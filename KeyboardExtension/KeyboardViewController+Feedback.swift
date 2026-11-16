import AudioToolbox
import UIKit

/// 按鍵的回饋：震動、聲音。兩個開關都在豆鍵 App 的設定頁（存在 App Group，要開完全取用才讀得到）。
extension KeyboardViewController {
    /// 按鍵震動：每按一顆鍵輕點一下（刪除鍵按住連刪時每刪一下也點）。
    /// 第三方鍵盤讀不到系統「鍵盤回饋 → 觸覺」的開關，所以自己放開關（預設關，跟系統一樣）；
    /// 鍵盤擴充要開完全取用才震得了
    func tapHaptic() {
        guard keyHaptics else { return }
        keyHaptic.impactOccurred(intensity: SamsungTheme.keyHapticIntensity)
        // 先叫醒震動馬達，下一下才不會慢半拍
        keyHaptic.prepare()
    }

    /// 按鍵聲，照 App 設定頁選的：
    /// 系統預設走系統的那一種（跟著「設定 → 聲音與觸覺 → 鍵盤回饋 → 聲音」）；
    /// 三種按鍵聲是字母、刪除、功能鍵各用系統鍵盤的那三種聲音，光聽就知道按了哪一類；關閉就不出聲
    func playKeySound(for spec: KeySpec) {
        switch keySound {
        case .system:
            UIDevice.current.playInputClick()
        case .distinct:
            AudioServicesPlaySystemSound(Self.soundID(for: spec.action))
        case .off:
            break
        }
    }

    /// 系統鍵盤的三種按鍵聲：字母 1104、刪除 1155、空白與功能鍵 1156
    private static func soundID(for action: KeySpec.Action) -> SystemSoundID {
        switch action {
        case .bopomofo, .letter, .text: 1104
        case .backspace: 1155
        default: 1156
        }
    }
}
