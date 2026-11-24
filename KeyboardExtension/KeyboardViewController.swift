import UIKit

/// 鍵盤殼：iOS 叫起鍵盤時的入口。管模式切換、把鍵的動作轉成引擎呼叫或送字，記住上次的模式。
final class KeyboardViewController: UIInputViewController {
    let candidateBar = CandidateBar()
    let keyboardView = KeyboardView()
    let candidateGrid = CandidateGrid()
    let clipboardPanel = ClipboardPanel()
    /// 長按候選字跳出的選單
    let candidateMenu = CandidateMenu()
    private var heightConstraint: NSLayoutConstraint?
    var barShown: NSLayoutConstraint?
    var barHidden: NSLayoutConstraint?
    var engine: BopomofoEngine?

    static let modeKey = "lastMode"
    static let languageKey = "lastLanguage"

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
    /// 開始組字時游標前面的最後兩個字（查「這後面通常接什麼」用）
    var composeContext = ""
    /// 接續紀錄：前面 1～2 個字 → 用豆鍵在它後面打過的字詞 → 次數。鍵盤出現時從字典檔讀進來
    var follows: [String: [String: Int]] = [:]
    /// 使用者字典的詞（自動學到的、手動加的）。長按候選字時查它有沒有學過
    var userWords: [UserDictionary.Word] = []
    /// 還沒寫進字典檔的接續紀錄（停手 3 秒或收鍵盤時一起寫）
    var pendingFollows: [(context: String, text: String)] = []
    var followFlushTimer: Timer?
    /// 剪貼簿面板開著
    var clipboardOpen = false
    /// 用豆鍵打過的英文字 → 次數（英文預測字排序用）。鍵盤出現時從字典檔讀進來
    var englishCounts: [String: Int] = [:]
    /// 還沒寫進字典檔的英文字（跟接續紀錄一起寫）
    var pendingEnglish: [String] = []
    /// 剛點了英文建議、自動補了空格（接著打標點時拿掉那個空格）
    var englishAutoSpace = false
    /// 目前輸入框的種類（email、網址、數字欄會換鍵面）
    var hostKeyboardType = UIKeyboardType.default
    var hostField = HostField.normal
    /// 鍵面是輸入框種類決定的：這時切鍵面不記進「上次的鍵面」，離開這個輸入框就回到平常的
    var hostOverridesMode = false
    /// App 設定：按鍵震動（要開完全取用才讀得到、才震得了）。鍵盤每次叫出來時重讀
    var keyHaptics = false
    /// App 設定：按鍵聲要哪一種（跟隨 iPhone 設定、三種按鍵聲、機械鍵盤聲音包、關閉）。鍵盤每次叫出來時重讀
    var keySound = KeySoundStyle.system
    let keySoundPlayer = KeySoundPlayer()
    let keyHaptic = UIImpactFeedbackGenerator(style: .light)
    /// 按住空白鍵拖游標中（沒在拖時是 nil）
    var cursorDrag: CursorDrag?
    /// App 設定：空白鍵一律送第一個候選（不當一聲）。鍵盤每次叫出來時重讀
    var spaceSelectsFirstCandidate = false

    /// 這一下空白鍵要不要當一聲
    var spaceSealsFirstTone: Bool {
        !spaceSelectsFirstCandidate && (engine?.canSealFirstTone ?? false)
    }

    // MARK: - 生命週期

    override func loadView() {
        OpenTiming.setUpBegan()
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

        wireCallbacks()
        candidateGrid.isHidden = true
        clipboardPanel.isHidden = true

        for v in [candidateBar, keyboardView, candidateGrid, clipboardPanel, candidateMenu] {
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
        ])
        coverKeys(with: candidateGrid)
        coverKeys(with: clipboardPanel)
        coverKeys(with: candidateMenu)

        restoreMode()
        showMode()
        setUpDismiss()
        setUpClipboard()
        setUpCandidateMenu()
        OpenTiming.setUpEnded()
    }

    /// 候選列、鍵盤的各種動作接到控制器
    private func wireCallbacks() {
        candidateBar.onSelect = { [weak self] i in
            self?.candidateFeedback()
            self?.selectFromBar(i)
        }
        candidateBar.onToggleExpand = { [weak self] in self?.toggleExpand() }
        candidateGrid.onSelect = { [weak self] i in
            self?.candidateFeedback()
            self?.selectFromBar(i)
        }
        keyboardView.onKey = { [weak self] spec in self?.handleKey(spec) }
        keyboardView.onLongKey = { [weak self] spec in self?.handleLongPress(spec) }
        keyboardView.onAnyPress = { [weak self] spec in
            self?.playKeySound(for: spec)
            self?.tapHaptic()
            self?.warmUpCursorHaptic(for: spec)
        }
        keyboardView.onAnyRelease = { [weak self] spec in self?.playKeyReleaseSound(for: spec) }
        keyboardView.peekRows = { [weak self] spec in self.flatMap { $0.peekRows(for: spec) } }
        keyboardView.onRepeatTick = { [weak self] in self?.tapHaptic() }
        keyboardView.onFastDelete = { [weak self] in self?.fastDelete() }
        keyboardView.onCursorDragBegin = { [weak self] in self?.beginCursorDrag() }
        keyboardView.onCursorDragMove = { [weak self] p in self?.moveCursorDrag(to: p) }
        keyboardView.onCursorDragEnd = { [weak self] in self?.endCursorDrag() }
    }

    /// 展開的全部候選、剪貼簿面板、長按候選字的選單：蓋在鍵區上，一樣大
    private func coverKeys(with v: UIView) {
        NSLayoutConstraint.activate([
            v.topAnchor.constraint(equalTo: keyboardView.topAnchor),
            v.leadingAnchor.constraint(equalTo: keyboardView.leadingAnchor),
            v.trailingAnchor.constraint(equalTo: keyboardView.trailingAnchor),
            v.bottomAnchor.constraint(equalTo: keyboardView.bottomAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        OpenTiming.appearBegan(enabled: hasFullAccess)
        applyHeight()
        engine?.clear()
        learning = LearningSession()
        loadUserDictionary()
        hasMarkedText = false
        pendingText = ""
        associations = []
        expanded = false
        clipboardOpen = false
        spaceSelectsFirstCandidate = hasFullAccess && SpaceKeySetting.selectsFirstCandidate
        keyHaptics = hasFullAccess && KeyHapticSetting.isOn
        keySound = hasFullAccess ? KeySoundStyle.saved : .system
        keySoundPlayer.load(pack: keySound.pack, from: .main)
        applyTheme()
        keyboardView.shift = .off
        applyHostTraits()
        applyHostKeyboardType()
        refreshBar()
        OpenTiming.prepared()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        OpenTiming.appeared(words: userWords.count, follows: follows, pack: keySound.pack)
        // 系統在螢幕左右邊緣做手勢判斷，會把觸控延後送來：最左、最右那欄鍵慢半拍，快打時像沒按到。關掉延後
        for recognizer in view.window?.gestureRecognizers ?? [] {
            recognizer.delaysTouchesBegan = false
            recognizer.delaysTouchesEnded = false
        }
        refreshContextAssociations()
    }

    override func textDidChange(_ textInput: UITextInput?) {
        super.textDidChange(textInput)
        // 換到另一個輸入框時：深淺色、換行鍵文字、鍵面跟著它
        applyHostTraits()
        applyHostKeyboardType()
        refreshContextAssociations()
        refreshEnglishIfNeeded()
    }

    override func selectionDidChange(_ textInput: UITextInput?) {
        super.selectionDidChange(textInput)
        refreshContextAssociations()
        refreshEnglishIfNeeded()
    }

    /// 英文鍵面：游標移了、輸入框的字被換了，預測字跟著游標前的字
    private func refreshEnglishIfNeeded() {
        if mode == .english {
            refreshBar()
        }
    }

    override func viewWillDisappear(_ animated: Bool) {
        // 鍵盤收起時，組到一半的注音就照第一個候選送出，不讓打的字消失
        commitAllComposing()
        flushFollows()
        // 按鍵聲的播放器不在背景空轉；下次叫出來 viewWillAppear 的 load 會再開
        keySoundPlayer.stop()
        super.viewWillDisappear(animated)
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.applyHeight() })
    }

    /// App 裡換了主題：重建鍵面，其他已經畫好的東西重新上色
    private func applyTheme() {
        let saved = KeyboardTheme.saved
        guard saved != SamsungTheme.theme else { return }
        SamsungTheme.theme = saved
        showMode()
        candidateBar.applyTheme()
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
}

// MARK: - 按鍵 → 引擎 → 輸入框

private extension KeyboardViewController {
    /// 按了一顆鍵：英文鍵面先處理自動補的空格、記下打完的字，再照鍵的動作做
    func handleKey(_ spec: KeySpec) {
        if language == .english {
            prepareEnglishKey(spec.action)
        }
        handle(spec)
    }

    func handle(_ spec: KeySpec) {
        switch spec.action {
        case let .bopomofo(symbol):
            associations = []
            startComposingIfNeeded()
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

        case .dismiss, .spacer: // 收鍵盤只從長按來（handleLongPress）
            break
        }
        refreshBar()
    }

    func handleSpace() {
        if let engine, spaceSealsFirstTone {
            engine.sealFirstTone() // 這個音沒打聲調：空白當一聲，再按一下空白才送字
            learning.noteTyped()
            syncMarkedText()
        } else if let engine, !engine.candidates.isEmpty {
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

    func handleLongPress(_ spec: KeySpec) {
        guard let longAction = spec.longAction else { return }
        if case .dismiss = longAction {
            dismissKeyboard()
            return
        }
        handle(KeySpec(spec.label, longAction))
    }
}
