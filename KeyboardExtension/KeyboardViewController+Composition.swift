import UIKit

/// 組字中的底線文字、送字、工具列（候選字／聯想詞／起頭字）、Shift。
extension KeyboardViewController {
    // MARK: - 組字中的底線文字（跟原生一樣，注音直接顯示在輸入框游標處）

    func syncMarkedText() {
        let composing = engine?.composing ?? ""
        if !composing.isEmpty {
            textDocumentProxy.setMarkedText(
                composing,
                selectedRange: NSRange(location: (composing as NSString).length, length: 0)
            )
            hasMarkedText = true
        } else if hasMarkedText {
            textDocumentProxy.setMarkedText("", selectedRange: NSRange(location: 0, length: 0))
            textDocumentProxy.unmarkText()
            hasMarkedText = false
        }
    }

    /// 把一段確定的字送進輸入框：有底線文字時用它取代，沒有就直接插入
    func commit(_ text: String) {
        guard !text.isEmpty else { return }
        if hasMarkedText {
            textDocumentProxy.setMarkedText(
                text,
                selectedRange: NSRange(location: (text as NSString).length, length: 0)
            )
            textDocumentProxy.unmarkText()
            hasMarkedText = false
        } else {
            textDocumentProxy.insertText(text)
        }
    }

    /// 組字中要送標點、換行、切鍵面、收鍵盤時：整串照第一個候選一路送完
    func commitAllComposing() {
        guard let engine else { return }
        // 打標點、換行、切鍵面時剩下的照預設送出：這段不算一個詞，不學
        learning = LearningSession()
        var out = ""
        while !engine.candidates.isEmpty {
            let piece = engine.selectCandidate(at: 0)
            if piece.isEmpty {
                break
            }
            out += piece
        }
        engine.clear()
        if out.isEmpty {
            syncMarkedText()
        } else {
            commit(out)
        }
    }

    // MARK: - 工具列：候選字／聯想詞／起頭字

    enum BarSource {
        case candidates
        case associations
        case starters
    }

    var barSource: BarSource {
        if let engine, !engine.composing.isEmpty {
            return .candidates
        }
        return associations.isEmpty ? .starters : .associations
    }

    var barItems: [String] {
        switch barSource {
        case .candidates: engine?.candidates ?? []
        case .associations: associations
        case .starters: Self.starters
        }
    }

    func selectFromBar(_ index: Int) {
        switch barSource {
        case .candidates:
            selectCandidate(index)
        case .associations, .starters:
            let items = barItems
            guard index < items.count else { return }
            let text = items[index]
            textDocumentProxy.insertText(text)
            associations = engine?.associatedPhrases(after: text) ?? []
        }
        expanded = false
        refreshBar()
    }

    func selectCandidate(_ index: Int) {
        guard let engine else { return }
        // 選之前先記下：前幾個是引擎自己猜的（整句、第一段），選它們不算改過候選
        let isDefault = index < Int(engine.defaultCandidateCount)
        let text = engine.selectCandidate(at: UInt(index))
        guard !text.isEmpty else { return }
        notePick(text, reading: engine.lastSelectedReading, isDefault: isDefault)
        commit(text)
        if engine.composing.isEmpty {
            finishLearningSession()
            associations = engine.associatedPhrases(after: text)
        } else {
            // 只選走了前面幾個音，剩下的繼續組字
            syncMarkedText()
        }
        expanded = false
        refreshBar()
    }

    func toggleExpand() {
        expanded.toggle()
        refreshBar()
    }

    func refreshBar() {
        let items = barItems
        if items.isEmpty {
            expanded = false
        }
        candidateBar.update(
            candidates: items,
            highlightFirst: barSource == .candidates,
            expanded: expanded
        )
        candidateGrid.isHidden = !expanded || mode != .bopomofo
        // 鍵盤底是透明的：展開候選時把鍵藏起來，不然會從候選後面透出來
        keyboardView.isHidden = !candidateGrid.isHidden
        if expanded {
            candidateGrid.update(items)
        }
    }

    // MARK: - Shift：點一下大寫一個字、連點兩下鎖定大寫、句首自動大寫

    func tapShift() {
        let now = Date()
        let isDoubleTap = now.timeIntervalSince(lastShiftTap) < 0.35
        lastShiftTap = now
        switch keyboardView.shift {
        case .off: keyboardView.shift = .once
        case .once: keyboardView.shift = isDoubleTap ? .locked : .off
        case .locked: keyboardView.shift = .off
        }
    }

    func updateAutoCapitalization() {
        guard mode == .english, keyboardView.shift != .locked, let type = textDocumentProxy.autocapitalizationType,
              type != .none else { return }
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let trimmed = before.trimmingCharacters(in: .whitespaces)
        let atSentenceStart = trimmed.isEmpty
            || before.hasSuffix("\n")
            || (before.hasSuffix(" ") && [".", "!", "?"].contains(trimmed.last.map(String.init) ?? ""))
        let shouldCap: Bool = switch type {
        case .allCharacters: true
        case .words: before.isEmpty || before.hasSuffix(" ") || before.hasSuffix("\n")
        default: atSentenceStart
        }
        if shouldCap, keyboardView.shift == .off {
            keyboardView.shift = .once
        }
    }
}
