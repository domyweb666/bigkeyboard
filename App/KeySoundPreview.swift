import AudioToolbox
import Foundation

/// 設定頁選按鍵聲時試聽：照鍵盤會播的聲音連按三下（機械鍵盤每一下是按下、彈回兩聲）。
/// 聲音包的音檔只放在鍵盤擴充裡一份，從擴充借來播
@MainActor
enum KeySoundPreview {
    private static let player = KeySoundPlayer()
    /// 兩下之間隔多久
    private static let gap = Duration.milliseconds(140)
    /// 機械鍵盤：按下到彈回隔多久（試聽用固定值；打字時是手指按多久就隔多久）
    private static let hold = Duration.milliseconds(70)

    private static let keyboardBundle: Bundle? = Bundle.main.builtInPlugInsURL
        .flatMap { Bundle(url: $0.appendingPathComponent("KeyboardExtension.appex")) }

    /// 選單要列的選項：聲音包只列音檔有包進來的
    static let available: [KeySoundStyle] = KeySoundStyle.allCases.filter { style in
        guard let pack = style.pack else { return true }
        guard let keyboardBundle else { return false }
        return KeySoundPlayer.isInstalled(pack, in: keyboardBundle)
    }

    static func play(_ style: KeySoundStyle) {
        switch style {
        case .system, .off:
            return
        case .distinct:
            Task {
                for id: SystemSoundID in [1104, 1155, 1156] {
                    AudioServicesPlaySystemSound(id)
                    try? await Task.sleep(for: gap)
                }
            }
        case .crisp, .thick, .vintage, .beans, .woodblock, .typewriter, .laptop:
            // 沒有彈回聲的那幾套，play(.up) 找不到音檔就不出聲
            guard let keyboardBundle else { return }
            Task {
                await withCheckedContinuation { ready in
                    player.load(pack: style.pack, from: keyboardBundle) { ready.resume() }
                }
                for bigKey in [false, false, true] {
                    player.play(.down, bigKey: bigKey)
                    try? await Task.sleep(for: hold)
                    player.play(.up, bigKey: bigKey)
                    try? await Task.sleep(for: gap)
                }
            }
        }
    }
}
