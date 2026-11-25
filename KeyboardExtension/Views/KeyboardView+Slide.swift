import UIKit

/// 手指按著滑到別的鍵再放開（照 iPhone 原生）：
/// - 按錯了先別放開，滑到對的鍵再放開，送出的是放開時那顆
/// - 按住「符」／「!#1」滑出去：符號頁先跑出來，滑到符號放開，打完還在原本的鍵面；沒選到符號就留在符號頁
/// - 按住 ⇧ 滑到字母放開：打一個大寫
///
/// 手指從頭到尾綁在它按下的那顆鍵（origin）上，所以滑動中不能把那顆鍵拆掉：
/// 符號頁是另外蓋一層上來，原本的鍵面留在底下變透明。
extension KeyboardView {
    struct Slide {
        let origin: KeyButton
        let originSpec: KeySpec
        /// 手指現在停在哪顆會送字的鍵上（不在任何一顆上是 nil）
        var target: KeyButton?
        /// 符號頁先跑出來了
        var peeking = false
        /// 從 ⇧ 滑出來時把 ⇧ 點亮了：沒打出字母就要熄回去
        var litShift = false
    }

    /// 可以從這顆鍵滑出去：送字的鍵、⇧、切鍵面的鍵。
    /// 空白鍵不行（按住要變觸控板，滑出去不該變成打字）、刪除鍵不行（按住是連刪）
    static func canSlide(from spec: KeySpec) -> Bool {
        switch spec.action {
        case .bopomofo, .letter, .text, .shift, .switchMode: true
        default: false
        }
    }

    /// 滑到上面放開會送字的鍵
    static func isCharacterKey(_ spec: KeySpec) -> Bool {
        switch spec.action {
        case .bopomofo, .letter, .text: true
        default: false
        }
    }

    /// 按著的手指動了。離按下的地方夠遠、而且已經比較靠近別顆鍵，才算開始滑
    func touchMoved(_ b: KeyButton, to windowPoint: CGPoint, moved: CGFloat) {
        guard !cursorDragging else { return }
        let point = convert(windowPoint, from: nil)
        if slide == nil {
            guard moved >= SamsungTheme.tapSlop, let spec = specs[b],
                  nearestKey(at: point, among: buttons, specs: specs) !== b,
                  beginSlide(from: b, spec: spec) else { return }
        }
        guard slide?.origin === b else { return }
        updateSlideTarget(at: point)
    }

    private func beginSlide(from b: KeyButton, spec: KeySpec) -> Bool {
        var next = Slide(origin: b, originSpec: spec)
        switch spec.action {
        case .shift:
            if shift == .off {
                shift = .once
                next.litShift = true
            }
        case .switchMode:
            guard let rows = peekRows?(spec) else { return false }
            showPeek(rows)
            next.peeking = true
        default:
            break
        }
        b.beginSliding()
        bubble.hide()
        slide = next
        return true
    }

    private func updateSlideTarget(at point: CGPoint) {
        guard var current = slide else { return }
        let pool = current.peeking ? peekButtons : buttons
        let table = current.peeking ? peekSpecs : specs
        var target: KeyButton?
        // 手指滑出鍵盤太遠，就不算在任何一顆鍵上
        let reach = bounds.insetBy(dx: -SamsungTheme.slideOutMargin, dy: -SamsungTheme.slideOutMargin)
        let near = reach.contains(point) ? nearestKey(at: point, among: pool, specs: table) : nil
        if let near, let spec = table[near], Self.isCharacterKey(spec) {
            target = near
        }
        guard target !== current.target else { return }
        current.target?.showsPressed = false
        target?.showsPressed = true
        current.target = target
        slide = current
        if let target, let spec = table[target], Self.showsBubble(spec) {
            bubble.show(text: target.label.text ?? "", above: target.convert(target.bounds, to: self))
        } else {
            bubble.hide()
        }
    }

    /// 滑動結束。commit：手指放開（送出停著的那顆）；false 是觸控被系統取消（什麼都不送）。
    /// byRollover：快打時被下一顆鍵搶先
    func endSlide(commit: Bool, byRollover: Bool = false) {
        guard let ended = slide else { return }
        slide = nil
        ended.target?.showsPressed = false
        bubble.hide()
        if heldKey === ended.origin {
            heldKey = nil
        }
        let table = ended.peeking ? peekSpecs : specs
        let typed = commit ? ended.target.flatMap { table[$0] } : nil
        if ended.peeking {
            hidePeek()
        }
        if let typed {
            onKey?(typed, [])
        } else if ended.peeking, commit {
            // 沒選到符號就放開：留在符號頁（跟點一下「符」一樣）
            onKey?(ended.originSpec, [])
        }
        // ⇧ 是滑出來時點亮的：打出字母後控制器會自己熄掉；沒打出字母（放在別處、打了標點、被取消）這裡熄回去。
        // 被下一顆鍵搶先時留著：那是「按住 ⇧ 再按字母」
        if ended.litShift, !byRollover, shift == .once {
            shift = .off
        }
    }

    // MARK: - 先跑出來的符號頁

    private func showPeek(_ rows: [KeyRow]) {
        peekButtons.removeAll()
        peekSpecs.removeAll()
        fill(peekStack, with: rows) { spec in
            let b = self.styledButton(spec)
            self.peekSpecs[b] = spec
            self.peekButtons.append(b)
            return b
        }
        applyReturnLabel(to: peekButtons, specs: peekSpecs)
        rowsStack.alpha = 0
        peekStack.isHidden = false
        bringSubviewToFront(bubble)
        layoutIfNeeded()
    }

    func hidePeek() {
        guard !peekStack.isHidden else { return }
        peekStack.isHidden = true
        rowsStack.alpha = 1
        peekStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        peekButtons.removeAll()
        peekSpecs.removeAll()
    }
}
