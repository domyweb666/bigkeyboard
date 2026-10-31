import UIKit

/// 鍵帽。刻意不用 UIButton：系統「按鈕形狀」輔助設定會在 UIButton 文字下加底線，鍵盤長相不該被它影響。
/// 負責：主字、右上角長按提示小字、按下變色、長按（≥ 0.4 秒）判定。
final class KeyButton: UIControl {
    let label = UILabel()
    let hintLabel = UILabel()

    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    /// 手指按下／放開（給預覽泡泡用）
    var onPressChanged: ((Bool) -> Void)?

    var normalColor: UIColor = SamsungTheme.keyWhite {
        didSet {
            backgroundColor = normalColor
        }
    }

    private var longPressTimer: Timer?
    private var longPressFired = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.textColor = SamsungTheme.keyText
        label.isUserInteractionEnabled = false
        label.translatesAutoresizingMaskIntoConstraints = false
        addSubview(label)

        hintLabel.font = .systemFont(ofSize: SamsungTheme.hintFontSize)
        hintLabel.textColor = SamsungTheme.hintText
        hintLabel.isUserInteractionEnabled = false
        hintLabel.translatesAutoresizingMaskIntoConstraints = false
        addSubview(hintLabel)

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            hintLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -5),
        ])
        layer.cornerRadius = SamsungTheme.keyCornerRadius
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        backgroundColor = normalColor

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
        addTarget(self, action: #selector(touchEnded), for: [.touchUpOutside, .touchCancel, .touchDragExit])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? SamsungTheme.keyPressed : normalColor
        }
    }

    @objc private func touchDown() {
        longPressFired = false
        onPressChanged?(true)
        guard onLongPress != nil else { return }
        longPressTimer?.invalidate()
        longPressTimer = Timer.scheduledTimer(
            withTimeInterval: SamsungTheme.longPressSeconds,
            repeats: false
        ) { [weak self] _ in
            guard let self else { return }
            longPressFired = true
            onPressChanged?(false)
            onLongPress?()
        }
    }

    @objc private func touchUpInside() {
        longPressTimer?.invalidate()
        onPressChanged?(false)
        if !longPressFired {
            onTap?()
        }
    }

    @objc private func touchEnded() {
        longPressTimer?.invalidate()
        onPressChanged?(false)
    }
}
