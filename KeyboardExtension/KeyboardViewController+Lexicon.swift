import UIKit

/// iPhone 設定裡的「替代文字」：輸入碼 → 片語
struct TextReplacements: Equatable {
    private var exact: [String: [String]] = [:]
    /// 輸入碼轉小寫（英文不分大小寫時查）
    private var folded: [String: [String]] = [:]

    init() {}

    init(_ pairs: [(code: String, phrase: String)]) {
        for (code, phrase) in pairs where code != phrase && !code.isEmpty && !phrase.isEmpty {
            Self.add(phrase, for: code, to: &exact)
            Self.add(phrase, for: code.lowercased(), to: &folded)
        }
    }

    var isEmpty: Bool {
        exact.isEmpty
    }

    /// 輸入碼完全一樣的片語（同一個碼可以有好幾個）
    func phrases(for code: String) -> [String] {
        exact[code] ?? []
    }

    /// 打的英文碼對到的片語：先比大小寫完全一樣，再不分大小寫
    func phrase(typed code: String) -> String? {
        exact[code]?.first ?? folded[code.lowercased()]?.first
    }

    private static func add(_ phrase: String, for code: String, to table: inout [String: [String]]) {
        guard table[code]?.contains(phrase) != true else { return }
        table[code, default: []].append(phrase)
    }
}

/// 剛用空白鍵把輸入碼換成片語：緊接著按 ⌫ 要還原
struct TypedReplacement {
    let code: String
    /// 送進輸入框的（片語＋空白）
    let inserted: String
    /// 換之前游標前面的字（App 回報慢半拍時認得出來）
    let contextBefore: String
    /// 已經還原：緊接著再按空白不再換，不然永遠打不出那個碼
    var undone = false
}

/// 替代文字：注音的片語排候選第一個；英文、符號、數字鍵面按空白時換掉。不存檔、不學
extension KeyboardViewController {
    /// 跟系統要一次替代文字。系統可能在背景、也可能鍵盤出現之後才給：整理完回主執行緒再換上
    func loadReplacements() {
        requestSupplementaryLexicon { [weak self] lexicon in
            let found = TextReplacements(lexicon.entries.map { (code: $0.userInput, phrase: $0.documentText) })
            DispatchQueue.main.async { [weak self] in
                self?.applyReplacements(found)
            }
        }
    }

    /// 正在組的注音剛好受影響才重畫候選
    private func applyReplacements(_ found: TextReplacements) {
        guard found != replacements else { return }
        let before = replacementCandidates
        replacements = found
        if replacementCandidates != before {
            refreshBar()
        }
    }

    // MARK: - 注音：片語排在引擎的候選前面

    /// 組字中的注音（去空白、去一聲記號）等於某個輸入碼時的片語。有幾個，引擎的候選就往後移幾位
    var replacementCandidates: [String] {
        guard !replacements.isEmpty, pendingText.isEmpty, let engine else { return [] }
        return replacements.phrases(for: engine.composing.filter { $0 != " " && $0 != "ˉ" })
    }

    /// 選了片語：組字清空，不學詞、不記接續
    func selectReplacement(_ phrase: String) {
        let before = composeContext
        engine?.clear()
        learning = LearningSession()
        commit(phrase)
        associations = suggestions(after: before + phrase)
        expanded = false
        refreshBar()
    }

    // MARK: - 英文、符號、數字鍵面：按空白換成片語

    /// 游標前那串非空白 ASCII（整串）剛好是輸入碼，按空白要換成的片語。last 是上一顆鍵換的（剛還原的不再換）
    func typedReplacement(after last: TypedReplacement?) -> (code: String, phrase: String)? {
        guard mode != .bopomofo, !replacements.isEmpty, !hasSelection,
              let before = textDocumentProxy.documentContextBeforeInput else { return nil }
        let run = before.reversed().prefix { $0.isASCII && !$0.isWhitespace }
        let code = String(run.reversed())
        guard !code.isEmpty, let phrase = replacements.phrase(typed: code) else { return nil }
        if let last, last.undone, last.code == code {
            return nil
        }
        return (code, phrase)
    }

    /// 按空白：換成片語、補空白。沒有對到回傳 false，照平常送空白
    func replaceTypedCode(after last: TypedReplacement?) -> Bool {
        guard let found = typedReplacement(after: last) else { return false }
        let inserted = found.phrase + " "
        lastReplacement = TypedReplacement(
            code: found.code,
            inserted: inserted,
            contextBefore: textDocumentProxy.documentContextBeforeInput ?? ""
        )
        for _ in 0 ..< found.code.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(inserted)
        associations = []
        return true
    }

    /// 剛換完就按 ⌫：還原成原本打的碼（不含空白）。游標已經不在片語後面（在 App 裡點到別處）就不還原，照平常刪
    func undoReplacement(_ last: TypedReplacement?) -> Bool {
        guard var last, !last.undone, !hasSelection,
              let now = textDocumentProxy.documentContextBeforeInput, !now.isEmpty else { return false }
        // App 給的前文可能只有尾巴一段，也可能還停在換之前
        guard now.hasSuffix(last.inserted) || last.inserted.hasSuffix(now) || now == last.contextBefore else {
            return false
        }
        for _ in 0 ..< last.inserted.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(last.code)
        last.undone = true
        lastReplacement = last
        return true
    }

    /// 選取了一段字：這時刪除是刪選取的字，不能照字數刪
    private var hasSelection: Bool {
        textDocumentProxy.selectedText?.isEmpty == false
    }
}
