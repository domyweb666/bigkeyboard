import UIKit

/// 工具列那排：左側顯示正在組的注音，右側橫向列出候選字。片 4 版。
final class CandidateBar: UIView {
    var onSelect: ((Int) -> Void)?

    private let composingLabel = UILabel()
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        composingLabel.font = .systemFont(ofSize: 18)
        composingLabel.textColor = .darkGray
        composingLabel.setContentHuggingPriority(.required, for: .horizontal)
        composingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)

        stack.axis = .horizontal
        stack.spacing = 4
        stack.alignment = .fill
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(stack)

        for v in [composingLabel, scroll] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            composingLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            composingLabel.centerYAnchor.constraint(equalTo: centerYAnchor),

            scroll.leadingAnchor.constraint(equalTo: composingLabel.trailingAnchor, constant: 12),
            scroll.trailingAnchor.constraint(equalTo: trailingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    func update(composing: String, candidates: [String]) {
        composingLabel.text = composing
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, c) in candidates.enumerated() {
            let b = UIButton(type: .system)
            b.setTitle(c, for: .normal)
            b.titleLabel?.font = .systemFont(ofSize: 24)
            b.setTitleColor(SamsungTheme.keyText, for: .normal)
            b.contentEdgeInsets = UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10)
            b.tag = i
            b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
            stack.addArrangedSubview(b)
        }
        scroll.setContentOffset(.zero, animated: false)
    }

    @objc private func tapped(_ sender: UIButton) {
        onSelect?(sender.tag)
    }
}
