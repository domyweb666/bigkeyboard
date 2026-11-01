import UIKit

/// 讓系統的「鍵盤按鍵聲」設定生效：鍵盤的 inputView 要宣告支援輸入音效，UIDevice.playInputClick() 才會響。
/// 不需要「允許完全取用」，而且會遵守使用者在 設定 → 聲音與觸覺 → 鍵盤回饋 的選擇。
final class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool {
        true
    }
}
