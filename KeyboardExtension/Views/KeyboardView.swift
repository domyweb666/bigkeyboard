import UIKit

/// 把一張鍵位表（資料）渲染成按鍵。所有鍵面共用這一份程式。
final class KeyboardView: UIView {
    var onKey: ((KeySpec) -> Void)?
    var onLongKey: ((KeySpec) -> Void)?
    /// 任何一顆鍵被按下（給按鍵聲用）
    var onAnyPress: (() -> Void)?

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

    private let rowsStack = UIStackView()
    private let bubble = KeyPreviewBubble()
    private var buttons: [KeyButton] = []
    private var specs: [KeyButton: KeySpec] = [:]

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

    func load(_ rows: [KeyRow]) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        buttons.removeAll()
        specs.removeAll()
        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = SamsungTheme.keyGap
            rowStack.alignment = .fill
            let total = row.reduce(0) { $0 + $1.width }
            let gaps = SamsungTheme.keyGap * CGFloat(row.count - 1)
            for spec in row {
                let b = makeButton(spec)
                rowStack.addArrangedSubview(b)
                b.widthAnchor.constraint(
                    equalTo: rowStack.widthAnchor,
                    multiplier: spec.width / total,
                    constant: -gaps * spec.width / total
                ).isActive = true
            }
            rowsStack.addArrangedSubview(rowStack)
        }
        bringSubviewToFront(bubble)
        applyShiftAppearance()
    }

    private func makeButton(_ spec: KeySpec) -> KeyButton {
        let b = KeyButton()
        b.label.text = spec.label
        let fontSize = spec.isFunction ? SamsungTheme.functionFontSize : SamsungTheme.keyFontSize
        b.label.font = .systemFont(ofSize: fontSize)
        b.hintLabel.text = spec.alt
        b.footLabel.text = spec.foot
        b.setIcon(spec.icon)
        b.normalColor = spec.isFunction ? SamsungTheme.keyGray : SamsungTheme.keyWhite

        if case .backspace = spec.action {
            // 刪除鍵：按下立刻刪、按住連刪
            b.onRepeat = { [weak self] in self?.onKey?(spec) }
        } else {
            b.onTap = { [weak self] in self?.onKey?(spec) }
        }
        if spec.alt != nil {
            b.onLongPress = { [weak self] in self?.onLongKey?(spec) }
        }
        let showsBubble = !spec.isFunction && !spec.label.isEmpty
        b.onPressChanged = { [weak self, weak b] pressed in
            guard let self, let b else { return }
            if pressed {
                onAnyPress?()
            }
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
