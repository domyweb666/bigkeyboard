import UIKit

/// 把一張鍵位表（資料）渲染成按鍵。所有鍵面共用這一份程式。
final class KeyboardView: UIView {
    var onKey: ((KeySpec) -> Void)?
    var onLongKey: ((KeySpec) -> Void)?
    /// 任何一顆鍵被按下（給按鍵聲、震動用）
    var onAnyPress: ((KeySpec) -> Void)?
    /// 手指離開任何一顆鍵：放開或觸控被系統取消（給機械鍵盤聲的彈回聲用）
    var onAnyRelease: ((KeySpec) -> Void)?
    /// 按住切鍵面的鍵（「符」「!#1」）滑出去：要先跑出來的那張鍵面；nil 表示這顆鍵不這樣用
    var peekRows: ((KeySpec) -> [KeyRow]?)?
    /// 刪除鍵按久了：改成一次刪一截
    var onFastDelete: (() -> Void)?
    /// 刪除鍵按住連刪的每一下（給震動用；按下那一下走 onAnyPress）
    var onRepeatTick: (() -> Void)?
    /// 按住空白鍵拖游標：進入觸控板、手指移動（螢幕座標）、放開
    var onCursorDragBegin: (() -> Void)?
    var onCursorDragMove: ((CGPoint) -> Void)?
    var onCursorDragEnd: (() -> Void)?
    /// 按住空白鍵變成觸控板中：鍵上的字淡掉，其他鍵按不到
    private(set) var cursorDragging = false

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

    /// 動態感應範圍：正在打的音打到哪，下一顆可能按的那類注音鍵感應範圍變大（外觀不變，跟原生鍵盤一樣）
    enum Emphasis {
        case none
        /// 只打了聲母 → 介音、韻母好按
        case afterConsonant
        /// 打到介音 → 韻母好按
        case afterMedial
    }

    var emphasis: Emphasis = .none

    let rowsStack = UIStackView()
    /// 按住「符」滑出去時先蓋上來的符號頁。原本的鍵留在底下不拆：拆掉的話按著的那根手指就斷了
    let peekStack = UIStackView()
    var peekButtons: [KeyButton] = []
    var peekSpecs: [KeyButton: KeySpec] = [:]
    var slide: Slide?
    /// 換行鍵目前顯示的字（先跑出來的符號頁也要一樣）
    private var returnLabel: String?
    let bubble = KeyPreviewBubble()
    private(set) var buttons: [KeyButton] = []
    private(set) var specs: [KeyButton: KeySpec] = [:]
    /// 目前按著還沒放開的那顆（快打時判斷「上一顆還沒放、下一顆已按下」）
    weak var heldKey: KeyButton?

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = SamsungTheme.keyAreaBackground
        for stack in [rowsStack, peekStack] {
            stack.axis = .vertical
            stack.spacing = SamsungTheme.rowGap
            stack.distribution = .fillEqually
            stack.translatesAutoresizingMaskIntoConstraints = false
            addSubview(stack)
            NSLayoutConstraint.activate([
                stack.topAnchor.constraint(equalTo: topAnchor, constant: SamsungTheme.rowGap),
                stack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SamsungTheme.rowGap),
                stack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SamsungTheme.sideInset),
                stack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SamsungTheme.sideInset),
            ])
        }
        peekStack.isHidden = true
        peekStack.isUserInteractionEnabled = false
        addSubview(bubble)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    /// 整塊鍵盤區沒有死角：按在鍵與鍵、排與排之間的縫，或最外圈的邊上，都算離手指最近的那顆鍵。
    /// 只放大單顆鍵的 point(inside:) 不夠：排與排之間的縫不屬於任何一排，觸控根本到不了鍵
    /// 下一顆可能按的鍵：距離先扣掉一段，按在它旁邊那顆鍵的邊上也算按到它
    override func hitTest(_ location: CGPoint, with _: UIEvent?) -> UIView? {
        guard !isHidden, isUserInteractionEnabled, bounds.contains(location) else { return nil }
        // 觸控板中、符號頁先跑出來時：別的手指碰到鍵盤不算按鍵（原本那根手指一直綁在它按下的那顆鍵上）
        if cursorDragging || slide?.peeking == true {
            return self
        }
        return nearestKey(at: location, among: buttons, specs: specs) ?? self
    }

    /// 離手指最近的那顆鍵（落點先往上修、下一顆可能按的鍵多吃一點邊）
    func nearestKey(
        at location: CGPoint,
        among pool: [KeyButton],
        specs table: [KeyButton: KeySpec]
    ) -> KeyButton? {
        let active = expectedEmphasis()
        // 人習慣按在目標偏下方：落點先往上修一點再找最近的鍵
        let lifted = CGPoint(x: location.x, y: location.y - SamsungTheme.touchLiftPoints)
        var nearest: KeyButton?
        var nearestDistance = CGFloat.greatestFiniteMagnitude
        for b in pool {
            let f = b.convert(b.bounds, to: self)
            let dx = max(f.minX - lifted.x, 0, lifted.x - f.maxX)
            let dy = max(f.minY - lifted.y, 0, lifted.y - f.maxY)
            var d = (dx * dx + dy * dy).squareRoot()
            if let spec = table[b], Self.isLikely(spec, after: active) {
                d -= SamsungTheme.likelyKeyTouchMargin
            }
            if d < nearestDistance {
                nearestDistance = d
                nearest = b
            }
        }
        return nearest
    }

    /// 快打時上一顆注音還按著、還沒送進引擎：照它是哪一類先推算（聲母之後一定是只有聲母、介音之後一定到介音）
    private func expectedEmphasis() -> Emphasis {
        guard let held = heldKey, let group = specs[held]?.zhuyin else { return emphasis }
        switch group {
        case .consonant: return .afterConsonant
        case .medial: return .afterMedial
        case .final, .tone: return .none
        }
    }

    private static func isLikely(_ spec: KeySpec, after emphasis: Emphasis) -> Bool {
        switch (emphasis, spec.zhuyin) {
        case (.afterConsonant, .medial), (.afterConsonant, .final), (.afterMedial, .final): true
        default: false
        }
    }

    func load(_ rows: [KeyRow]) {
        bubble.applyTheme()
        // 鍵面整個換掉：滑到一半、符號頁先跑出來的都作廢
        slide = nil
        hidePeek()
        cursorDragging = false
        buttons.removeAll()
        specs.removeAll()
        fill(rowsStack, with: rows) { spec in
            let b = self.makeButton(spec)
            self.specs[b] = spec
            self.buttons.append(b)
            return b
        }
        bringSubviewToFront(bubble)
        applyShiftAppearance()
    }

    private func makeButton(_ spec: KeySpec) -> KeyButton {
        let b = styledButton(spec)
        if case .backspace = spec.action {
            // 刪除鍵：按下立刻刪、按住連刪
            b.onRepeat = { [weak self, weak b] in self?.backspaceFired(spec, repeats: b?.repeatCount ?? 0) }
        } else {
            b.onTap = { [weak self] in self?.onKey?(spec) }
        }
        if case .space = spec.action {
            // 按住空白鍵：整塊鍵盤變觸控板，拖著移游標（照 iPhone 原生）
            b.onLongPress = { [weak self, weak b] in
                self?.setCursorDragging(true)
                // 從手指現在的位置起算：不然進觸控板後的第一小段移動會被當成起點吃掉
                if let b {
                    self?.onCursorDragMove?(b.trackLast)
                }
            }
            b.onDragAfterLongPress = { [weak self] p in self?.onCursorDragMove?(p) }
            b.onLongPressEnd = { [weak self] in self?.setCursorDragging(false) }
        } else if spec.longAction != nil {
            b.onLongPress = { [weak self] in self?.onLongKey?(spec) }
        }
        if Self.canSlide(from: spec) {
            b.onTrackMove = { [weak self, weak b] point, moved in
                guard let self, let b else { return }
                touchMoved(b, to: point, moved: moved)
            }
            b.onSlideEnd = { [weak self] released in self?.endSlide(commit: released) }
        }
        b.addAction(
            UIAction { [weak self] _ in self?.onAnyRelease?(spec) },
            for: [.touchUpInside, .touchUpOutside, .touchCancel]
        )
        let showsBubble = Self.showsBubble(spec)
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
        return b
    }

    static func showsBubble(_ spec: KeySpec) -> Bool {
        !spec.isFunction && !spec.label.isEmpty
    }

    /// 記住按著的那顆。快打時上一顆還沒放開、下一顆已經按下：上一顆先算按完，送字順序才不會顛倒
    private func trackHeld(_ b: KeyButton, pressed: Bool) {
        guard pressed else {
            if heldKey === b {
                heldKey = nil
            }
            return
        }
        if let held = heldKey, held !== b {
            if slide?.origin === held {
                // 上一根手指正滑在別的鍵上：先把它滑到的那顆送出
                endSlide(commit: true, byRollover: true)
                held.commitSlideEarly()
            } else if let s = specs[held], Self.firesEarlyOnRollover(s) {
                held.fireNow()
            }
        }
        heldKey = b
        if let spec = specs[b] {
            onAnyPress?(spec)
        }
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
        returnLabel = text
        applyReturnLabel(to: buttons, specs: specs)
    }

    /// 空白鍵底下的小字（組字時顯示「一聲」「選字」）；nil 回到鍵位表寫的
    func setSpaceFoot(_ text: String?) {
        for b in buttons {
            guard let spec = specs[b], case .space = spec.action else { continue }
            b.footLabel.text = text ?? spec.foot
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

// MARK: - 排鍵、鍵的長相、刪除連發、觸控板

extension KeyboardView {
    /// 把一張鍵位表排進一個直向的 stack（原本的鍵面和先跑出來的符號頁共用）
    func fill(_ stack: UIStackView, with rows: [KeyRow], make: (KeySpec) -> KeyButton) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = SamsungTheme.keyGap
            rowStack.alignment = .fill
            let total = row.reduce(0) { $0 + $1.width }
            let gaps = SamsungTheme.keyGap * CGFloat(row.count - 1)
            for spec in row {
                // 空位不是鍵：按在上面由 hitTest 算給最近的鍵
                let b: UIView = if case .spacer = spec.action {
                    UIView()
                } else {
                    make(spec)
                }
                rowStack.addArrangedSubview(b)
                b.widthAnchor.constraint(
                    equalTo: rowStack.widthAnchor,
                    multiplier: spec.width / total,
                    constant: -gaps * spec.width / total
                ).isActive = true
            }
            stack.addArrangedSubview(rowStack)
        }
    }

    /// 一顆鍵的長相（字、圖示、小字、底色），還沒接上按下去要做的事
    func styledButton(_ spec: KeySpec) -> KeyButton {
        let b = KeyButton()
        b.label.text = spec.label
        if spec.isTone {
            b.label.font = SamsungTheme.keyFont(ofSize: SamsungTheme.toneFontSize, bold: true)
        } else {
            let fontSize = spec.isFunction ? SamsungTheme.functionFontSize : SamsungTheme.keyFontSize
            b.label.font = SamsungTheme.keyFont(ofSize: fontSize)
        }
        b.hintLabel.text = spec.longHint
        if spec.isFunction {
            // 灰色功能鍵上灰字對比不夠，改用主字色
            b.hintLabel.textColor = SamsungTheme.keyText
        }
        b.footLabel.text = spec.foot
        b.setIcon(spec.icon)
        b.normalColor = spec.tint ?? (spec.isFunction ? SamsungTheme.keyGray : SamsungTheme.keyWhite)
        return b
    }

    /// 刪除鍵：按下刪一個；按住連刪，連刪夠久之後每幾下刪一截
    private func backspaceFired(_ spec: KeySpec, repeats: Int) {
        let fast = repeats - SamsungTheme.fastDeleteAfterRepeats
        if fast < 0 {
            onKey?(spec)
        } else if fast % SamsungTheme.fastDeleteEveryRepeats == 0 {
            onFastDelete?()
        } else {
            return
        }
        if repeats > 0 {
            onRepeatTick?()
        }
    }

    private func setCursorDragging(_ on: Bool) {
        guard on != cursorDragging else { return }
        cursorDragging = on
        bubble.hide()
        UIView.animate(withDuration: SamsungTheme.cursorFadeSeconds) {
            for b in self.buttons {
                b.setContentHidden(on)
            }
        }
        if on {
            onCursorDragBegin?()
        } else {
            onCursorDragEnd?()
        }
    }

    func applyReturnLabel(to pool: [KeyButton], specs table: [KeyButton: KeySpec]) {
        for b in pool {
            guard let spec = table[b], case .newline = spec.action else { continue }
            if let returnLabel {
                b.setIcon(nil)
                b.label.text = returnLabel
            } else {
                b.setIcon(spec.icon)
                b.label.text = spec.label
            }
        }
    }
}
