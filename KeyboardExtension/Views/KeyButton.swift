import UIKit

/// 鍵帽。刻意不用 UIButton：系統「按鈕形狀」輔助設定會在 UIButton 文字下加底線，鍵盤長相不該被它影響。
final class KeyButton: UIControl {
    let label = UILabel()
    var normalColor: UIColor = SamsungTheme.keyWhite {
        didSet { backgroundColor = normalColor }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.textColor = SamsungTheme.keyText
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)
        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
        layer.cornerRadius = SamsungTheme.keyCornerRadius
        backgroundColor = normalColor
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    override var isHighlighted: Bool {
        didSet { backgroundColor = isHighlighted ? SamsungTheme.keyPressed : normalColor }
    }
}
