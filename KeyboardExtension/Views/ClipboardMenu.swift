import UIKit

/// 長按剪貼簿卡片跳出的選單：固定、標籤（從 App 裡建好的選，可複選）、刪除。
/// 蓋在剪貼簿面板上，點選單外面就關。鍵盤裡沒辦法打字編輯，改字和建標籤寫一行提示指去豆鍵 App
final class ClipboardMenu: UIView {
    var onTogglePin: (() -> Void)?
    var onToggleTag: ((String) -> Void)?
    var onDelete: (() -> Void)?
    var onClose: (() -> Void)?

    private static let rowHeight: CGFloat = 40
    private let card = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 半透明的遮罩：看得出選單外面按了會關，也讓觸控送得進來
        backgroundColor = UIColor.black.withAlphaComponent(0.2)
        stack.axis = .vertical
        scroll.addSubview(stack)
        card.addSubview(scroll)
        addSubview(card)
        for v in [card, scroll, stack] {
            v.translatesAutoresizingMaskIntoConstraints = false
        }
        let fit = card.heightAnchor.constraint(equalTo: stack.heightAnchor)
        fit.priority = .defaultLow
        NSLayoutConstraint.activate([
            card.centerXAnchor.constraint(equalTo: centerXAnchor),
            card.centerYAnchor.constraint(equalTo: centerYAnchor),
            card.widthAnchor.constraint(equalToConstant: 240),
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

    /// 照這一筆目前的狀態排選單（換了標籤後重排一次，打勾跟著變）
    func show(_ entry: ClipboardHistory.Entry, allTags: [String]) {
        card.backgroundColor = SamsungTheme.keyWhite
        card.layer.cornerRadius = SamsungTheme.keyCornerRadius + 4
        card.clipsToBounds = true
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        addRow(entry.pinned ? "取消固定" : "固定", icon: entry.pinned ? "pin.slash" : "pin") { [weak self] in
            self?.onTogglePin?()
        }
        if allTags.isEmpty {
            addNote("要加標籤，先在豆鍵 App 的「剪貼簿」分頁建立標籤")
        }
        for tag in allTags {
            let on = entry.tags.contains(tag)
            addRow("＃" + tag, icon: on ? "checkmark.circle.fill" : "circle") { [weak self] in
                self?.onToggleTag?(tag)
            }
        }
        addRow("刪除", icon: "trash", color: .systemRed) { [weak self] in
            self?.onDelete?()
        }
        addNote("要改文字：打開豆鍵 App →「剪貼簿」")
        addRow("取消", icon: nil) { [weak self] in
            self?.onClose?()
        }
        scroll.setContentOffset(.zero, animated: false)
    }

    private func addRow(_ title: String, icon: String?, color: UIColor? = nil, action: @escaping () -> Void) {
        let b = KeyButton()
        b.normalColor = .clear
        b.layer.shadowOpacity = 0
        b.layer.cornerRadius = 0
        b.tapsWhenCancelled = false
        b.onTap = action
        b.label.text = title
        b.label.font = .systemFont(ofSize: 16)
        b.label.textColor = color ?? SamsungTheme.keyText
        b.accessibilityLabel = title
        if let icon {
            let image = UIImageView(image: UIImage(systemName: icon))
            image.tintColor = color ?? SamsungTheme.keyText
            image.isUserInteractionEnabled = false
            image.translatesAutoresizingMaskIntoConstraints = false
            b.addSubview(image)
            NSLayoutConstraint.activate([
                image.leadingAnchor.constraint(equalTo: b.leadingAnchor, constant: 16),
                image.centerYAnchor.constraint(equalTo: b.centerYAnchor),
            ])
        }
        b.heightAnchor.constraint(equalToConstant: Self.rowHeight).isActive = true
        stack.addArrangedSubview(b)
    }

    /// 一行灰色小字（不能按）
    private func addNote(_ text: String) {
        let label = UILabel()
        label.text = text
        label.font = .systemFont(ofSize: 13)
        label.textColor = SamsungTheme.hintText
        label.numberOfLines = 0
        label.textAlignment = .center
        let wrap = UIView()
        label.translatesAutoresizingMaskIntoConstraints = false
        wrap.addSubview(label)
        NSLayoutConstraint.activate([
            label.topAnchor.constraint(equalTo: wrap.topAnchor, constant: 8),
            label.bottomAnchor.constraint(equalTo: wrap.bottomAnchor, constant: -8),
            label.leadingAnchor.constraint(equalTo: wrap.leadingAnchor, constant: 14),
            label.trailingAnchor.constraint(equalTo: wrap.trailingAnchor, constant: -14),
        ])
        stack.addArrangedSubview(wrap)
    }
}
