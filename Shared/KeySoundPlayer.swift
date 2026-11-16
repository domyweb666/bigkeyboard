import AudioToolbox
import Foundation

/// 機械鍵盤聲音包：一套是同一把鍵盤的十幾個單鍵錄音，每按一下隨機播一個，不連續播同一個（不然聽起來像機關槍）。
/// 檔名 keysound-<套>-<編號>.wav 是一般鍵；keysound-<套>-fn-<編號>.wav 是空白、刪除、換行這些大鍵（聲音比較低）。
/// 音檔只放在鍵盤擴充裡一份（Resources/KeySounds，用 docs/make_keysounds.py 產生）；App 試聽時從擴充借。
///
/// 用系統音效播：不用開音訊工作階段，不會打斷別的 App 正在放的音樂。音量跟著手機的鈴聲音量和靜音鍵
final class KeySoundPlayer {
    private var keys: [SystemSoundID] = []
    private var bigKeys: [SystemSoundID] = []
    private var loadedPack: String?
    private var lastIndex = -1

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
            if url.lastPathComponent.contains("-fn-") {
                bigKeys.append(id)
            } else {
                keys.append(id)
            }
        }
    }

    /// 播一下。回傳 false 表示這一套沒有音檔可播（呼叫的人自己決定要不要改播別的）
    @discardableResult
    func play(bigKey: Bool) -> Bool {
        let pool = bigKey && !bigKeys.isEmpty ? bigKeys : keys
        guard !pool.isEmpty else { return false }
        var index = Int.random(in: 0 ..< pool.count)
        if pool.count > 1, index == lastIndex {
            index = (index + 1) % pool.count
        }
        lastIndex = index
        AudioServicesPlaySystemSound(pool[index])
        return true
    }

    private func unload() {
        for id in keys + bigKeys {
            AudioServicesDisposeSystemSoundID(id)
        }
        keys = []
        bigKeys = []
        loadedPack = nil
    }
}
