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

    /// 量過的字寬，同一個字型才算數。簡拼時候選常有上千個，每次都量，按展開要等一下（2026-11-26 性能審查）
    private var widths: [String: CGFloat] = [:]
    private var widthFont: UIFont?
    /// 這個字型一個漢字的寬；抽樣量過漢字都一樣寬才有值，整串都是漢字的候選就不用量
    private var hanWidth: CGFloat?
    /// 收起來過：下次展開照舊重排、回到最上面
    private var stale = true

    override var isHidden: Bool {
        didSet {
            if isHidden {
                stale = true
            }
        }
    }

    func update(_ candidates: [String], corrected marked: Set<Int>) {
        let font = Self.font
        // 選一個字時候選列會刷新好幾次；內容沒變就不重排，也不會把捲到一半的跳回最上面
        if !stale, candidates == items, marked == corrected, font == widthFont {
            return
        }
        stale = false
        items = candidates
        corrected = marked
        if font != widthFont || widths.count > 5000 {
            widthFont = font
            widths = [:]
            hanWidth = Self.uniformHanWidth(font)
        }
        let h = ceil(font.lineHeight) + Self.padY * 2
        sizes = candidates.map { text in
            CGSize(width: max(Self.minWidth, width(of: text, font: font) + Self.padX * 2), height: h)
        }
        collection.reloadData()
        collection.setContentOffset(.zero, animated: false)
    }

    private func width(of text: String, font: UIFont) -> CGFloat {
        if let hanWidth, text.unicodeScalars.allSatisfy({ (0x4E00 ... 0x9FFF).contains($0.value) }) {
            return ceil(hanWidth * CGFloat(text.unicodeScalars.count))
        }
        if let w = widths[text] {
            return w
        }
        let w = ceil((text as NSString).size(withAttributes: [.font: font]).width)
        widths[text] = w
        return w
    }

    /// 字型的漢字一不一樣寬：抽幾個常用、罕用的字量，連著排也剛好是倍數，才回傳一個字的寬
    private static func uniformHanWidth(_ font: UIFont) -> CGFloat? {
        func measure(_ text: String) -> CGFloat {
            (text as NSString).size(withAttributes: [.font: font]).width
        }
        let one = measure("一")
        let same = ["鬱", "國", "的", "龘"].allSatisfy { abs(measure($0) - one) < 0.01 }
        return same && abs(measure("一鬱國") - one * 3) < 0.01 ? one : nil
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
