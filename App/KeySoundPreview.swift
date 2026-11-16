import AudioToolbox
import Foundation

/// 設定頁選按鍵聲時試聽：照鍵盤會播的聲音連按三下。
/// 聲音包的音檔只放在鍵盤擴充裡一份，從擴充借來播
@MainActor
enum KeySoundPreview {
    private static let player = KeySoundPlayer()
    /// 兩下之間隔多久
    private static let gap = Duration.milliseconds(140)

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
        case .crisp, .thick, .vintage:
            guard let keyboardBundle else { return }
            player.load(pack: style.pack, from: keyboardBundle)
            Task {
                for bigKey in [false, false, true] {
                    player.play(bigKey: bigKey)
                    try? await Task.sleep(for: gap)
                }
            }
        }
    }
}
