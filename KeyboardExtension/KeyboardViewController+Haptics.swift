import UIKit

/// 按鍵震動：每按一顆鍵輕點一下（刪除鍵按住連刪時每刪一下也點）。
/// 第三方鍵盤讀不到系統「鍵盤回饋 → 觸覺」的開關，所以開關放在豆鍵 App 的設定頁（預設關，跟系統一樣）；
/// 鍵盤擴充要開完全取用才震得了
extension KeyboardViewController {
    func tapHaptic() {
        guard keyHaptics else { return }
        keyHaptic.impactOccurred(intensity: SamsungTheme.keyHapticIntensity)
        // 先叫醒震動馬達，下一下才不會慢半拍
        keyHaptic.prepare()
    }
}
