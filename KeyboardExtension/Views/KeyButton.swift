import UIKit

/// 鍵帽。刻意不用 UIButton：系統「按鈕形狀」輔助設定會在 UIButton 文字下加底線，鍵盤長相不該被它影響。
/// 負責：主字（文字或 SF Symbol）、右上角長按提示小字、按下變色、長按判定、按住連發（刪除鍵用）。
final class KeyButton: UIControl {
    let label = UILabel()
    let hintLabel = UILabel()
    let iconView = UIImageView()
    /// 空白鍵底部的小字（顯示目前語言）
    let footLabel = UILabel()

    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?
    /// 設了就變成「按下立刻觸發一次、按住 0.4 秒後連發」，不再走 onTap
    var onRepeat: (() -> Void)?
    /// 手指按下／放開（給預覽泡泡用）
    var onPressChanged: ((Bool) -> Void)?

    var normalColor: UIColor = SamsungTheme.keyWhite {
        didSet {
            backgroundColor = normalColor
        }
    }

    private var longPressTimer: Timer?
    private var repeatTimer: Timer?
    private var longPressFired = false
    /// 快打時被下一顆鍵搶先送出了，放開時不再送一次
    private var firedEarly = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        label.textAlignment = .center
        label.textColor = SamsungTheme.keyText
        label.adjustsFontSizeToFitWidth = true
        label.minimumScaleFactor = 0.6

        hintLabel.font = .systemFont(ofSize: SamsungTheme.hintFontSize, weight: .medium)
        hintLabel.textColor = SamsungTheme.hintText

        iconView.tintColor = SamsungTheme.keyText
        iconView.contentMode = .scaleAspectFit

        footLabel.font = .systemFont(ofSize: SamsungTheme.footFontSize)
        footLabel.textColor = SamsungTheme.hintText

        for v in [label, hintLabel, iconView, footLabel] as [UIView] {
            v.isUserInteractionEnabled = false
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: centerXAnchor),
            label.centerYAnchor.constraint(equalTo: centerYAnchor, constant: 2),
            label.leadingAnchor.constraint(greaterThanOrEqualTo: leadingAnchor, constant: 2),
            label.trailingAnchor.constraint(lessThanOrEqualTo: trailingAnchor, constant: -2),
            hintLabel.topAnchor.constraint(equalTo: topAnchor, constant: 3),
            hintLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -4),
            iconView.centerXAnchor.constraint(equalTo: centerXAnchor),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            footLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            footLabel.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -4),
        ])
        layer.cornerRadius = SamsungTheme.keyCornerRadius
        layer.shadowColor = UIColor.black.cgColor
        layer.shadowOpacity = 0.12
        layer.shadowOffset = CGSize(width: 0, height: 1)
        layer.shadowRadius = 0
        backgroundColor = normalColor

        addTarget(self, action: #selector(touchDown), for: .touchDown)
        addTarget(self, action: #selector(touchUpInside), for: .touchUpInside)
        addTarget(self, action: #selector(touchEnded), for: [.touchUpOutside, .touchCancel])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        if layer.shadowOpacity > 0 {
            layer.shadowOpacity = traitCollection.userInterfaceStyle == .dark ? 0.35 : 0.12
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.shadowPath = UIBezierPath(roundedRect: bounds, cornerRadius: layer.cornerRadius).cgPath
    }

    override var isHighlighted: Bool {
        didSet {
            backgroundColor = isHighlighted ? SamsungTheme.keyPressed : normalColor
        }
    }

    /// 讓鍵的觸控範圍吃掉鍵與鍵之間的縫：縫裡按下去算最近的那顆鍵，減少「按在縫上沒反應」
    override func point(inside point: CGPoint, with _: UIEvent?) -> Bool {
        bounds.insetBy(dx: -SamsungTheme.keyGap / 2, dy: -SamsungTheme.rowGap / 2).contains(point)
    }

    func setIcon(_ systemName: String?) {
        if let systemName {
            let config = UIImage.SymbolConfiguration(pointSize: SamsungTheme.iconPointSize, weight: .regular)
            iconView.image = UIImage(systemName: systemName, withConfiguration: config)
            label.isHidden = true
        } else {
            iconView.image = nil
            label.isHidden = false
        }
    }

    @objc private func touchDown() {
        longPressFired = false
        firedEarly = false
        onPressChanged?(true)
        if let onRepeat {
            onRepeat()
            repeatTimer?.invalidate()
            repeatTimer = Timer.scheduledTimer(
                withTimeInterval: SamsungTheme.longPressSeconds,
                repeats: false
            ) { [weak self] _ in
                self?.startRepeating()
            }
            return
        }
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

    private func startRepeating() {
        repeatTimer?.invalidate()
        repeatTimer = Timer.scheduledTimer(
            withTimeInterval: SamsungTheme.repeatInterval,
            repeats: true
        ) { [weak self] _ in
            self?.onRepeat?()
        }
    }

    private func stopTimers() {
        longPressTimer?.invalidate()
        repeatTimer?.invalidate()
    }

    /// 快打時下一顆鍵已經按下：這顆現在就算按完（不等手指放開）
    func fireNow() {
        guard isTracking, onRepeat == nil, !longPressFired, !firedEarly else { return }
        firedEarly = true
        stopTimers()
        onPressChanged?(false)
        onTap?()
    }

    @objc private func touchUpInside() {
        stopTimers()
        guard !firedEarly, !longPressFired else { return }
        onPressChanged?(false)
        if onRepeat == nil {
            onTap?()
        }
    }

    @objc private func touchEnded() {
        stopTimers()
        guard !firedEarly, !longPressFired else { return }
        onPressChanged?(false)
    }
}
