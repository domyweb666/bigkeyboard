import UIKit

/// 收鍵盤（2026-11-02 改）：拿掉頂端拖曳條和「往下拖收起」——往下拖在鍵上很不敏感，又可能在快打時誤收。
/// 改成看得見的鍵：注音鍵面工具列最右邊一顆「收鍵盤」（系統同款圖示）；其他鍵面沒有工具列，長按換行鍵收（鍵上小字 ⌄）
extension KeyboardViewController {
    func setUpDismiss() {
        candidateBar.onDismiss = { [weak self] in self?.dismissKeyboard() }
    }
}
