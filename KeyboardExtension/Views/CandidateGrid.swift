import UIKit

/// 展開後的全部候選：蓋在鍵盤區上面，一格一格排，可上下捲。
/// 為了「候選字選不到想要的字」這個最怕的事：橫向一列滑不完的時候，展開一次看完。
final class CandidateGrid: UIView, UICollectionViewDataSource, UICollectionViewDelegate {
    var onSelect: ((Int) -> Void)?

    private var items: [String] = []
    private let collection: UICollectionView

    override init(frame: CGRect) {
        let layout = UICollectionViewFlowLayout()
        layout.estimatedItemSize = UICollectionViewFlowLayout.automaticSize
        layout.minimumInteritemSpacing = SamsungTheme.keyGap
        layout.minimumLineSpacing = SamsungTheme.keyGap
        layout.sectionInset = UIEdgeInsets(top: 6, left: 6, bottom: 6, right: 6)
        collection = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        backgroundColor = SamsungTheme.background
        collection.backgroundColor = .clear
        collection.register(Cell.self, forCellWithReuseIdentifier: "c")
        collection.dataSource = self
        collection.delegate = self
        collection.translatesAutoresizingMaskIntoConstraints = false
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

    func update(_ candidates: [String]) {
        items = candidates
        collection.reloadData()
        collection.setContentOffset(.zero, animated: false)
    }

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        items.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = cv.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath)
        (cell as? Cell)?.label.text = items[indexPath.item]
        return cell
    }

    func collectionView(_: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        onSelect?(indexPath.item)
    }

    private final class Cell: UICollectionViewCell {
        let label = UILabel()

        override init(frame: CGRect) {
            super.init(frame: frame)
            contentView.backgroundColor = SamsungTheme.keyWhite
            contentView.layer.cornerRadius = SamsungTheme.keyCornerRadius
            label.font = .systemFont(ofSize: SamsungTheme.candidateFontSize)
            label.textColor = SamsungTheme.keyText
            label.textAlignment = .center
            label.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview(label)
            NSLayoutConstraint.activate([
                label.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 8),
                label.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -8),
                label.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 12),
                label.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -12),
                contentView.widthAnchor.constraint(greaterThanOrEqualToConstant: 48),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("not used")
        }

        override var isHighlighted: Bool {
            didSet {
                contentView.backgroundColor = isHighlighted ? SamsungTheme.keyPressed : SamsungTheme.keyWhite
            }
        }
    }
}
