import AudioToolbox
import Foundation

/// 機械鍵盤聲音包：一套是同一把鍵盤的十幾個單鍵錄音，每個錄音切成「按下去」和「彈回來」兩聲。
/// 手指碰到鍵播按下那聲、手指離開播彈回那聲，兩聲隔多久跟著手指走（整個錄音一次播完的話，
/// 彈回聲永遠隔一樣久，聽起來像罐頭）。每一聲都從那一類隨機挑一個，不連續播同一個（不然像機關槍）。
///
/// 檔名（都在鍵盤擴充的 Resources/KeySounds，用 docs/make_keysounds.py 產生；App 試聽時從擴充借）：
/// keysound-<套>-<編號>.wav 一般鍵按下、keysound-<套>-up-<編號>.wav 一般鍵彈回；
/// 中間多一個 fn 的是空白、刪除、換行這些大鍵用的（聲音比較低）。
///
/// 用系統音效播：不用開音訊工作階段，不會打斷別的 App 正在放的音樂。音量跟著手機的鈴聲音量和靜音鍵
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

    private var sounds: [Pool: [SystemSoundID]] = [:]
    private var lastIndex: [Pool: Int] = [:]
    private var loadedPack: String?

    deinit {
        unload()
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

    /// 換一套（nil = 不用聲音包）。已經是這一套就不重讀
    func load(pack: String?, from bundle: Bundle) {
        guard pack != loadedPack else { return }
        unload()
        loadedPack = pack
        guard let pack else { return }
        for url in Self.files(for: pack, in: bundle) {
            var id: SystemSoundID = 0
            guard AudioServicesCreateSystemSoundID(url as CFURL, &id) == kAudioServicesNoError else { continue }
            sounds[Self.pool(for: url.lastPathComponent), default: []].append(id)
        }
    }

    /// 播一下。回傳 false 表示這一套沒有這一聲可播（呼叫的人自己決定要不要改播別的）
    @discardableResult
    func play(_ stroke: Stroke, bigKey: Bool) -> Bool {
        let regular: Pool = stroke == .down ? .key : .keyUp
        let big: Pool = stroke == .down ? .bigKey : .bigKeyUp
        // 這一套沒有大鍵的音檔就用一般鍵的
        let pool = bigKey && sounds[big]?.isEmpty == false ? big : regular
        guard let ids = sounds[pool], !ids.isEmpty else { return false }
        var index = Int.random(in: 0 ..< ids.count)
        if ids.count > 1, index == lastIndex[pool] {
            index = (index + 1) % ids.count
        }
        lastIndex[pool] = index
        AudioServicesPlaySystemSound(ids[index])
        return true
    }

    private static func pool(for fileName: String) -> Pool {
        let big = fileName.contains("-fn-")
        if fileName.contains("-up-") {
            return big ? .bigKeyUp : .keyUp
        }
        return big ? .bigKey : .key
    }

    private func unload() {
        for id in sounds.values.joined() {
            AudioServicesDisposeSystemSoundID(id)
        }
        sounds = [:]
        lastIndex = [:]
        loadedPack = nil
    }
}
