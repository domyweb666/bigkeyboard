import UIKit

/// 鍵盤殼。片 5：注音全鍵面（資料驅動）＋候選字列，接小麥引擎。
final class KeyboardViewController: UIInputViewController {
    private let candidateBar = CandidateBar()
    private let keyboardView = KeyboardView()
    private var heightConstraint: NSLayoutConstraint?
    private var engine: BopomofoEngine?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SamsungTheme.background

        if let path = Bundle.main.path(forResource: "mcbopomofo-data", ofType: "txt") {
            engine = BopomofoEngine(dataPath: path)
        }

        candidateBar.onSelect = { [weak self] i in self?.select(i) }
        keyboardView.onKey = { [weak self] spec in self?.handle(spec) }
        keyboardView.load(BopomofoLayout.rows)

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
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyHeight()
        engine?.clear()
        refreshBar()
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

    // MARK: - 鍵 → 引擎 → 輸入框

    private func handle(_ spec: KeySpec) {
        guard let engine else { return }
        switch spec.action {
        case let .bopomofo(symbol):
            _ = engine.feedSymbol(symbol)
        case let .text(s):
            commitFirstCandidateIfComposing()
            textDocumentProxy.insertText(s)
        case .space:
            if engine.candidates.isEmpty {
                textDocumentProxy.insertText(" ")
            } else {
                select(0)
            }
        case .newline:
            commitFirstCandidateIfComposing()
            textDocumentProxy.insertText("\n")
        case .backspace:
            if !engine.backspace() {
                textDocumentProxy.deleteBackward()
            }
        case .placeholder:
            break
        }
        refreshBar()
    }

    private func commitFirstCandidateIfComposing() {
        guard let engine, !engine.candidates.isEmpty else { return }
        let text = engine.selectCandidate(at: 0)
        if !text.isEmpty {
            textDocumentProxy.insertText(text)
        }
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
