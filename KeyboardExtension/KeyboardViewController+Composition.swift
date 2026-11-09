import UIKit

/// 組字中的底線文字、送字、工具列（候選字／聯想詞／起頭字）、Shift。
extension KeyboardViewController {
    // MARK: - 組字中的底線文字（跟原生一樣，注音直接顯示在輸入框游標處）

    /// 底線裡顯示「前半段已選好的字＋還在組的注音」
    func syncMarkedText() {
        let composing = engine?.composing ?? ""
        // 注音刪光了：前半段已選好的字直接送出（這段沒選完，不算一個詞，不學）
        if composing.isEmpty, !pendingText.isEmpty {
            let text = pendingText
            pendingText = ""
            learning = LearningSession()
            commit(text)
            return
        }
        let shown = pendingText + composing
        if !shown.isEmpty {
            textDocumentProxy.setMarkedText(
                shown,
                selectedRange: NSRange(location: (shown as NSString).length, length: 0)
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
        var out = pendingText
        pendingText = ""
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

    // MARK: - 工具列：候選字／聯想詞／起頭字／英文預測字

    enum BarSource {
        case candidates
        case associations
        case starters
        case english
    }

    var barSource: BarSource {
        if mode == .english {
            return .english
        }
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
        case .english: englishSuggestions()
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
            let before = String((textDocumentProxy.documentContextBeforeInput ?? "").suffix(2))
            textDocumentProxy.insertText(text)
            noteFollow(text, after: before)
            associations = suggestions(after: before + text)
        case .english:
            let items = barItems
            guard index < items.count else { return }
            pickEnglish(items[index])
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
        let before = composeContext + pendingText
        notePick(text, reading: engine.lastSelectedReading, isDefault: isDefault)
        noteFollow(text, after: before)
        if engine.composing.isEmpty {
            commit(pendingText + text)
            pendingText = ""
            finishLearningSession()
            associations = suggestions(after: before + text)
        } else {
            // 只選走了前面幾個音：選好的字留在底線裡，剩下的繼續組字，
            // 剩下的候選照「選好的字後面通常接什麼」排
            pendingText += text
            engine.setPreferredFollowers(followers(after: before + text))
            syncMarkedText()
        }
        expanded = false
        refreshBar()
    }

    // MARK: - 看游標前面的字：候選和聯想照自己平常的寫法排

    /// 剛開始打注音：記下游標前面的字，候選照「自己平常在這後面打什麼」排
    func startComposingIfNeeded() {
        guard let engine, engine.composing.isEmpty, pendingText.isEmpty else { return }
        composeContext = String((textDocumentProxy.documentContextBeforeInput ?? "").suffix(2))
        engine.setPreferredFollowers(followers(after: composeContext))
    }

    /// 沒在組字時（剛叫出鍵盤、移了游標、刪了字）：工具列擺游標前那個字後面通常接的字詞
    func refreshContextAssociations() {
        guard mode == .bopomofo, pendingText.isEmpty, !hasMarkedText, engine?.composing.isEmpty ?? true else {
            return
        }
        associations = suggestions(after: textDocumentProxy.documentContextBeforeInput ?? "")
        refreshBar()
    }

    /// 聯想詞：自己打過的接續排前面，後面接詞庫的聯想
    func suggestions(after context: String) -> [String] {
        let tail = String(context.suffix(2))
        var out = followers(after: tail)
        for phrase in engine?.associatedPhrases(after: tail) ?? [] where !out.contains(phrase) {
            out.append(phrase)
        }
        return out
    }

    /// 正在打的音打到哪 → 哪一類注音鍵要變寬
    private func currentEmphasis() -> KeyboardView.Emphasis {
        guard mode == .bopomofo, let engine else { return .none }
        switch engine.composingStage {
        case 1: return .afterConsonant
        case 2: return .afterMedial
        default: return .none
        }
    }

    func toggleExpand() {
        clipboardOpen = false
        expanded.toggle()
        refreshBar()
    }

    func refreshBar() {
        keyboardView.emphasis = currentEmphasis()
        let items = barItems
        if items.isEmpty {
            expanded = false
        }
        candidateBar.update(
            candidates: items,
            highlightFirst: barSource == .candidates,
            expanded: expanded,
            clipboardOpen: clipboardOpen
        )
        candidateGrid.isHidden = !expanded || !mode.isLanguage || clipboardOpen
        clipboardPanel.isHidden = !clipboardOpen
        // 鍵盤底是透明的：展開候選、開剪貼簿時把鍵藏起來，不然會從後面透出來
        keyboardView.isHidden = !candidateGrid.isHidden || clipboardOpen
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
