import UIKit

/// 剪貼簿的一張卡片：文字最多 4 行（長的只顯示開頭，貼上照樣貼整段），下面一行標籤，固定的右上角有圖釘。
/// 整張是一顆鍵（KeyButton）：點了貼上、按住跳選單；在可捲動的清單裡，開始捲就不算點
final class ClipboardCard: UICollectionViewCell {
    static let font = UIFont.systemFont(ofSize: 15)
    static let tagFont = UIFont.systemFont(ofSize: 12, weight: .semibold)
    static let maxLines: CGFloat = 4
    static let padX: CGFloat = 10
    static let padY: CGFloat = 9
    /// 圖釘佔掉的右邊寬度
    static let pinWidth: CGFloat = 16
    static let tagGap: CGFloat = 4

    var onTap: (() -> Void)?
    var onLongPress: (() -> Void)?

    private let button = KeyButton()
    private let textLabel = UILabel()
    private let tagLabel = UILabel()
    private let pinView = UIImageView()
    private var textTrailing: NSLayoutConstraint?

    override init(frame: CGRect) {
        super.init(frame: frame)
        button.tapsWhenCancelled = false
        button.onTap = { [weak self] in self?.onTap?() }
        button.onLongPress = { [weak self] in self?.onLongPress?() }
        textLabel.font = Self.font
        textLabel.numberOfLines = Int(Self.maxLines)
        textLabel.lineBreakMode = .byTruncatingTail
        tagLabel.font = Self.tagFont
        pinView.image = UIImage(
            systemName: "pin.fill",
            withConfiguration: UIImage.SymbolConfiguration(pointSize: 11)
        )
        pinView.contentMode = .scaleAspectFit
        for v in [button, textLabel, tagLabel, pinView] as [UIView] {
            v.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(v)
        }
        // 字和圖示疊在鍵上，觸控交給下面那顆鍵
        for v in [textLabel, tagLabel, pinView] as [UIView] {
            v.isUserInteractionEnabled = false
        }
        let trailing = textLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.padX)
        textTrailing = trailing
        NSLayoutConstraint.activate([
            button.topAnchor.constraint(equalTo: contentView.topAnchor),
            button.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
            button.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            button.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),

            textLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: Self.padY),
            textLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.padX),
            trailing,

            tagLabel.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -Self.padY),
            tagLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: Self.padX),
            tagLabel.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -Self.padX),

            pinView.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
            pinView.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -7),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    func show(_ entry: ClipboardHistory.Entry) {
        button.normalColor = SamsungTheme.keyWhite
        button.layer.cornerRadius = SamsungTheme.keyCornerRadius
        textLabel.textColor = SamsungTheme.keyText
        tagLabel.textColor = SamsungTheme.accentStrong
        pinView.tintColor = SamsungTheme.accent
        textLabel.text = Self.preview(entry.text)
        tagLabel.text = Self.tagLine(entry.tags)
        pinView.isHidden = !entry.pinned
        textTrailing?.constant = -Self.padX - (entry.pinned ? Self.pinWidth : 0)
        accessibilityLabel = entry.text
    }

    /// 換行換成空白，4 行裡看得到比較多字
    static func preview(_ text: String) -> String {
        text.replacingOccurrences(of: "\n", with: " ")
    }

    static func tagLine(_ tags: [String]) -> String? {
        tags.isEmpty ? nil : tags.map { "＃" + $0 }.joined(separator: " ")
    }

    /// 這筆在這個寬度下要多高（兩欄排版算位置用）
    static func height(for entry: ClipboardHistory.Entry, width: CGFloat) -> CGFloat {
        let textWidth = width - padX * 2 - (entry.pinned ? pinWidth : 0)
        let measured = (preview(entry.text) as NSString).boundingRect(
            with: CGSize(width: max(textWidth, 1), height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin],
            attributes: [.font: font],
            context: nil
        ).height
        let text = min(ceil(measured), ceil(font.lineHeight * maxLines))
        let tags = entry.tags.isEmpty ? 0 : ceil(tagFont.lineHeight) + tagGap
        return text + tags + padY * 2
    }
}

/// 兩欄卡片排法（像 Google Keep）：每張依序放進目前比較矮的那一欄
final class MasonryLayout: UICollectionViewLayout {
    static let inset: CGFloat = 4

    /// 第 i 張在這個欄寬下多高（外面依資料算）
    var heightForItem: ((Int, CGFloat) -> CGFloat)?

    private var frames: [UICollectionViewLayoutAttributes] = []
    private var contentHeight: CGFloat = 0

    override func prepare() {
        super.prepare()
        frames = []
        guard let cv = collectionView, cv.numberOfSections > 0 else { return }
        let gap = SamsungTheme.keyGap
        let columnWidth = (cv.bounds.width - Self.inset * 2 - gap) / 2
        var bottoms: [CGFloat] = [Self.inset, Self.inset]
        for i in 0 ..< cv.numberOfItems(inSection: 0) {
            let column = bottoms[0] <= bottoms[1] ? 0 : 1
            let h = heightForItem?(i, columnWidth) ?? 60
            let a = UICollectionViewLayoutAttributes(forCellWith: IndexPath(item: i, section: 0))
            a.frame = CGRect(
                x: Self.inset + CGFloat(column) * (columnWidth + gap),
                y: bottoms[column],
                width: columnWidth,
                height: h
            )
            frames.append(a)
            bottoms[column] += h + gap
        }
        contentHeight = max(bottoms[0], bottoms[1]) - gap + Self.inset
    }

    override var collectionViewContentSize: CGSize {
        CGSize(width: collectionView?.bounds.width ?? 0, height: contentHeight)
    }

    override func layoutAttributesForElements(in rect: CGRect) -> [UICollectionViewLayoutAttributes]? {
        frames.filter { $0.frame.intersects(rect) }
    }

    override func layoutAttributesForItem(at indexPath: IndexPath) -> UICollectionViewLayoutAttributes? {
        indexPath.item < frames.count ? frames[indexPath.item] : nil
    }

    override func shouldInvalidateLayout(forBoundsChange newBounds: CGRect) -> Bool {
        newBounds.width != collectionView?.bounds.width
    }
}
