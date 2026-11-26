import UIKit

/// 建好的鍵面留著重用：切鍵面時把建好的那幾排換上去，不再整張拆掉重建。
/// 鍵位表的資料逐顆一樣才重用（英文鍵面跟著輸入框變、符號頁和數字鍵盤跟著中英文變）；換了主題整批重建。
/// 不在畫面上的鍵面整個拿下來，不在鍵盤裡：收不到觸控，hitTest 也只找目前這張的鍵
extension KeyboardView {
    /// 一張建好的鍵面
    struct Page {
        let signature: String
        /// 一排排橫向的 stack：放進 rowsStack（目前的鍵面）或 peekStack（先跑出來的符號頁）才看得到
        let rows: [UIStackView]
        let buttons: [KeyButton]
        let specs: [KeyButton: KeySpec]
    }

    /// 最多留幾張：注音、英文、符號 1/2、2/2、數字鍵盤剛好五張；超過就丟最久沒用的
    static let pageLimit = 5

    /// 這張鍵位表建好的鍵面：建過就拿出來用，沒建過現在建
    func cachedPage(for rows: [KeyRow]) -> Page {
        if pagesTheme != SamsungTheme.theme {
            // 字型、圓角、底色是建鍵時照主題定的：換了主題整批重建
            pages.removeAll()
            pagesTheme = SamsungTheme.theme
        }
        let signature = Self.signature(of: rows)
        if let i = pages.firstIndex(where: { $0.signature == signature }) {
            let page = pages.remove(at: i)
            pages.append(page)
            return page
        }
        var keys: [KeyButton] = []
        var table: [KeyButton: KeySpec] = [:]
        let stacks = makeRows(rows) { spec in
            let b = self.makeButton(spec)
            table[b] = spec
            keys.append(b)
            return b
        }
        let page = Page(signature: signature, rows: stacks, buttons: keys, specs: table)
        pages.append(page)
        if pages.count > Self.pageLimit {
            pages.removeFirst()
        }
        return page
    }

    /// 把一張鍵面放進 stack，原本在裡面的那幾排拿下來（鍵留著下次用）。
    /// 鍵的樣子回到剛建好時：滑過時畫成按下的、觸控板中淡掉的字、空白鍵底下的小字，都可能是上次留下的
    func show(_ page: Page, in stack: UIStackView) {
        for b in page.buttons {
            b.showsPressed = false
            b.setContentHidden(false)
            if let spec = page.specs[b], case .space = spec.action {
                b.footLabel.text = spec.foot
            }
        }
        guard !stack.arrangedSubviews.elementsEqual(page.rows, by: ===) else { return }
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        page.rows.forEach { stack.addArrangedSubview($0) }
    }

    /// 按下「符」「!#1」就先把會跑出來的符號頁建好：滑出去時只要蓋上來，不用在手指移動中建整頁。
    /// 點一下去符號頁也是用這張，放開時就不用再建
    func warmPeekPage(for spec: KeySpec) {
        guard case .switchMode = spec.action, let rows = peekRows?(spec) else { return }
        _ = cachedPage(for: rows)
    }

    /// 鍵位表的指紋：每顆鍵的資料逐項接起來。KeySpec 不是 Equatable；
    /// 底色是畫的時候才照主題取值的顏色，比不了，只比有沒有（換主題另外整批重建）
    private static func signature(of rows: [KeyRow]) -> String {
        rows.map { row in
            row.map { s in
                [
                    s.label,
                    String(describing: s.action),
                    String(describing: s.width),
                    String(describing: s.isFunction),
                    String(describing: s.icon),
                    String(describing: s.foot),
                    String(describing: s.longAction),
                    String(describing: s.longHint),
                    String(describing: s.tint != nil),
                    String(describing: s.isTone),
                    String(describing: s.zhuyin),
                ].joined(separator: "\u{1F}")
            }.joined(separator: "\u{1E}")
        }.joined(separator: "\u{1D}")
    }
}
