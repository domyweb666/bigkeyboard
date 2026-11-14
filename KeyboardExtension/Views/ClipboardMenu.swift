import UIKit

/// 長按剪貼簿卡片跳出的選單：最上面一行是這筆的開頭，接著兩顆大按鈕（固定、刪除）、
/// 一排標籤膠囊（從 App 裡建好的選，可複選，多了可以左右滑）、取消。
/// 蓋在剪貼簿面板上，點選單外面就關。鍵盤裡沒辦法打字編輯，改字和建標籤寫一行提示指去豆鍵 App
final class ClipboardMenu: UIView {
    var onTogglePin: (() -> Void)?
    var onToggleTag: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onClose: (() -> Void)?

    private static let buttonHeight: CGFloat = 40
    private static let tagHeight: CGFloat = 34
    private let card = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let tagScroll = UIScrollView()
    private let tagStack = UIStackView()
    /// 目前顯示的是哪一筆：同一筆重排（勾了標籤）時，標籤那排不捲回開頭
    private var shownID: UUID?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 半透明的遮罩：看得出選單外面按了會關，也讓觸控送得進來
        backgroundColor = UIColor.black.withAlphaComponent(0.2)
        stack.axis = .vertical
        stack.spacing = 10
        stack.isLayoutMarginsRelativeArrangement = true
        stack.layoutMargins = UIEdgeInsets(top: 14, left: 14, bottom: 14, right: 14)
        tagStack.axis = .horizontal
        tagStack.spacing = 6
        tagScroll.showsHorizontalScrollIndicator = false
        tagScroll.addSubview(tagStack)
        scroll.addSubview(stack)
        card.addSubview(scroll)
        addSubview(card)
        for v in [card, scroll, stack, tagScroll, tagStack] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
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

            tagScroll.heightAnchor.constraint(equalToConstant: Self.tagHeight),
            tagStack.topAnchor.constraint(equalTo: tagScroll.contentLayoutGuide.topAnchor),
            tagStack.bottomAnchor.constraint(equalTo: tagScroll.contentLayoutGuide.bottomAnchor),
            tagStack.leadingAnchor.constraint(equalTo: tagScroll.contentLayoutGuide.leadingAnchor),
            tagStack.trailingAnchor.constraint(equalTo: tagScroll.contentLayoutGuide.trailingAnchor),
            tagStack.heightAnchor.constraint(equalTo: tagScroll.frameLayoutGuide.heightAnchor),
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

    /// 照這一筆目前的狀態排選單（換了標籤後重排一次，打勾跟著變）
    func show(_ entry: ClipboardHistory.Entry, allTags: [String]) {
        let sameEntry = shownID == entry.id
        shownID = entry.id
        card.backgroundColor = SamsungTheme.keyWhite
        card.layer.cornerRadius = 16
        card.clipsToBounds = true
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        stack.addArrangedSubview(makeNote(ClipboardCard.preview(entry.text), size: 14, lines: 1))
        stack.addArrangedSubview(makeActions(pinned: entry.pinned))
        if allTags.isEmpty {
            stack.addArrangedSubview(makeNote("要加標籤，先在豆鍵 App 的「剪貼簿」分頁建立標籤", size: 13))
        } else {
            fillTags(allTags, on: entry.tags)
            stack.addArrangedSubview(tagScroll)
        }
        stack.addArrangedSubview(makeNote("要改文字：打開豆鍵 App →「剪貼簿」", size: 12))
        let cancel = makeButton(
            "取消",
            icon: nil,
            background: SamsungTheme.keyTone,
            color: SamsungTheme.keyText
        ) { [weak self] in
            self?.onClose?()
        }
        stack.addArrangedSubview(cancel)
        if !sameEntry {
            scroll.setContentOffset(.zero, animated: false)
            tagScroll.setContentOffset(.zero, animated: false)
        }
    }

    /// 兩顆並排的大按鈕：固定（或取消固定）、刪除
    private func makeActions(pinned: Bool) -> UIView {
        let pin = makeButton(
            pinned ? "取消固定" : "固定",
            icon: pinned ? "pin.slash" : "pin",
            background: SamsungTheme.keyTone,
            color: SamsungTheme.keyText
        ) { [weak self] in
            self?.onTogglePin?()
        }
        let delete = makeButton(
            "刪除",
            icon: "trash",
            background: SamsungTheme.destructiveSoft,
            color: SamsungTheme.destructive
        ) { [weak self] in
            self?.onDelete?()
        }
        let row = UIStackView(arrangedSubviews: [pin, delete])
        row.axis = .horizontal
        row.spacing = 8
        row.distribution = .fillEqually
        return row
    }

    /// 膠囊按鈕：字置中，圖示貼在字的左邊
    private func makeButton(
        _ title: String,
        icon: String?,
        background: UIColor,
        color: UIColor,
        action: @escaping () -> Void
    ) -> KeyButton {
        let b = KeyButton()
        b.normalColor = background
        b.layer.shadowOpacity = 0
        b.layer.cornerRadius = Self.buttonHeight / 2
        b.tapsWhenCancelled = false
        b.onTap = action
        b.label.text = title
        b.label.font = .systemFont(ofSize: 16, weight: .semibold)
        b.label.textColor = color
        b.isAccessibilityElement = true
        b.accessibilityLabel = title
        b.accessibilityTraits = .button
        if let icon {
            let config = UIImage.SymbolConfiguration(pointSize: 14, weight: .semibold)
            let image = UIImageView(image: UIImage(systemName: icon, withConfiguration: config))
            image.tintColor = color
            image.isUserInteractionEnabled = false
            image.translatesAutoresizingMaskIntoConstraints = false
            b.addSubview(image)
            NSLayoutConstraint.activate([
                image.trailingAnchor.constraint(equalTo: b.label.leadingAnchor, constant: -6),
                image.centerYAnchor.constraint(equalTo: b.centerYAnchor),
            ])
        }
        b.heightAnchor.constraint(equalToConstant: Self.buttonHeight).isActive = true
        return b
    }

    /// 把標籤那排換成最新的：勾了的是產品色淡底加打勾
    private func fillTags(_ allTags: [String], on: [String]) {
        tagStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for tag in allTags {
            tagStack.addArrangedSubview(makeTagChip(tag, on: on.contains(tag)))
        }
    }

    private func makeTagChip(_ tag: String, on: Bool) -> KeyButton {
        let b = KeyButton()
        b.normalColor = on ? SamsungTheme.accentSoft : SamsungTheme.keyTone
        b.layer.shadowOpacity = 0
        b.layer.cornerRadius = Self.tagHeight / 2
        // 在可左右捲的那排裡：觸控被取消代表使用者開始捲了，不算點
        b.tapsWhenCancelled = false
        b.onTap = { [weak self] in self?.onToggleTag?(tag) }
        b.label.text = (on ? "✓ " : "") + "＃" + tag
        b.label.font = .systemFont(ofSize: 14, weight: on ? .semibold : .regular)
        b.label.textColor = on ? SamsungTheme.accentStrong : SamsungTheme.keyText
        b.label.adjustsFontSizeToFitWidth = false
        b.isAccessibilityElement = true
        b.accessibilityLabel = "＃" + tag
        b.accessibilityTraits = on ? [.button, .selected] : .button
        b.widthAnchor.constraint(greaterThanOrEqualTo: b.label.widthAnchor, constant: 24).isActive = true
        return b
    }

    /// 一行灰色小字（不能按）。lines 給 0 是不限行數
    private func makeNote(_ text: String, size: CGFloat, lines: Int = 0) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: size)
        label.textColor = SamsungTheme.hintText
        label.numberOfLines = lines
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}
