import UIKit

/// 按下鍵時跳在鍵上方的放大字。一個鍵盤只有一顆，重複使用。
final class KeyPreviewBubble: UIView {
    private let label = UILabel()

    override init(frame: CGRect) {
        super.init(frame: frame)
        layer.cornerRadius = 10
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.25
        layer.shadowOffset = CGSize(width: 0, height: 2)
        layer.shadowRadius = 4
        applyTheme()
        label.textAlignment = .center
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        isUserInteractionEnabled = false
        isHidden = true
    }

    /// 照目前主題上色、換字（換主題後鍵面重建時呼叫）
    func applyTheme() {
        backgroundColor = SamsungTheme.keyWhite
        label.font = SamsungTheme.keyFont(ofSize: SamsungTheme.previewFontSize)
        label.textColor = SamsungTheme.keyText
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    /// 顯示在某顆鍵的正上方（座標以 superview 為準）
    func show(text: String, above keyFrame: CGRect) {
        label.text = text
        let w = max(keyFrame.width * 1.4, 48)
        let h = keyFrame.height * 1.3
        // 最上排的泡泡不能超出鍵盤頂端（超出會被系統裁掉），頂多貼齊鍵盤頂
        let topLimit = -(superview?.frame.minY ?? 0)
        let y = max(keyFrame.minY - h - 6, topLimit)
        frame = CGRect(x: keyFrame.midX - w / 2, y: y, width: w, height: h)
        isHidden = false
    }

    func hide() {
        isHidden = true
    }
}
