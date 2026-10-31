import UIKit

/// 鍵盤殼：iOS 叫起鍵盤時的入口。片 3：高度、底色、工具列空帶。鍵仍只有「ㄅ」與地球鍵。
final class KeyboardViewController: UIInputViewController {
    private let toolbar = UIView()
    private let keyArea = UIView()
    private let nextKeyboardButton = UIButton(type: .system)
    private let bopomofoKey = UIButton(type: .system)
    private var heightConstraint: NSLayoutConstraint?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = SamsungTheme.background

        toolbar.backgroundColor = .clear
        keyArea.backgroundColor = .clear

        bopomofoKey.setTitle("ㄅ", for: .normal)
        bopomofoKey.titleLabel?.font = .systemFont(ofSize: 32)
        bopomofoKey.setTitleColor(SamsungTheme.keyText, for: .normal)
        bopomofoKey.backgroundColor = SamsungTheme.keyWhite
        bopomofoKey.layer.cornerRadius = 8
        bopomofoKey.addTarget(self, action: #selector(bopomofoTapped), for: .touchUpInside)

        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.titleLabel?.font = .systemFont(ofSize: 24)
        nextKeyboardButton.backgroundColor = SamsungTheme.keyGray
        nextKeyboardButton.layer.cornerRadius = 8
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        for v in [toolbar, keyArea] {
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }
        for b in [bopomofoKey, nextKeyboardButton] {
            b.translatesAutoresizingMaskIntoConstraints = false
            keyArea.addSubview(b)
        }

        NSLayoutConstraint.activate([
            toolbar.topAnchor.constraint(equalTo: view.topAnchor),
            toolbar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            toolbar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            toolbar.heightAnchor.constraint(equalTo: view.heightAnchor, multiplier: SamsungTheme.toolbarHeightRatio),

            keyArea.topAnchor.constraint(equalTo: toolbar.bottomAnchor),
            keyArea.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            keyArea.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            keyArea.bottomAnchor.constraint(equalTo: view.bottomAnchor),

            bopomofoKey.centerXAnchor.constraint(equalTo: keyArea.centerXAnchor),
            bopomofoKey.centerYAnchor.constraint(equalTo: keyArea.centerYAnchor),
            bopomofoKey.widthAnchor.constraint(equalToConstant: 80),
            bopomofoKey.heightAnchor.constraint(equalToConstant: 60),

            nextKeyboardButton.leadingAnchor.constraint(equalTo: keyArea.leadingAnchor, constant: 12),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: keyArea.bottomAnchor, constant: -12),
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: 60),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        applyHeight()
    }

    override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        coordinator.animate(alongsideTransition: { _ in self.applyHeight() })
    }

    override func viewWillLayoutSubviews() {
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }

    /// 高度約束：對 inputView 自己加，iOS 會照這個撐鍵盤。要在 view 進 window 後設才有效。
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

    @objc private func bopomofoTapped() {
        textDocumentProxy.insertText("ㄅ")
    }
}
