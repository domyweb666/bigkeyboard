import UIKit

/// 鍵盤殼。片 4：四顆鍵（ㄋ ㄧ ˇ 空白）＋候選字列，接小麥引擎。
final class KeyboardViewController: UIInputViewController {
    private let candidateBar = CandidateBar()
    private let keyArea = UIView()
    private var heightConstraint: NSLayoutConstraint?
    private var engine: BopomofoEngine?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SamsungTheme.background

        if let path = Bundle.main.path(forResource: "mcbopomofo-data", ofType: "txt") {
            engine = BopomofoEngine(dataPath: path)
        }

        candidateBar.onSelect = { [weak self] i in self?.select(i) }

        for v in [candidateBar, keyArea] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        let keys: [(String, CGFloat)] = [("ㄋ", 1), ("ㄧ", 1), ("ˇ", 1), (" ", 3)]
        let row = UIStackView()
        row.axis = .horizontal
        row.spacing = 6
        row.distribution = .fillProportionally
        row.translatesAutoresizingMaskIntoConstraints = false
        keyArea.addSubview(row)
        for (title, weight) in keys {
            let b = UIButton(type: .system)
            b.setTitle(title == " " ? "" : title, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 28)
            b.setTitleColor(SamsungTheme.keyText, for: .normal)
            b.backgroundColor = SamsungTheme.keyWhite
            b.layer.cornerRadius = 8
            b.accessibilityLabel = title == " " ? "空白" : title
            b.addAction(UIAction { [weak self] _ in self?.keyTapped(title) }, for: .touchUpInside)
            row.addArrangedSubview(b)
            b.widthAnchor.constraint(equalTo: row.widthAnchor, multiplier: weight / 6.6).isActive = true
        }

        NSLayoutConstraint.activate([
            candidateBar.topAnchor.constraint(equalTo: view.topAnchor),
            candidateBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            candidateBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            candidateBar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: SamsungTheme.toolbarHeightRatio),

            keyArea.topAnchor.constraint(equalTo: candidateBar.bottomAnchor),
            keyArea.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyArea.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyArea.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            row.centerYAnchor.constraint(equalTo: keyArea.centerYAnchor),
            row.leadingAnchor.constraint(equalTo: keyArea.leadingAnchor, constant: 8),
            row.trailingAnchor.constraint(equalTo: keyArea.trailingAnchor, constant: -8),
            row.heightAnchor.constraint(equalToConstant: 60),
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

    private func keyTapped(_ title: String) {
        guard let engine else { return }
        if title == " " {
            if engine.candidates.isEmpty {
                textDocumentProxy.insertText(" ")
            } else {
                select(0)
            }
            return
        }
        _ = engine.feedSymbol(title)
        refreshBar()
    }

    private func select(_ index: Int) {
        guard let engine else { return }
        let text = engine.selectCandidate(at: UInt(index))
        if !text.isEmpty { textDocumentProxy.insertText(text) }
        refreshBar()
    }

    private func refreshBar() {
        candidateBar.update(composing: engine?.composing ?? "", candidates: engine?.candidates ?? [])
    }
}
