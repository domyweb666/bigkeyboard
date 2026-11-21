import UIKit

/// 長按候選字跳出的選單（2026-11-21 多米選 A：跟剪貼簿長按的選單同一套長相）。蓋在鍵區上，點選單外面就關。
/// 有學過：說明它為什麼排前面，兩顆按鈕「忘掉這個詞」「取消」。
/// 沒學過、或學過但寫不進字典（沒開完全取用）：只說明，一顆「好」
final class CandidateMenu: UIView {
    var onForget: (() -> Void)?
    var onClose: (() -> Void)?

    private let card = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 半透明的遮罩：看得出選單外面按了會關，也讓觸控送得進來
        backgroundColor = UIColor.black.withAlphaComponent(0.2)
        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        scroll.addSubview(stack)
        card.addSubview(scroll)
        addSubview(card)
        for v in [card, scroll, stack] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        // 橫放時鍵區很矮，放不下就在卡片裡上下捲
        let fit = card.heightAnchor.constraint(equalTo: stack.heightAnchor)
        fit.priority = .defaultLow
        NSLayoutConstraint.activate([
            card.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 12),
            card.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -12),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.heightAnchor.constraint(lessThanOrEqualTo: heightAnchor, constant: -16),
            fit,

            scroll.topAnchor.constraint(equalTo: card.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: card.bottomAnchor),
            scroll.leadingAnchor.constraint(equalTo: card.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: card.trailingAnchor),

            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            stack.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    /// 點在選單外面：關掉
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        guard let point = touches.first?.location(in: self), !card.frame.contains(point) else { return }
        onClose?()
    }

    /// reason 是它為什麼排前面（nil 表示沒學過）；reading 是字典裡存的讀音（沒有就不顯示）；
    /// canForget 是鍵盤寫得進字典（有開完全取用）
    func show(_ text: String, reading: String?, reason: String?, canForget: Bool) {
        card.backgroundColor = SamsungTheme.keyWhite
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(makeTitle(text, reading: reading))
        scroll.setContentOffset(.zero, animated: false)
        guard let reason else {
            stack.addArrangedSubview(ClipboardMenu.makeNote("這是詞庫原本的順序，沒有學過，不用刪", size: 14))
            stack.addArrangedSubview(makeClose("好"))
            return
        }
        stack.addArrangedSubview(ClipboardMenu.makeNote(reason + "，所以排前面", size: 14))
        guard canForget else {
            let how = "要在鍵盤上忘掉它，先打開「允許完全取用」（設定 → 一般 → 鍵盤 → 鍵盤 → 豆鍵）；或打開豆鍵 App →「字典」刪"
            stack.addArrangedSubview(ClipboardMenu.makeNote(how, size: 13))
            stack.addArrangedSubview(makeClose("好"))
            return
        }
        let forget = ClipboardMenu.makeButton(
            "忘掉這個詞",
            icon: "trash",
            background: SamsungTheme.destructiveSoft,
            color: SamsungTheme.destructive
        ) { [weak self] in
            self?.onForget?()
        }
        let row = UIStackView(arrangedSubviews: [forget, makeClose("取消")])
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        stack.addArrangedSubview(row)
        stack.addArrangedSubview(ClipboardMenu.makeNote("詞庫原本就有的詞不會消失，只會回到原本的順序", size: 12))
    }

    /// 最上面一行：這個詞，後面跟著灰色小字的讀音
    private func makeTitle(_ text: String, reading: String?) -> UILabel {
        let title = NSMutableAttributedString(string: text, attributes: [
            .font: UIFont.systemFont(ofSize: 22, weight: .semibold),
            .foregroundColor: SamsungTheme.keyText,
        ])
        if let reading {
            title.append(NSAttributedString(string: "  " + reading, attributes: [
                .font: UIFont.systemFont(ofSize: 14),
                .foregroundColor: SamsungTheme.hintText,
            ]))
        }
        let label = UILabel()
        label.attributedText = title
        label.numberOfLines = 0
        return label
    }

    private func makeClose(_ title: String) -> KeyButton {
        ClipboardMenu.makeButton(
            title,
            icon: nil,
            background: SamsungTheme.keyTone,
            color: SamsungTheme.keyText
        ) { [weak self] in
            self?.onClose?()
        }
    }
}
