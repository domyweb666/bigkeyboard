import UIKit

/// 鍵面切換：記住上次的鍵面、換鍵面、照輸入框種類換鍵面。
extension KeyboardViewController {
    func restoreMode() {
        let d = UserDefaults.standard
        language = .bopomofo
        if let raw = d.string(forKey: Self.languageKey), let m = KeyboardMode(rawValue: raw), m.isLanguage {
            language = m
        }
        if let raw = d.string(forKey: Self.modeKey), let m = KeyboardMode(rawValue: raw) {
            mode = m
        } else {
            mode = language
        }
    }

    func setMode(_ newMode: KeyboardMode) {
        if newMode.isLanguage {
            language = newMode
        }
        mode = newMode
        if !hostOverridesMode {
            let d = UserDefaults.standard
            d.set(mode.rawValue, forKey: Self.modeKey)
            d.set(language.rawValue, forKey: Self.languageKey)
        }
        showMode()
    }

    /// 輸入框種類換了：email、網址、只收英文的欄位換英文鍵面（email、網址的底排多 @ 或 / .com），數字加標點的欄位換數字鍵盤；其他回到平常記住的鍵面
    func applyHostKeyboardType() {
        let type = textDocumentProxy.keyboardType ?? .default
        guard type != hostKeyboardType else { return }
        hostKeyboardType = type
        commitAllComposing()
        associations = []
        let plan = Self.hostPlan(for: type)
        hostField = plan.field
        hostOverridesMode = plan.mode != nil
        if let forced = plan.mode {
            mode = forced
            if forced.isLanguage {
                language = forced
            }
        } else {
            restoreMode()
        }
        showMode()
    }

    func showMode() {
        let chinese = language == .bopomofo
        switch mode {
        case .bopomofo:
            keyboardView.load(BopomofoLayout.rows)
        case .english:
            keyboardView.load(EnglishLayout.rows(for: hostField))
        case .symbols1:
            keyboardView.load(SymbolLayout.page1(chinese: chinese))
        case .symbols2:
            keyboardView.load(SymbolLayout.page2(chinese: chinese))
        case .numpad:
            keyboardView.load(NumpadLayout.rows(chinese: chinese))
        }
        // 工具列只在注音鍵面出現（候選字）；英文、符號頁、數字鍵盤總高度不變，空間讓給鍵（鍵變高、更好按）
        let showBar = mode == .bopomofo
        barShown?.isActive = false
        barHidden?.isActive = false
        (showBar ? barShown : barHidden)?.isActive = true
        candidateBar.isHidden = !showBar
        expanded = false
        clipboardOpen = false
        if mode == .english {
            preloadEnglishWords()
        }
        keyboardView.shift = .off
        keyboardView.setReturnLabel(Self.returnLabel(for: textDocumentProxy.returnKeyType))
        refreshBar()
    }
}
