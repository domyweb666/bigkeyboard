import UIKit

/// 展開後的全部候選：蓋在鍵盤區上面，一格一格排，可上下捲。
/// 為了「候選字選不到想要的字」這個最怕的事：橫向一列滑不完的時候，展開一次看完。
final class CandidateGrid: UIView, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    var onSelect: ((Int) -> Void)?
    /// 長按第 i 格（跳出「忘掉這個詞」的選單）
    var onLongPress: ((Int) -> Void)?

    private var items: [String] = []
    /// 修正出來的候選（第幾格），字換一個色
    private var corrected: Set<Int> = []
    /// 每格的大小：展開時一次算好。以前讓每格自己量（automaticSize），候選上百個時第一次排版要量上百次，
    /// 按了展開要等一下才出來（2026-11-02 多米回報）。量字寬很快，直接給大小
    private var sizes: [CGSize] = []
    private static var font: UIFont {
        SamsungTheme.keyFont(ofSize: SamsungTheme.candidateFontSize)
    }

    private static let padX: CGFloat = 12
    private static let padY: CGFloat = 8
    private static let minWidth: CGFloat = 48
    private let collection: UICollectionView

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.minimumInteritemSpacing = SamsungTheme.keyGap
        layout.minimumLineSpacing = SamsungTheme.keyGap
        layout.sectionInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        // 格子之間的縫也要接得到觸控（上下捲），全透明的話系統不送進來
        backgroundColor = SamsungTheme.keyAreaBackground
        collection.backgroundColor = .clear
        collection.register(Cell.self, forCellWithReuseIdentifier: "c")
        collection.dataSource = self
        collection.delegate = self
        collection.translatesAutoresizingMaskIntoConstraints = false
        // 長按跟候選列一樣 0.4 秒；長按成立時系統會取消這次點選，不會順便選字
        let hold = UILongPressGestureRecognizer(target: self, action: #selector(held(_:)))
        hold.minimumPressDuration = SamsungTheme.longPressSeconds
        collection.addGestureRecognizer(hold)
        addSubview(collection)
        NSLayoutConstraint.activate([
            collection.topAnchor.constraint(equalTo: topAnchor),
            collection.bottomAnchor.constraint(equalTo: bottomAnchor),
            collection.leadingAnchor.constraint(equalTo: leadingAnchor),
            collection.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    func update(_ candidates: [String], corrected marked: Set<Int>) {
        items = candidates
        corrected = marked
        let h = ceil(Self.font.lineHeight) + Self.padY * 2
        sizes = candidates.map { text in
            let w = ceil((text as NSString).size(withAttributes: [.font: Self.font]).width) + Self.padX * 2
            return CGSize(width: max(Self.minWidth, w), height: h)
        }
        collection.reloadData()
        collection.setContentOffset(.zero, animated: false)
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        items.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath)
        if let cell = cell as? Cell {
            cell.applyTheme()
            cell.label.text = items[indexPath.item]
            if corrected.contains(indexPath.item) {
                cell.label.textColor = SamsungTheme.correctedCandidate
            }
        }
        return cell
    }

    func collectionView(
        _: UICollectionView,
        layout _: UICollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> CGSize {
        indexPath.item < sizes.count ? sizes[indexPath.item] : CGSize(width: Self.minWidth, height: Self.minWidth)
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(indexPath.item)
    }

    @objc private func held(_ g: UILongPressGestureRecognizer) {
        guard g.state == .began, let path = collection.indexPathForItem(at: g.location(in: collection)) else { return }
        onLongPress?(path.item)
    }

    private final class Cell: UICollectionViewCell {
        let label = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            applyTheme()
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
            // 格子大小由外面算好給（sizeForItemAt），字置中就好
            NSLayoutConstraint.activate([
                label.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
                label.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("not used")
        }

        /// 照目前主題上色、換字（格子會重複使用，換主題後每次拿出來都重設）
        func applyTheme() {
            contentView.backgroundColor = SamsungTheme.keyWhite
            contentView.layer.cornerRadius = SamsungTheme.keyCornerRadius
            label.font = CandidateGrid.font
            label.textColor = SamsungTheme.keyText
        }

        override var isHighlighted: Bool {
            didSet {
                contentView.backgroundColor = isHighlighted ? SamsungTheme.keyPressed : SamsungTheme.keyWhite
            }
        }
    }
}
