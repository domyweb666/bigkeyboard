import UIKit

/// 剪貼簿面板：跟展開全部候選一樣蓋在鍵區上。上面一排「返回、篩選（全部／固定／各標籤）、清空」，
/// 下面兩欄卡片（像 Google Keep）。點卡片貼上、按住跳選單（固定、標籤、刪除）。
/// 面板只管顯示與把手指的動作交出去，讀寫紀錄在 KeyboardViewController+Clipboard
final class ClipboardPanel: UIView, UICollectionViewDataSource {
    enum Content {
        case file(ClipboardHistory.File)
        /// 沒開完全取用：讀不到系統剪貼簿，也存不了
        case needsFullAccess
    }

    enum Filter: Equatable {
        case all
        case pinned
        case tag(String)
    }

    var onBack: (() -> Void)?
    var onPick: ((ClipboardHistory.Entry) -> Void)?
    var onTogglePin: ((UUID) -> Void)?
    var onToggleTag: ((String, UUID) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onClear: (() -> Void)?

    private static let headerHeight: CGFloat = 40

    private var file = ClipboardHistory.File()
    private var shown: [ClipboardHistory.Entry] = []
    private var filter = Filter.all
    /// 選單開著的那一筆
    private var menuID: UUID?
    private let layout = MasonryLayout()
    private let grid: UICollectionView
    private let backButton = KeyButton()
    private let chipScroll = UIScrollView()
    private let chipStack = UIStackView()
    private let clearButton = KeyButton()
    private let messageLabel = UILabel()
    private let menu = ClipboardMenu()
    /// 清空要按兩次：第一次按鈕變「確定清空？」，3 秒內再按才清（鍵盤裡跳不出確認視窗）
    private var clearArmed = false
    private var clearTimer: Timer?

    override init(frame: CGRect) {
        grid = UICollectionView(frame: .zero, collectionViewLayout: layout)
        super.init(frame: frame)
        // 全透明的地方系統不把觸控送進來：卡片之間的縫也要能捲
        backgroundColor = SamsungTheme.keyAreaBackground
        setUpHeader()
        layout.heightForItem = { [weak self] i, width in
            guard let self, i < shown.count else { return 60 }
            return ClipboardCard.height(for: shown[i], width: width)
        }
        grid.backgroundColor = .clear
        grid.alwaysBounceVertical = true
        grid.register(ClipboardCard.self, forCellWithReuseIdentifier: "c")
        grid.dataSource = self
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 15)
        setUpMenu()

        for v in [backButton, chipScroll, clearButton, grid, messageLabel, menu] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        activateConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    private func setUpHeader() {
        backButton.normalColor = .clear
        backButton.layer.shadowOpacity = 0
        backButton.setIcon("chevron.left", pointSize: SamsungTheme.iconPointSize)
        backButton.firesOnPress = true
        backButton.onTap = { [weak self] in self?.onBack?() }
        backButton.accessibilityLabel = "回到鍵盤"

        chipStack.axis = .horizontal
        chipStack.spacing = 4
        chipScroll.showsHorizontalScrollIndicator = false
        chipScroll.addSubview(chipStack)
        chipStack.translatesAutoresizingMaskIntoConstraints = false

        clearButton.normalColor = .clear
        clearButton.layer.shadowOpacity = 0
        clearButton.label.font = .systemFont(ofSize: 15)
        clearButton.onTap = { [weak self] in self?.tapClear() }
    }

    private func setUpMenu() {
        menu.isHidden = true
        menu.onClose = { [weak self] in self?.closeMenu() }
        menu.onTogglePin = { [weak self] in
            guard let self, let id = menuID else { return }
            closeMenu()
            onTogglePin?(id)
        }
        menu.onDelete = { [weak self] in
            guard let self, let id = menuID else { return }
            closeMenu()
            onDelete?(id)
        }
        // 換標籤選單不關，可以一次勾好幾個
        menu.onToggleTag = { [weak self] tag in
            guard let self, let id = menuID else { return }
            onToggleTag?(tag, id)
        }
    }

    private func activateConstraints() {
        let h = Self.headerHeight
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: topAnchor),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor),
            backButton.widthAnchor.constraint(equalToConstant: 44),
            backButton.heightAnchor.constraint(equalToConstant: h),

            chipScroll.topAnchor.constraint(equalTo: topAnchor, constant: 5),
            chipScroll.heightAnchor.constraint(equalToConstant: h - 10),
            chipScroll.leadingAnchor.constraint(equalTo: backButton.trailingAnchor),
            chipScroll.trailingAnchor.constraint(equalTo: clearButton.leadingAnchor, constant: -4),

            chipStack.topAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.topAnchor),
            chipStack.bottomAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.bottomAnchor),
            chipStack.leadingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.leadingAnchor),
            chipStack.trailingAnchor.constraint(equalTo: chipScroll.contentLayoutGuide.trailingAnchor),
            chipStack.heightAnchor.constraint(equalTo: chipScroll.frameLayoutGuide.heightAnchor),

            clearButton.topAnchor.constraint(equalTo: topAnchor),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SamsungTheme.sideInset),
            clearButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 52),
            clearButton.widthAnchor.constraint(greaterThanOrEqualTo: clearButton.label.widthAnchor, constant: 16),
            clearButton.heightAnchor.constraint(equalToConstant: h),

            grid.topAnchor.constraint(equalTo: topAnchor, constant: h),
            grid.leadingAnchor.constraint(equalTo: leadingAnchor),
            grid.trailingAnchor.constraint(equalTo: trailingAnchor),
            grid.bottomAnchor.constraint(equalTo: bottomAnchor),

            messageLabel.centerYAnchor.constraint(equalTo: grid.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),

            menu.topAnchor.constraint(equalTo: topAnchor),
            menu.bottomAnchor.constraint(equalTo: bottomAnchor),
            menu.leadingAnchor.constraint(equalTo: leadingAnchor),
            menu.trailingAnchor.constraint(equalTo: trailingAnchor),
        ])
    }

    /// 換內容：打開面板、讀到新的、固定／標籤／刪除後呼叫
    func show(_ content: Content) {
        backButton.iconView.tintColor = SamsungTheme.keyText
        clearButton.label.textColor = SamsungTheme.keyText
        messageLabel.textColor = SamsungTheme.hintText
        disarmClear()
        var needsAccess = false
        switch content {
        case let .file(newFile):
            file = newFile
            if case let .tag(name) = filter, !file.tags.contains(name) {
                filter = .all
            }
            clearButton.isHidden = !file.entries.contains { !$0.isKept }
        case .needsFullAccess:
            file = ClipboardHistory.File()
            filter = .all
            clearButton.isHidden = true
            needsAccess = true
        }
        chipScroll.isHidden = needsAccess
        rebuildChips()
        applyFilter(needsAccess: needsAccess)
        refreshMenu()
    }

    /// 打開時捲回最上面、選單收起
    func reset() {
        grid.setContentOffset(.zero, animated: false)
        closeMenu()
    }

    private func applyFilter(needsAccess: Bool = false) {
        shown = file.sorted.filter { entry in
            switch filter {
            case .all: true
            case .pinned: entry.pinned
            case let .tag(name): entry.tags.contains(name)
            }
        }
        if needsAccess {
            messageLabel.text = "要開「允許完全取用」才能讀剪貼簿\n設定 → 一般 → 鍵盤 → 鍵盤 → 豆鍵 → 允許完全取用"
        } else if file.entries.isEmpty {
            messageLabel.text = "還沒有存下任何文字\n在別的 App 複製文字後，回來按剪貼簿鍵就會存進來"
        } else {
            messageLabel.text = "這裡還沒有東西\n按住一張卡片就能固定、加標籤"
        }
        messageLabel.isHidden = !shown.isEmpty
        layout.invalidateLayout()
        grid.reloadData()
    }

    // MARK: - 卡片

    func collectionView(_: UICollectionView, numberOfItemsInSection _: Int) -> Int {
        shown.count
    }

    func collectionView(_ cv: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let reused = cv.dequeueReusableCell(withReuseIdentifier: "c", for: indexPath)
        guard let cell = reused as? ClipboardCard, indexPath.item < shown.count else { return reused }
        let entry = shown[indexPath.item]
        cell.show(entry)
        cell.onTap = { [weak self] in self?.onPick?(entry) }
        cell.onLongPress = { [weak self] in self?.openMenu(entry.id) }
        return cell
    }
}

// MARK: - 篩選（全部、固定、各標籤）、清空、長按選單

private extension ClipboardPanel {
    func rebuildChips() {
        chipStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        var filters: [(Filter, String)] = [(.all, "全部"), (.pinned, "固定")]
        filters += file.tags.map { (Filter.tag($0), "＃" + $0) }
        for (item, title) in filters {
            chipStack.addArrangedSubview(makeChip(item, title: title))
        }
    }

    func makeChip(_ item: Filter, title: String) -> KeyButton {
        let selected = item == filter
        let b = KeyButton()
        b.normalColor = selected ? SamsungTheme.keyWhite : .clear
        b.layer.shadowOpacity = 0
        b.layer.cornerRadius = 15
        b.tapsWhenCancelled = false
        b.label.text = title
        b.label.font = .systemFont(ofSize: 14, weight: selected ? .semibold : .regular)
        b.label.textColor = selected ? SamsungTheme.keyText : SamsungTheme.hintText
        b.accessibilityTraits = selected ? [.button, .selected] : .button
        b.onTap = { [weak self] in
            guard let self else { return }
            filter = item
            rebuildChips()
            applyFilter()
            grid.setContentOffset(.zero, animated: false)
        }
        b.widthAnchor.constraint(greaterThanOrEqualTo: b.label.widthAnchor, constant: 20).isActive = true
        return b
    }

    // MARK: - 清空

    func tapClear() {
        guard clearArmed else {
            clearArmed = true
            clearButton.label.text = "確定清空？"
            clearTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
                self?.disarmClear()
            }
            return
        }
        disarmClear()
        onClear?()
    }

    func disarmClear() {
        clearTimer?.invalidate()
        clearTimer = nil
        clearArmed = false
        clearButton.label.text = "清空"
    }

    // MARK: - 長按選單

    func openMenu(_ id: UUID) {
        menuID = id
        refreshMenu()
    }

    func closeMenu() {
        menuID = nil
        menu.isHidden = true
    }

    /// 選單開著時照最新的資料重排（標籤打勾）；那筆被刪了就關掉
    func refreshMenu() {
        guard let id = menuID, let entry = file.entries.first(where: { $0.id == id }) else {
            closeMenu()
            return
        }
        menu.show(entry, allTags: file.tags)
        menu.isHidden = false
    }
}
