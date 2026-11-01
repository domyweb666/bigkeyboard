import UIKit

/// 鍵盤殼：iOS 叫起鍵盤時的入口。管模式切換、把鍵的動作轉成引擎呼叫或送字，記住上次的模式。
final class KeyboardViewController: UIInputViewController {
    let candidateBar = CandidateBar()
    let keyboardView = KeyboardView()
    let candidateGrid = CandidateGrid()
    private var heightConstraint: NSLayoutConstraint?
    private var barShown: NSLayoutConstraint?
    private var barHidden: NSLayoutConstraint?
    var engine: BopomofoEngine?

    private static let modeKey = "lastMode"
    private static let languageKey = "lastLanguage"

    /// 打字前、還沒有上下文時，工具列先擺常用的起頭字，不留一條空白
    static let starters = ["我", "你", "好", "這", "那", "是", "在", "有", "不", "要", "如果", "但是", "因為", "所以"]

    /// 目前鍵面
    var mode: KeyboardMode = .bopomofo
    /// 符號頁／數字鍵盤要回去的語言鍵面
    var language: KeyboardMode = .bopomofo

    /// 輸入框裡目前有沒有我們放的「組字中」底線文字
    var hasMarkedText = false
    /// 只選了前半段時已選好的字：先留在底線裡，整段選完才一起送出（跟系統注音一樣）。
    /// 選一段就送一段的話，「送出→馬上再標底線」在有些 App 會蓋掉剛送的字
    var pendingText = ""
    /// 剛送出字之後的聯想詞
    var associations: [String] = []
    /// 工具列展開成全部候選
    var expanded = false
    var lastShiftTap = Date.distantPast
    /// 這段組字選過的字（判斷要不要自動加詞）
    var learning = LearningSession()

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
        setUpDismissHandle()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyHeight()
        engine?.clear()
        learning = LearningSession()
        loadUserDictionary()
        hasMarkedText = false
        pendingText = ""
        associations = []
        expanded = false
        updateAutoCapitalization()
        applyHostTraits()
        refreshBar()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // 系統在螢幕左右邊緣做手勢判斷，會把觸控延後送來：最左、最右那欄鍵慢半拍，快打時像沒按到。關掉延後
        for recognizer in view.window?.gestureRecognizers ?? [] {
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
        }
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // 換到另一個輸入框時：深淺色、換行鍵文字跟著它
        applyHostTraits()
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
        keyboardView.setReturnLabel(Self.returnLabel(for: textDocumentProxy.returnKeyType))
        refreshBar()
    }

    // MARK: - 鍵 → 引擎 → 輸入框

    private func handle(_ spec: KeySpec) {
        switch spec.action {
        case let .bopomofo(symbol):
            associations = []
            _ = engine?.feedSymbol(symbol)
            learning.noteTyped()
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
            handleSpace()

        case .newline:
            commitAllComposing()
            textDocumentProxy.insertText("\n")
            associations = []

        case .backspace:
            if engine?.backspace() == true {
                learning.noteTyped()
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

        case .spacer:
            break
        }
        if mode == .english {
            updateAutoCapitalization()
        }
        refreshBar()
    }

    private func handleSpace() {
        if let engine, !engine.candidates.isEmpty {
            selectCandidate(0)
        } else if let engine, !engine.composing.isEmpty {
            engine.clear() // 殘留、接不上字的注音，丟掉
            learning = LearningSession()
            syncMarkedText()
        } else {
            textDocumentProxy.insertText(" ")
            associations = []
        }
    }

    private func handleLongPress(_ spec: KeySpec) {
        guard let longAction = spec.longAction else { return }
        handle(KeySpec(spec.label, longAction))
    }
}
