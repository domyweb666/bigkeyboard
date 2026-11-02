import UIKit

/// 把一張鍵位表（資料）渲染成按鍵。所有鍵面共用這一份程式。
final class KeyboardView: UIView {
    var onKey: ((KeySpec) -> Void)?
    var onLongKey: ((KeySpec) -> Void)?
    /// 任何一顆鍵被按下（給按鍵聲用）
    var onAnyPress: (() -> Void)?
    /// 從任何一顆鍵往下拖（收鍵盤）
    var onSwipeDown: (() -> Void)?

    /// shift 狀態（只影響英文字母的顯示與送出）
    enum ShiftState {
        case off
        case once
        case locked
    }

    var shift: ShiftState = .off {
        didSet {
            applyShiftAppearance()
        }
    }

    /// 動態鍵寬：正在打的音打到哪，下一顆可能按的那類注音鍵就變寬
    enum Emphasis {
        case none
        /// 只打了聲母 → 介音、韻母變寬
        case afterConsonant
        /// 打到介音 → 韻母變寬
        case afterMedial
    }

    var emphasis: Emphasis = .none {
        didSet {
            guard emphasis != oldValue else { return }
            applyWidths()
            UIView.animate(withDuration: SamsungTheme.emphasisAnimation) {
                self.layoutIfNeeded()
            }
        }
    }

    private let rowsStack = UIStackView()
    private let bubble = KeyPreviewBubble()
    private var buttons: [KeyButton] = []
    private var specs: [KeyButton: KeySpec] = [:]
    /// 每一排的鍵（含空位）與它們的資料，重算寬度用
    private var rows: [(stack: UIStackView, keys: [(view: UIView, spec: KeySpec)])] = []
    private var widthConstraints: [NSLayoutConstraint] = []
    /// 目前按著還沒放開的那顆（快打時判斷「上一顆還沒放、下一顆已按下」）
    private weak var heldKey: KeyButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        rowsStack.axis = .vertical
        rowsStack.spacing = SamsungTheme.rowGap
        rowsStack.distribution = .fillEqually
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)
        addSubview(bubble)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: topAnchor, constant: SamsungTheme.rowGap),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SamsungTheme.rowGap),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SamsungTheme.sideInset),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SamsungTheme.sideInset),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    /// 整塊鍵盤區沒有死角：按在鍵與鍵、排與排之間的縫，或最外圈的邊上，都算離手指最近的那顆鍵。
    /// 只放大單顆鍵的 point(inside:) 不夠：排與排之間的縫不屬於任何一排，觸控根本到不了鍵
    override func hitTest(_ location: CGPoint, with _: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, bounds.contains(location) else { return nil }
        var nearest: KeyButton?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for b in buttons {
            let f = b.convert(b.bounds, to: self)
            let dx = max(f.minX - location.x, 0, location.x - f.maxX)
            let dy = max(f.minY - location.y, 0, location.y - f.maxY)
            let d = dx * dx + dy * dy
            if d < nearestDistance {
                nearestDistance = d
                nearest = b
            }
        }
        return nearest ?? self
    }

    func load(_ rows: [KeyRow]) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        specs.removeAll()
        self.rows.removeAll()
        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = SamsungTheme.keyGap
            rowStack.alignment = .fill
            var keys: [(view: UIView, spec: KeySpec)] = []
            for spec in row {
                // 空位不是鍵：按在上面由 hitTest 算給最近的鍵
                let b: UIView = if case .spacer = spec.action {
                    UIView()
                } else {
                    makeButton(spec)
                }
                rowStack.addArrangedSubview(b)
                keys.append((b, spec))
            }
            self.rows.append((rowStack, keys))
            rowsStack.addArrangedSubview(rowStack)
        }
        applyWidths()
        bringSubviewToFront(bubble)
        applyShiftAppearance()
    }

    /// 照 emphasis 算每顆鍵的寬：一排的總寬不變，變寬的鍵從變窄的鍵那裡拿空間
    private func applyWidths() {
        NSLayoutConstraint.deactivate(widthConstraints)
        widthConstraints.removeAll()
        for row in rows {
            let widths = row.keys.map { $0.spec.width * widthFactor($0.spec) }
            let total = widths.reduce(0, +)
            let gaps = SamsungTheme.keyGap * CGFloat(row.keys.count - 1)
            for (key, w) in zip(row.keys, widths) {
                let c = key.view.widthAnchor.constraint(
                    equalTo: row.stack.widthAnchor,
                    multiplier: w / total,
                    constant: -gaps * w / total
                )
                widthConstraints.append(c)
            }
        }
        NSLayoutConstraint.activate(widthConstraints)
    }

    private func widthFactor(_ spec: KeySpec) -> CGFloat {
        guard let group = spec.zhuyin, group != .tone else { return 1 }
        switch (emphasis, group) {
        case (.none, _):
            return 1
        case (.afterConsonant, .medial), (.afterConsonant, .final), (.afterMedial, .final):
            return SamsungTheme.emphasisGrow
        default:
            return SamsungTheme.emphasisShrink
        }
    }

    private func makeButton(_ spec: KeySpec) -> KeyButton {
        let b = KeyButton()
        b.label.text = spec.label
        if spec.isTone {
            b.label.font = .systemFont(ofSize: SamsungTheme.toneFontSize, weight: .bold)
        } else {
            let fontSize = spec.isFunction ? SamsungTheme.functionFontSize : SamsungTheme.keyFontSize
            b.label.font = .systemFont(ofSize: fontSize)
        }
        b.hintLabel.text = spec.longHint
        if spec.isFunction {
            // 灰色功能鍵上灰字對比不夠，改用主字色
            b.hintLabel.textColor = SamsungTheme.keyText
        }
        b.footLabel.text = spec.foot
        b.setIcon(spec.icon)
        b.normalColor = spec.tint ?? (spec.isFunction ? SamsungTheme.keyGray : SamsungTheme.keyWhite)

        if case .backspace = spec.action {
            // 刪除鍵：按下立刻刪、按住連刪
            b.onRepeat = { [weak self] in self?.onKey?(spec) }
        } else {
            b.onTap = { [weak self] in self?.onKey?(spec) }
        }
        if spec.longAction != nil {
            b.onLongPress = { [weak self] in self?.onLongKey?(spec) }
        }
        b.onSwipeDown = { [weak self] in self?.onSwipeDown?() }
        let showsBubble = !spec.isFunction && !spec.label.isEmpty
        b.onPressChanged = { [weak self, weak b] pressed in
            guard let self, let b else { return }
            trackHeld(b, pressed: pressed)
            guard showsBubble else { return }
            if pressed {
                let f = b.convert(b.bounds, to: self)
                bubble.show(text: b.label.text ?? "", above: f)
            } else {
                bubble.hide()
            }
        }
        specs[b] = spec
        buttons.append(b)
        return b
    }

    /// 記住按著的那顆。快打時上一顆還沒放開、下一顆已經按下：上一顆先算按完，送字順序才不會顛倒
    private func trackHeld(_ b: KeyButton, pressed: Bool) {
        guard pressed else {
            if heldKey === b {
                heldKey = nil
            }
            return
        }
        if let held = heldKey, held !== b, let s = specs[held], Self.firesEarlyOnRollover(s) {
            held.fireNow()
        }
        heldKey = b
        onAnyPress?()
    }

    /// 被下一顆鍵搶先時可以提早送出的鍵：送字的鍵和 shift（按住 shift 再按字母＝大寫）。
    /// 切鍵面的鍵不提早，免得鍵面換掉時下一顆鍵還按在舊鍵面上
    private static func firesEarlyOnRollover(_ spec: KeySpec) -> Bool {
        switch spec.action {
        case .bopomofo, .letter, .text, .space, .shift: true
        default: false
        }
    }

    /// 換行鍵依輸入框顯示「搜尋」「傳送」等字；nil 表示一般換行（顯示圖示）
    func setReturnLabel(_ text: String?) {
        for b in buttons {
            guard let spec = specs[b], case .newline = spec.action else { continue }
            if let text {
                b.setIcon(nil)
                b.label.text = text
            } else {
                b.setIcon(spec.icon)
                b.label.text = spec.label
            }
        }
    }

    private func applyShiftAppearance() {
        for b in buttons {
            guard let spec = specs[b] else { continue }
            switch spec.action {
            case let .letter(c):
                b.label.text = shift == .off ? c : c.uppercased()
            case .shift:
                switch shift {
                case .off: b.setIcon("shift")
                case .once: b.setIcon("shift.fill")
                case .locked: b.setIcon("capslock.fill")
                }
                b.normalColor = shift == .off ? SamsungTheme.keyGray : SamsungTheme.keyWhite
            default:
                break
            }
        }
    }
}
