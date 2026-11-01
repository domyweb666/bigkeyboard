import UIKit

/// 讓系統的「鍵盤按鍵聲」設定生效：鍵盤的 inputView 要宣告支援輸入音效，UIDevice.playInputClick() 才會響。
/// 不需要「允許完全取用」，而且會遵守使用者在 設定 → 聲音與觸覺 → 鍵盤回饋 的選擇。
final class KeyboardInputView: UIInputView, UIInputViewAudioFeedback {
    var enableInputClicksWhenVisible: Bool {
        true
    }
}

/// 鍵盤殼：iOS 叫起鍵盤時的入口。管模式切換、把鍵的動作轉成引擎呼叫或送字，記住上次的模式。
final class KeyboardViewController: UIInputViewController {
    private let candidateBar = CandidateBar()
    private let keyboardView = KeyboardView()
    private let candidateGrid = CandidateGrid()
    private var heightConstraint: NSLayoutConstraint?
    private var barShown: NSLayoutConstraint?
    private var barHidden: NSLayoutConstraint?
    private var engine: BopomofoEngine?

    private static let modeKey = "lastMode"
    private static let languageKey = "lastLanguage"

    /// 打字前、還沒有上下文時，工具列先擺常用的起頭字，不留一條空白
    private static let starters = ["我", "你", "好", "這", "那", "是", "在", "有", "不", "要", "如果", "但是", "因為", "所以"]

    /// 目前鍵面
    private var mode: KeyboardMode = .bopomofo
    /// 符號頁／數字鍵盤要回去的語言鍵面
    private var language: KeyboardMode = .bopomofo

    /// 輸入框裡目前有沒有我們放的「組字中」底線文字
    private var hasMarkedText = false
    /// 剛送出字之後的聯想詞
    private var associations: [String] = []
    /// 工具列展開成全部候選
    private var expanded = false
    private var lastShiftTap = Date.distantPast

    // MARK: - 生命週期

    override func loadView() {
        inputView = KeyboardInputView(frame: .zero, inputViewStyle: .default)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SamsungTheme.background

        let bundle = Bundle.main
        if let path = bundle.path(forResource: "mcbopomofo-data", ofType: "txt") {
            engine = BopomofoEngine(
                dataPath: path,
                associatedPath: bundle.path(forResource: "mcbopomofo-associated", ofType: "txt")
            )
        }

        candidateBar.onSelect = { [weak self] i in self?.selectFromBar(i) }
        candidateBar.onToggleExpand = { [weak self] in self?.toggleExpand() }
        candidateGrid.onSelect = { [weak self] i in self?.selectFromBar(i) }
        keyboardView.onKey = { [weak self] spec in self?.handle(spec) }
        keyboardView.onLongKey = { [weak self] spec in self?.handleLongPress(spec) }
        keyboardView.onAnyPress = { UIDevice.current.playInputClick() }
        candidateGrid.isHidden = true

        for v in [candidateBar, keyboardView, candidateGrid] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        let shown = candidateBar.heightAnchor.constraint(
            equalTo: view.heightAnchor,
            multiplier: SamsungTheme.toolbarHeightRatio
        )
        let hidden = candidateBar.heightAnchor.constraint(equalToConstant: 0)
        barShown = shown
        barHidden = hidden

        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            shown,

            keyboardView.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            candidateGrid.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            candidateGrid.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            candidateGrid.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            candidateGrid.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
        ])

        restoreMode()
        showMode()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyHeight()
        engine?.clear()
        hasMarkedText = false
        associations = []
        expanded = false
        updateAutoCapitalization()
        refreshBar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        // 鍵盤收起時，組到一半的注音就照第一個候選送出，不讓打的字消失
        commitAllComposing()
        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.applyHeight() })
    }

    private func applyHeight() {
        guard let screen = view.window?.windowScene?.screen ?? view.window?.screen else { return }
        let h = SamsungTheme.keyboardHeight(for: screen)
        if let c = heightConstraint {
            c.constant = h
        } else {
            let c = view.heightAnchor.constraint(equalToConstant: h)
            c.priority = .init(999)
            c.isActive = true
            heightConstraint = c
        }
    }

    // MARK: - 模式

    private func restoreMode() {
        let d = UserDefaults.standard
        if let raw = d.string(forKey: Self.languageKey), let m = KeyboardMode(rawValue: raw), m.isLanguage {
            language = m
        }
        if let raw = d.string(forKey: Self.modeKey), let m = KeyboardMode(rawValue: raw) {
            mode = m
        } else {
            mode = language
        }
    }

    private func setMode(_ newMode: KeyboardMode) {
        if newMode.isLanguage {
            language = newMode
        }
        mode = newMode
        let d = UserDefaults.standard
        d.set(mode.rawValue, forKey: Self.modeKey)
        d.set(language.rawValue, forKey: Self.languageKey)
        showMode()
    }

    private func showMode() {
        let chinese = language == .bopomofo
        switch mode {
        case .bopomofo:
            keyboardView.load(BopomofoLayout.rows)
        case .english:
            keyboardView.load(EnglishLayout.rows)
        case .symbols1:
            keyboardView.load(SymbolLayout.page1(chinese: chinese))
        case .symbols2:
            keyboardView.load(SymbolLayout.page2(chinese: chinese))
        case .numpad:
            keyboardView.load(NumpadLayout.rows(chinese: chinese))
        }
        // 工具列只在注音鍵面出現；其他鍵面總高度不變，空間讓給鍵（鍵變高、更好按）
        let showBar = mode == .bopomofo
        barShown?.isActive = false
        barHidden?.isActive = false
        (showBar ? barShown : barHidden)?.isActive = true
        candidateBar.isHidden = !showBar
        expanded = false
        keyboardView.shift = .off
        updateAutoCapitalization()
        refreshBar()
    }

    // MARK: - 鍵 → 引擎 → 輸入框

    private func handle(_ spec: KeySpec) {
        switch spec.action {
        case let .bopomofo(symbol):
            associations = []
            _ = engine?.feedSymbol(symbol)
            syncMarkedText()

        case let .letter(c):
            let out = keyboardView.shift == .off ? c : c.uppercased()
            textDocumentProxy.insertText(out)
            if keyboardView.shift == .once {
                keyboardView.shift = .off
            }

        case let .text(s):
            commitAllComposing()
            textDocumentProxy.insertText(s)
            associations = []

        case .space:
            if let engine, !engine.candidates.isEmpty {
                selectCandidate(0)
            } else if let engine, !engine.composing.isEmpty {
                engine.clear() // 殘留、接不上字的注音，丟掉
                syncMarkedText()
            } else {
                textDocumentProxy.insertText(" ")
                associations = []
            }

        case .newline:
            commitAllComposing()
            textDocumentProxy.insertText("\n")
            associations = []

        case .backspace:
            if engine?.backspace() == true {
                syncMarkedText()
            } else {
                textDocumentProxy.deleteBackward()
                associations = []
            }

        case .shift:
            tapShift()

        case .toggleLanguage:
            commitAllComposing()
            associations = []
            setMode(language == .bopomofo ? .english : .bopomofo)

        case let .switchMode(m):
            commitAllComposing()
            associations = []
            setMode(m)

        case .backToLanguage:
            setMode(language)
        }
        if mode == .english {
            updateAutoCapitalization()
        }
        refreshBar()
    }

    private func handleLongPress(_ spec: KeySpec) {
        guard let alt = spec.altText else { return }
        commitAllComposing()
        textDocumentProxy.insertText(alt)
        associations = []
        refreshBar()
    }

    // MARK: - 組字中的底線文字（跟原生一樣，注音直接顯示在輸入框游標處）

    private func syncMarkedText() {
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
    private func commit(_ text: String) {
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
    private func commitAllComposing() {
        guard let engine else { return }
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

    private enum BarSource {
        case candidates
        case associations
        case starters
    }

    private var barSource: BarSource {
        if let engine, !engine.composing.isEmpty {
            return .candidates
        }
        return associations.isEmpty ? .starters : .associations
    }

    private var barItems: [String] {
        switch barSource {
        case .candidates: engine?.candidates ?? []
        case .associations: associations
        case .starters: Self.starters
        }
    }

    private func selectFromBar(_ index: Int) {
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

    private func selectCandidate(_ index: Int) {
        guard let engine else { return }
        let text = engine.selectCandidate(at: UInt(index))
        guard !text.isEmpty else { return }
        commit(text)
        if engine.composing.isEmpty {
            associations = engine.associatedPhrases(after: text)
        } else {
            // 只選走了前面幾個音，剩下的繼續組字
            syncMarkedText()
        }
        expanded = false
        refreshBar()
    }

    private func toggleExpand() {
        expanded.toggle()
        refreshBar()
    }

    private func refreshBar() {
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
        if expanded {
            candidateGrid.update(items)
        }
    }

    // MARK: - Shift：點一下大寫一個字、連點兩下鎖定大寫、句首自動大寫

    private func tapShift() {
        let now = Date()
        let isDoubleTap = now.timeIntervalSince(lastShiftTap) < 0.35
        lastShiftTap = now
        switch keyboardView.shift {
        case .off: keyboardView.shift = .once
        case .once: keyboardView.shift = isDoubleTap ? .locked : .off
        case .locked: keyboardView.shift = .off
        }
    }

    private func updateAutoCapitalization() {
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
