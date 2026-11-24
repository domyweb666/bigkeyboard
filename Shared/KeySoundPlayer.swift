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
/// 音訊類別用 ambient：跟別的 App 正在放的音樂混著放、不打斷；手機切靜音就不響。
/// 音量跟著手機的媒體音量（以前用系統音效時跟著鈴聲音量）
final class KeySoundPlayer {
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

    private let engine = AVAudioEngine()
    private var voices: [AVAudioPlayerNode] = []
    private var nextVoice = 0
    /// 播放器接到混音器用的格式：第一個讀到的音檔的格式（產生音檔的程式都輸出 44.1 kHz 單聲道）
    private var format: AVAudioFormat?
    private var sounds: [Pool: [AVAudioPCMBuffer]] = [:]
    private var lastIndex: [Pool: Int] = [:]
    private var loadedPack: String?

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

    /// 換一套（nil = 不用聲音包），並把播放器開起來待命（第一下才不會晚）。已經是這一套就不重讀音檔
    func load(pack: String?, from bundle: Bundle) {
        if pack != loadedPack {
            unload()
            loadedPack = pack
            if let pack {
                OpenTiming.measure(\.readSounds) { read(pack, from: bundle) }
            }
        }
        OpenTiming.measure(\.startAudio) { start() }
    }

    /// 鍵盤收起時停掉，不在背景空轉。下次叫出來 load 會再開
    func stop() {
        engine.stop()
    }

    /// 播一下。回傳 false 表示這一套沒有這一聲可播、或播放器開不起來（呼叫的人自己決定要不要改播別的）
    @discardableResult
    func play(_ stroke: Stroke, bigKey: Bool) -> Bool {
        let regular: Pool = stroke == .down ? .key : .keyUp
        let big: Pool = stroke == .down ? .bigKey : .bigKeyUp
        // 這一套沒有大鍵的音檔就用一般鍵的
        let pool = bigKey && sounds[big]?.isEmpty == false ? big : regular
        guard let list = sounds[pool], !list.isEmpty else { return false }
        // 被系統停掉（來電、插拔耳機）之後的第一下：重新開起來
        if !engine.isRunning {
            start()
        }
        guard engine.isRunning, !voices.isEmpty else { return false }
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

    /// 有音檔才開。播放器第一次開時建好、接上混音器，之後重開只要再按播放
    private func start() {
        guard let format, !sounds.isEmpty, !engine.isRunning else { return }
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
            return
        }
        for voice in voices {
            voice.play()
        }
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
        lastIndex = [:]
        loadedPack = nil
    }
}
