import UIKit

/// 鍵盤殼：iOS 叫起鍵盤時的入口。片 2 只有一顆「ㄅ」鍵與地球鍵。
final class KeyboardViewController: UIInputViewController {
    private let nextKeyboardButton = UIButton(type: .system)
    private let bopomofoKey = UIButton(type: .system)

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = UIColor(red: 0.88, green: 0.87, blue: 0.85, alpha: 1)

        bopomofoKey.setTitle("ㄅ", for: .normal)
        bopomofoKey.titleLabel?.font = .systemFont(ofSize: 32)
        bopomofoKey.setTitleColor(.black, for: .normal)
        bopomofoKey.backgroundColor = .white
        bopomofoKey.layer.cornerRadius = 8
        bopomofoKey.addTarget(self, action: #selector(bopomofoTapped), for: .touchUpInside)

        nextKeyboardButton.setTitle("🌐", for: .normal)
        nextKeyboardButton.titleLabel?.font = .systemFont(ofSize: 24)
        nextKeyboardButton.backgroundColor = UIColor(red: 0.78, green: 0.76, blue: 0.73, alpha: 1)
        nextKeyboardButton.layer.cornerRadius = 8
        nextKeyboardButton.addTarget(self, action: #selector(handleInputModeList(from:with:)), for: .allTouchEvents)

        for button in [bopomofoKey, nextKeyboardButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(button)
        }

        NSLayoutConstraint.activate([
            bopomofoKey.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            bopomofoKey.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: -20),
            bopomofoKey.widthAnchor.constraint(equalToConstant: 80),
            bopomofoKey.heightAnchor.constraint(equalToConstant: 60),

            nextKeyboardButton.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 12),
            nextKeyboardButton.bottomAnchor.constraint(equalTo: view.bottomAnchor, constant: -12),
            nextKeyboardButton.widthAnchor.constraint(equalToConstant: 60),
            nextKeyboardButton.heightAnchor.constraint(equalToConstant: 44),
        ])
    }

    override func viewWillLayoutSubviews() {
        // Apple 規定：系統自己有切換鍵時，第三方鍵盤可以藏掉地球鍵
        nextKeyboardButton.isHidden = !needsInputModeSwitchKey
        super.viewWillLayoutSubviews()
    }

    @objc private func bopomofoTapped() {
        textDocumentProxy.insertText("ㄅ")
    }
}
