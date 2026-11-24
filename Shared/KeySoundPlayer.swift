import AVFoundation
import Foundation

/// 按鍵聲音包：一套是十幾個單鍵錄音。機械鍵盤那三套每個錄音切成「按下去」和「彈回來」兩聲，
/// 手指碰到鍵播按下那聲、手指離開播彈回那聲，兩聲隔多久跟著手指走（整個錄音一次播完的話，
/// 彈回聲永遠隔一樣久，聽起來像罐頭）。每一聲都從那一類隨機挑一個，不連續播同一個（不然像機關槍）。
///
/// 檔名（都在鍵盤擴充的 Resources/KeySounds，用 docs/make_keysounds.py、make_ai_keysounds.py 產生；App 試聽時從擴充借）：
/// keysound-<套>-<編號>.wav 一般鍵按下、keysound-<套>-up-<編號>.wav 一般鍵彈回；
/// 中間多一個 fn 的是空白、刪除、換行這些大鍵用的（聲音比較低）。
///
/// 用 AVAudioEngine 播，不用系統音效（2026-11-22 多米：敲快時有些鍵沒聲音、聲音聽起來怪）。
/// 系統音效每一聲都交給系統排隊，快打時會被吃掉，每一聲晚多少也不一定；按下、彈回兩聲一起排，掉得更多。
/// 這裡先把音檔全讀進記憶體，幾個播放器輪流播：上一聲還沒收尾，下一聲照樣疊上去，每一聲走同一條路、晚一樣多。
/// 讀音檔、開音訊都在背景做（2026-11-25 手感審查：在主執行緒做的話，叫出鍵盤要多等一百多毫秒）。
/// 還沒好的時候 play 回傳 false，呼叫的人改播系統按鍵聲；音檔讀一次就留著，同一套不重讀。
/// 音訊類別用 ambient：跟別的 App 正在放的音樂混著放、不打斷；手機切靜音就不響。
/// 音量跟著手機的媒體音量（以前用系統音效時跟著鈴聲音量）
final class KeySoundPlayer {
    /// 已經開好、可以播的東西
    private struct Playable {
        let voices: [AVAudioPlayerNode]
        let sounds: [Pool: [AVAudioPCMBuffer]]
    }

    /// 一下按鍵的兩聲
    enum Stroke {
        /// 手指碰到鍵
        case down
        /// 手指離開鍵
        case up
    }

    private enum Pool {
        case key
        case keyUp
        case bigKey
        case bigKeyUp
    }

    /// 同時最多幾聲疊在一起。一聲最長約 0.4 秒，一秒打 10 下（按下、彈回各一聲）也只疊 8 聲
    private static let voiceCount = 8
    /// 每一聲隨機小聲 0～1.5 dB：對齊成一模一樣大聲反而假，留一點點差
    private static let volumeJitter: ClosedRange<Float> = 0.84 ... 1
    /// 量多大聲時只看開頭這麼長（秒）：按鍵聲的份量都在撞擊後這一小段，尾巴長短不該算進去
    private static let loudnessWindow = 0.03
    /// 小聲的放大時，峰值最多到多少，免得破音
    private static let peakLimit: Float = 0.95
    /// 聲音從送出到喇叭的緩衝（秒）：越短越跟手。系統不一定照給，給多少用多少
    private static let ioBufferSeconds = 0.005

    // 主執行緒用的。playable 有東西時背景一定沒在動播放器，主執行緒才可以碰它
    private var playable: Playable?
    private var preparing = false
    /// load 之後、stop 之前：收起來的鍵盤不自己把播放器開回來
    private var active = false
    /// 第幾次準備：背景做完時已經換了一套、或鍵盤收起了，那次的結果就不要
    private var turn = 0
    private var wantedPack: String?
    private var wantedBundle = Bundle.main
    private var nextVoice = 0
    private var lastIndex: [Pool: Int] = [:]
    private var observers: [NSObjectProtocol] = []

    // 背景（queue）用的
    private let queue = DispatchQueue(label: "org.domyweb.bigkeyboard.keysound", qos: .userInitiated)
    private lazy var engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []
    /// 播放器接到混音器用的格式：第一個讀到的音檔的格式（產生音檔的程式都輸出 44.1 kHz 單聲道）
    private var format: AVAudioFormat?
    private var sounds: [Pool: [AVAudioPCMBuffer]] = [:]
    private var loadedPack: String?

    init() {
        // 插拔耳機、講完電話：系統會把播放器停掉，先在背景開回來，不等下一顆鍵
        let center = NotificationCenter.default
        for name in [Notification.Name.AVAudioEngineConfigurationChange, AVAudioSession.interruptionNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] note in
                let kind = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt
                guard kind != AVAudioSession.InterruptionType.began.rawValue else { return }
                // 通知可能是播放器自己的執行緒發的、正鎖著播放器：不等主執行緒，排進去就好，免得互等
                DispatchQueue.main.async { self?.restartIfStopped() }
            })
        }
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }

    /// bundle 裡這一套的音檔（照檔名排）
    static func files(for pack: String, in bundle: Bundle) -> [URL] {
        (bundle.urls(forResourcesWithExtension: "wav", subdirectory: nil) ?? [])
            .filter { $0.lastPathComponent.hasPrefix("keysound-\(pack)-") }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
    }

    /// 這一套的音檔有沒有包進來（沒有的話選單不列）
    static func isInstalled(_ pack: String, in bundle: Bundle) -> Bool {
        !files(for: pack, in: bundle).isEmpty
    }

    /// 換一套（nil = 不用聲音包），並在背景把播放器開起來待命。已經是這一套就不重讀音檔。
    /// 好了（或開不起來）在主執行緒叫 done
    func load(pack: String?, from bundle: Bundle, then done: (() -> Void)? = nil) {
        let same = pack == wantedPack
        wantedPack = pack
        wantedBundle = bundle
        active = true
        // 本來就沒用聲音包、或同一套正開著：不用動
        if same, pack == nil || (playable != nil && engine.isRunning) {
            done?()
            return
        }
        prepare(then: done)
    }

    /// 鍵盤收起時停掉，不在背景空轉。下次叫出來 load 會再開
    func stop() {
        active = false
        guard wantedPack != nil else { return }
        turn += 1
        playable = nil
        preparing = false
        queue.async { self.engine.stop() }
    }

    /// 播一下。回傳 false 表示還沒準備好、這一套沒有這一聲可播、或播放器開不起來（呼叫的人自己決定要不要改播別的）
    @discardableResult
    func play(_ stroke: Stroke, bigKey: Bool) -> Bool {
        guard let playable, engine.isRunning else {
            // 被系統停掉、還沒開回來：在背景重開，這一下不等
            if active, !preparing {
                prepare()
            }
            return false
        }
        let (voices, sounds) = (playable.voices, playable.sounds)
        let regular: Pool = stroke == .down ? .key : .keyUp
        let big: Pool = stroke == .down ? .bigKey : .bigKeyUp
        // 這一套沒有大鍵的音檔就用一般鍵的
        let pool = bigKey && sounds[big]?.isEmpty == false ? big : regular
        guard let list = sounds[pool], !list.isEmpty else { return false }
        var index = Int.random(in: 0 ..< list.count)
        if list.count > 1, index == lastIndex[pool] {
            index = (index + 1) % list.count
        }
        lastIndex[pool] = index
        let voice = voices[nextVoice]
        nextVoice = (nextVoice + 1) % voices.count
        voice.volume = Float.random(in: Self.volumeJitter)
        // 輪到的播放器如果還在響好幾下之前的那一聲，直接蓋掉，新的這一聲不排隊
        voice.scheduleBuffer(list[index], at: nil, options: .interrupts)
        if !voice.isPlaying {
            voice.play()
        }
        return true
    }

    private func restartIfStopped() {
        guard playable != nil, !engine.isRunning else { return }
        prepare()
    }

    /// 背景讀音檔、開播放器，好了才交給主執行緒用
    private func prepare(then done: (() -> Void)? = nil) {
        turn += 1
        playable = nil
        preparing = true
        let (turn, pack, bundle) = (turn, wantedPack, wantedBundle)
        queue.async {
            let began = CACurrentMediaTime()
            if pack != self.loadedPack {
                self.unload()
                self.loadedPack = pack
                if let pack {
                    self.read(pack, from: bundle)
                }
            }
            let read = CACurrentMediaTime()
            let ready = self.start() ? Playable(voices: self.voices, sounds: self.sounds) : nil
            let started = CACurrentMediaTime()
            DispatchQueue.main.async {
                if turn == self.turn {
                    self.playable = ready
                    self.preparing = false
                    if ready != nil {
                        OpenTiming.soundReady(read: read - began, start: started - read)
                    }
                }
                done?()
            }
        }
    }

    private func read(_ pack: String, from bundle: Bundle) {
        for url in Self.files(for: pack, in: bundle) {
            guard let buffer = Self.readBuffer(url) else { continue }
            if format == nil {
                format = buffer.format
            }
            // 一組播放器只接一種格式，跟第一個不一樣的不播
            guard buffer.format == format else { continue }
            sounds[Self.pool(for: url.lastPathComponent), default: []].append(buffer)
        }
        for list in sounds.values {
            Self.level(list)
        }
    }

    private static func readBuffer(_ url: URL) -> AVAudioPCMBuffer? {
        guard let file = try? AVAudioFile(forReading: url),
              let buffer = AVAudioPCMBuffer(
                  pcmFormat: file.processingFormat,
                  frameCapacity: AVAudioFrameCount(file.length)
              )
        else { return nil }
        do {
            try file.read(into: buffer)
        } catch {
            return nil
        }
        return buffer
    }

    /// 同一類對齊成一樣大聲：音檔是照峰值對齊的，聽起來大小聲最多差到 9 dB，隨機挑到就忽大忽小。
    /// 以開頭 30 毫秒的音量為準，大家往中間那一聲靠（直接乘進音檔，播放器的音量最大只到 1）；
    /// 小聲的要放大時，峰值不超過 peakLimit。不同類之間（按下比彈回大聲）照原本的差不動
    private static func level(_ list: [AVAudioPCMBuffer]) {
        let measured = list.map(loudness)
        let sorted = measured.map(\.rms).sorted()
        guard !sorted.isEmpty else { return }
        let target = sorted[sorted.count / 2]
        for (buffer, m) in zip(list, measured) where m.rms > 0 && m.peak > 0 {
            let gain = min(target / m.rms, peakLimit / m.peak)
            for channel in 0 ..< Int(buffer.format.channelCount) {
                guard let samples = buffer.floatChannelData?[channel] else { continue }
                for i in 0 ..< Int(buffer.frameLength) {
                    samples[i] *= gain
                }
            }
        }
    }

    /// 開頭那一小段的音量（均方根）與整個音檔的峰值，只看第一個聲道
    private static func loudness(_ buffer: AVAudioPCMBuffer) -> (rms: Float, peak: Float) {
        guard let samples = buffer.floatChannelData?[0] else { return (0, 0) }
        let count = Int(buffer.frameLength)
        let window = min(count, Int(buffer.format.sampleRate * loudnessWindow))
        var sum: Float = 0
        var peak: Float = 0
        for i in 0 ..< count {
            let v = abs(samples[i])
            peak = max(peak, v)
            if i < window {
                sum += v * v
            }
        }
        return (window > 0 ? (sum / Float(window)).squareRoot() : 0, peak)
    }

    /// 有音檔才開，回傳開著沒有。播放器第一次開時建好、接上混音器，之後重開只要再按播放
    private func start() -> Bool {
        guard let format, !sounds.isEmpty else { return false }
        guard !engine.isRunning else { return true }
        let session = AVAudioSession.sharedInstance()
        if voices.isEmpty {
            try? session.setCategory(.ambient)
            try? session.setPreferredIOBufferDuration(Self.ioBufferSeconds)
            for _ in 0 ..< Self.voiceCount {
                let voice = AVAudioPlayerNode()
                engine.attach(voice)
                engine.connect(voice, to: engine.mainMixerNode, format: format)
                voices.append(voice)
            }
        }
        do {
            try session.setActive(true)
            try engine.start()
        } catch {
            return false
        }
        for voice in voices {
            voice.play()
        }
        return true
    }

    private static func pool(for fileName: String) -> Pool {
        let big = fileName.contains("-fn-")
        if fileName.contains("-up-") {
            return big ? .bigKeyUp : .keyUp
        }
        return big ? .bigKey : .key
    }

    /// 換成別套或不用聲音包：先停掉，沒音檔就不讓播放器空轉
    private func unload() {
        for voice in voices {
            voice.stop()
        }
        engine.stop()
        sounds = [:]
        loadedPack = nil
    }
}
