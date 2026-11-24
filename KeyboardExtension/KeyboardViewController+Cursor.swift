import UIKit

/// 按住空白鍵拖游標的狀態。
/// 第一次真的要移時，拍一張游標前後的字（快照），之後在快照裡算位置：
/// 這樣表情符號這類一個字占兩格的，也能一次移過整個字；上下拖也找得到這行的頭尾。
struct CursorDrag {
    /// 上一次手指的位置與時間（算這次拖了多遠、多快）
    var lastPoint: CGPoint?
    var lastTime: CFTimeInterval = 0
    /// 還不到一個字、一行的零頭，留著跟下一次一起算
    var restX: CGFloat = 0
    var restY: CGFloat = 0
    /// 游標前後的字（快照）；還沒拍是 nil
    var text: [Character]?
    /// 游標在快照裡的位置（第幾個字前面）
    var position = 0
}

/// 按住空白鍵拖游標（照 iPhone 原生）：按住 0.4 秒整塊鍵盤變觸控板，
/// 左右拖一個字一個字移、拖越快跳越多；往上拖到這行開頭（已在開頭就到上一行開頭），往下拖到這行結尾。
/// 第三方鍵盤拿不到「上一行同一個位置」，所以上下拖是跳行頭行尾，不是原生那種換行。
extension KeyboardViewController {
    func beginCursorDrag() {
        // 一進來就震，跟鍵上的字淡掉同一刻；馬達在空白鍵按下時就叫醒了。
        // 鍵盤擴充要開完全取用才震得了；沒開就只是不震
        keyHaptic.impactOccurred()
        // 組到一半的注音先照第一個候選送出，再移游標（跟原生一樣）
        commitAllComposing()
        associations = []
        englishAutoSpace = false
        expanded = false
        cursorDrag = CursorDrag()
        refreshBar()
    }

    func moveCursorDrag(to point: CGPoint) {
        guard var drag = cursorDrag else { return }
        let now = CACurrentMediaTime()
        defer {
            drag.lastPoint = point
            drag.lastTime = now
            cursorDrag = drag
        }
        guard let last = drag.lastPoint else { return }

        let dx = point.x - last.x
        let dt = max(now - drag.lastTime, 0.001)
        let speed = abs(dx) / CGFloat(dt)
        let boost = min(max(speed / SamsungTheme.cursorFastSpeed, 1), SamsungTheme.cursorMaxAcceleration)
        drag.restX += dx * boost
        drag.restY += point.y - last.y

        let chars = Int(drag.restX / SamsungTheme.cursorPointsPerCharacter)
        drag.restX -= CGFloat(chars) * SamsungTheme.cursorPointsPerCharacter
        let lines = Int(drag.restY / SamsungTheme.cursorPointsPerLine)
        drag.restY -= CGFloat(lines) * SamsungTheme.cursorPointsPerLine
        guard chars != 0 || lines != 0 else { return }

        if drag.text == nil {
            takeSnapshot(&drag)
        }
        var target = drag.position + chars
        if target < 0 || target > (drag.text?.count ?? 0) {
            target = extendSnapshot(&drag, toward: target)
        }
        for _ in 0 ..< abs(lines) {
            target = lines < 0 ? Self.lineStart(above: target, in: drag.text ?? [])
                : Self.lineEnd(below: target, in: drag.text ?? [])
        }
        let offset = Self.utf16Distance(from: drag.position, to: target, in: drag.text ?? [])
        if offset != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: offset)
        }
        drag.position = target
    }

    func endCursorDrag() {
        cursorDrag = nil
        // 工具列照新游標前面的字擺聯想（英文鍵面照游標前的字給預測）
        refreshContextAssociations()
        refreshBar()
    }

    // MARK: - 快照

    private func takeSnapshot(_ drag: inout CursorDrag) {
        let before = Array(textDocumentProxy.documentContextBeforeInput ?? "")
        let after = Array(textDocumentProxy.documentContextAfterInput ?? "")
        drag.text = before + after
        drag.position = before.count
    }

    /// 拖到快照的邊了：App 給的前後文常常只有一段，游標停下來之後再問一次，接上更前面（或更後面）的字。
    /// 問到的跟快照對不起來（App 還沒跟上），或真的到了整篇的頭尾，就停在邊上
    private func extendSnapshot(_ drag: inout CursorDrag, toward target: Int) -> Int {
        let text = drag.text ?? []
        let edge = target < 0 ? 0 : text.count
        // 先移到邊上，App 那邊的游標才會跟快照的邊對齊
        let toEdge = Self.utf16Distance(from: drag.position, to: edge, in: text)
        if toEdge != 0 {
            textDocumentProxy.adjustTextPosition(byCharacterOffset: toEdge)
        }
        drag.position = edge

        let before = Array(textDocumentProxy.documentContextBeforeInput ?? "")
        let after = Array(textDocumentProxy.documentContextAfterInput ?? "")
        // App 的游標真的在快照的邊上：往左時快照開頭接在 after 前頭；往右時快照結尾是 before 的尾巴
        let probe = 8
        let lined = target < 0
            ? after.starts(with: text.prefix(probe))
            : before.reversed().starts(with: text.suffix(probe).reversed())
        let hasMore = target < 0 ? !before.isEmpty : !after.isEmpty
        guard lined, hasMore else {
            return edge
        }
        drag.text = before + after
        drag.position = before.count
        let moved = target - edge
        return min(max(drag.position + moved, 0), before.count + after.count)
    }

    // MARK: - 在快照裡算位置

    /// 往上一次：到這行開頭；已經在開頭就到上一行開頭
    static func lineStart(above i: Int, in text: [Character]) -> Int {
        guard i > 0, i <= text.count else { return i }
        func start(of j: Int) -> Int {
            var k = j
            while k > 0, text[k - 1] != "\n" {
                k -= 1
            }
            return k
        }
        let s = start(of: i)
        return s == i ? start(of: i - 1) : s
    }

    /// 往下一次：到這行結尾；已經在結尾就到下一行結尾
    static func lineEnd(below i: Int, in text: [Character]) -> Int {
        guard i >= 0, i < text.count else { return i }
        func end(of j: Int) -> Int {
            var k = j
            while k < text.count, text[k] != "\n" {
                k += 1
            }
            return k
        }
        let e = end(of: i)
        return e == i ? end(of: i + 1) : e
    }

    /// 從 a 移到 b 要叫系統移幾格：系統一格是一個 UTF-16 單位，表情符號一個字占兩格以上。
    /// 快照外面不知道是什麼字，一個字算一格
    static func utf16Distance(from a: Int, to b: Int, in text: [Character]) -> Int {
        guard a != b else { return 0 }
        var n = 0
        for k in min(a, b) ..< max(a, b) {
            n += text.indices.contains(k) ? text[k].utf16.count : 1
        }
        return b > a ? n : -n
    }
}
