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
    /// 長按觸發後手指繼續拖：回報手指位置（螢幕座標）。空白鍵拖游標用
    var onDragAfterLongPress: ((CGPoint) -> Void)?
    /// 長按觸發後手指放開（或觸控被取消）
    var onLongPressEnd: (() -> Void)?
    /// 按下就觸發 onTap、不等放開（展開鍵用：放開前觸控被系統取消也不會沒反應）
    var firesOnPress = false
    /// 觸控被取消時，手指沒怎麼動就照樣算按到。候選字關掉：它在可左右捲的列裡，取消代表使用者開始捲了
    var tapsWhenCancelled = true

    var normalColor: UIColor = SamsungTheme.keyWhite {
        didSet {
            backgroundColor = normalColor
        }
    }

    private var longPressTimer: Timer?
    private var repeatTimer: Timer?
    private var longPressFired = false
    /// 這次按住已經連發了幾下（按下那一下是 0）
    private(set) var repeatCount = 0
    /// 快打時被下一顆鍵搶先送出了，放開時不再送一次
    private var firedEarly = false
    /// 按下的位置、最後一次移動的位置（判斷「手指幾乎沒動」用）
    private var trackStart = CGPoint.zero
    private var trackLast = CGPoint.zero

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
        addTarget(self, action: #selector(touchUpOutside), for: .touchUpOutside)
        addTarget(self, action: #selector(touchCancelled), for: .touchCancel)
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

    func setIcon(_ systemName: String?, pointSize: CGFloat = SamsungTheme.iconPointSize) {
        if let systemName {
            let config = UIImage.SymbolConfiguration(pointSize: pointSize, weight: .regular)
            iconView.image = UIImage(systemName: systemName, withConfiguration: config)
            label.isHidden = true
        } else {
            iconView.image = nil
            label.isHidden = false
        }
    }

    override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        trackStart = touch.location(in: nil)
        trackLast = trackStart
        return super.beginTracking(touch, with: event)
    }

    override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
        trackLast = touch.location(in: nil)
        if longPressFired {
            onDragAfterLongPress?(trackLast)
        }
        return super.continueTracking(touch, with: event)
    }

    override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
        if let touch {
            trackLast = touch.location(in: nil)
        }
        super.endTracking(touch, with: event)
    }

    @objc private func touchDown() {
        longPressFired = false
        firedEarly = false
        if firesOnPress {
            onTap?()
            return
        }
        onPressChanged?(true)
        if let onRepeat {
            repeatCount = 0
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
            guard let self else { return }
            repeatCount += 1
            onRepeat?()
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
        endLongPressIfNeeded()
        guard !firesOnPress, !firedEarly, !longPressFired else { return }
        finishTap()
    }

    /// 在鍵外放開：按在鍵縫、錯開的半顆空位時，落點本來就在這顆鍵的範圍外
    @objc private func touchUpOutside() {
        touchEnded(canTap: true)
    }

    /// 觸控被取消：最左最右兩欄的觸控常被系統邊緣手勢取消
    @objc private func touchCancelled() {
        touchEnded(canTap: tapsWhenCancelled)
    }

    /// 手指幾乎沒移動就照樣算按到
    private func touchEnded(canTap: Bool) {
        stopTimers()
        endLongPressIfNeeded()
        guard !firesOnPress, !firedEarly, !longPressFired else { return }
        let moved = hypot(trackLast.x - trackStart.x, trackLast.y - trackStart.y)
        if canTap, moved < SamsungTheme.tapSlop {
            finishTap()
        } else {
            onPressChanged?(false)
        }
    }

    private func endLongPressIfNeeded() {
        if longPressFired {
            onLongPressEnd?()
        }
    }

    /// 字、圖示、小字淡掉或回來（空白鍵拖游標時整塊鍵盤變觸控板）；鍵帽底色不變
    func setContentHidden(_ hidden: Bool) {
        for v in [label, hintLabel, iconView, footLabel] as [UIView] {
            v.alpha = hidden ? 0 : 1
        }
    }

    private func finishTap() {
        onPressChanged?(false)
        if onRepeat == nil {
            onTap?()
        }
    }
}
