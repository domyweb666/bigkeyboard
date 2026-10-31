import UIKit

/// 鍵盤殼：iOS 叫起鍵盤時的入口。管模式切換、把鍵的動作轉成引擎呼叫或送字，記住上次的模式。
final class KeyboardViewController: UIInputViewController {
    private let candidateBar = CandidateBar()
    private let keyboardView = KeyboardView()
    private var heightConstraint: NSLayoutConstraint?
    private var engine: BopomofoEngine?

    private static let modeKey = "lastMode"
    private static let languageKey = "lastLanguage"

    /// 目前鍵面
    private var mode: KeyboardMode = .bopomofo
    /// 符號頁／數字鍵盤要回去的語言鍵面
    private var language: KeyboardMode = .bopomofo

    // MARK: - 生命週期

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SamsungTheme.background

        if let path = Bundle.main.path(forResource: "mcbopomofo-data", ofType: "txt") {
            engine = BopomofoEngine(dataPath: path)
        }

        candidateBar.onSelect = { [weak self] i in self?.select(i) }
        keyboardView.onKey = { [weak self] spec in self?.handle(spec) }
        keyboardView.onLongKey = { [weak self] spec in self?.handleLongPress(spec) }

        for v in [candidateBar, keyboardView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            candidateBar.heightAnchor.constraint(
                equalTo: view.heightAnchor,
                multiplier: SamsungTheme.toolbarHeightRatio
            ),

            keyboardView.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            keyboardView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyboardView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyboardView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        restoreMode()
        showMode()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyHeight()
        engine?.clear()
        refreshBar()
    }

    override func viewWillDisappear(_ animated: Bool) {
        // 鍵盤收起時，組到一半的注音就送出第一個候選，不要讓打的字消失
        commitFirstCandidateIfComposing()
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
        keyboardView.shift = .off
        refreshBar()
    }

    // MARK: - 鍵 → 引擎 → 輸入框

    private func handle(_ spec: KeySpec) {
        switch spec.action {
        case let .bopomofo(symbol):
            _ = engine?.feedSymbol(symbol)

        case let .letter(c):
            let out = keyboardView.shift == .off ? c : c.uppercased()
            textDocumentProxy.insertText(out)
            if keyboardView.shift == .once {
                keyboardView.shift = .off
            }

        case let .text(s):
            commitFirstCandidateIfComposing()
            textDocumentProxy.insertText(s)

        case .space:
            if let engine, !engine.candidates.isEmpty {
                select(0)
            } else if let engine, !engine.composing.isEmpty {
                engine.clear() // 殘留的接不上字的注音，丟掉
            } else {
                textDocumentProxy.insertText(" ")
            }

        case .newline:
            commitFirstCandidateIfComposing()
            textDocumentProxy.insertText("\n")

        case .backspace:
            if engine?.backspace() != true {
                textDocumentProxy.deleteBackward()
            }

        case .shift:
            keyboardView.shift = keyboardView.shift == .off ? .once : .off

        case .toggleLanguage:
            commitFirstCandidateIfComposing()
            setMode(language == .bopomofo ? .english : .bopomofo)

        case let .switchMode(m):
            commitFirstCandidateIfComposing()
            setMode(m)

        case .backToLanguage:
            setMode(language)
        }
        refreshBar()
    }

    private func handleLongPress(_ spec: KeySpec) {
        guard let alt = spec.altText else { return }
        commitFirstCandidateIfComposing()
        textDocumentProxy.insertText(alt)
        refreshBar()
    }

    private func commitFirstCandidateIfComposing() {
        guard let engine, !engine.candidates.isEmpty else { return }
        let text = engine.selectCandidate(at: 0)
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
        // 選完第一個後若還有剩（多音節只吃掉一部分），繼續送到清空
        while !engine.candidates.isEmpty {
            let more = engine.selectCandidate(at: 0)
            if more.isEmpty {
                break
            }
            textDocumentProxy.insertText(more)
        }
        engine.clear()
    }

    private func select(_ index: Int) {
        guard let engine else { return }
        let text = engine.selectCandidate(at: UInt(index))
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
        refreshBar()
    }

    private func refreshBar() {
        candidateBar.update(composing: engine?.composing ?? "", candidates: engine?.candidates ?? [])
    }
}
