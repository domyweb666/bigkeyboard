import UIKit

/// 剪貼簿面板：跟展開全部候選一樣蓋在鍵區上。上面一排「返回、剪貼簿、清空」，下面是存下來的文字。
/// 點一筆貼上、圖釘固定、左滑刪除。面板只管顯示與把手指的動作交出去，讀寫紀錄在 KeyboardViewController+Clipboard。
final class ClipboardPanel: UIView, UITableViewDataSource, UITableViewDelegate {
    enum Content {
        case entries([ClipboardHistory.Entry])
        /// 沒開完全取用：讀不到系統剪貼簿，也存不了
        case needsFullAccess
    }

    var onBack: (() -> Void)?
    var onPick: ((ClipboardHistory.Entry) -> Void)?
    var onTogglePin: ((UUID) -> Void)?
    var onDelete: ((UUID) -> Void)?
    var onClear: (() -> Void)?

    private static let headerHeight: CGFloat = 44
    private static let textFontSize: CGFloat = 17

    private var entries: [ClipboardHistory.Entry] = []
    private let backButton = KeyButton()
    private let titleLabel = UILabel()
    private let clearButton = KeyButton()
    private let table = UITableView(frame: .zero, style: .plain)
    private let messageLabel = UILabel()
    /// 清空要按兩次：第一次按鈕變「確定清空？」，3 秒內再按才清（鍵盤裡跳不出確認視窗）
    private var clearArmed = false
    private var clearTimer: Timer?

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 全透明的地方系統不把觸控送進來：格子之間的縫也要能捲
        backgroundColor = SamsungTheme.keyAreaBackground
        setUpHeader()
        table.backgroundColor = .clear
        table.separatorStyle = .none
        table.rowHeight = UITableView.automaticDimension
        table.estimatedRowHeight = 64
        table.register(Cell.self, forCellReuseIdentifier: "c")
        table.dataSource = self
        table.delegate = self
        messageLabel.numberOfLines = 0
        messageLabel.textAlignment = .center
        messageLabel.font = .systemFont(ofSize: 16)

        for v in [backButton, titleLabel, clearButton, table, messageLabel] {
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

        titleLabel.text = "剪貼簿"
        titleLabel.textAlignment = .center
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)

        clearButton.normalColor = .clear
        clearButton.layer.shadowOpacity = 0
        clearButton.label.font = .systemFont(ofSize: 16)
        clearButton.onTap = { [weak self] in self?.tapClear() }
    }

    private func activateConstraints() {
        let h = Self.headerHeight
        NSLayoutConstraint.activate([
            backButton.topAnchor.constraint(equalTo: topAnchor),
            backButton.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SamsungTheme.sideInset),
            backButton.widthAnchor.constraint(equalToConstant: SamsungTheme.barButtonWidth),
            backButton.heightAnchor.constraint(equalToConstant: h),

            titleLabel.centerXAnchor.constraint(equalTo: centerXAnchor),
            titleLabel.centerYAnchor.constraint(equalTo: backButton.centerYAnchor),

            clearButton.topAnchor.constraint(equalTo: topAnchor),
            clearButton.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SamsungTheme.sideInset),
            clearButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 64),
            clearButton.widthAnchor.constraint(greaterThanOrEqualTo: clearButton.label.widthAnchor, constant: 20),
            clearButton.heightAnchor.constraint(equalToConstant: h),

            table.topAnchor.constraint(equalTo: topAnchor, constant: h),
            table.leadingAnchor.constraint(equalTo: leadingAnchor),
            table.trailingAnchor.constraint(equalTo: trailingAnchor),
            table.bottomAnchor.constraint(equalTo: bottomAnchor),

            messageLabel.centerYAnchor.constraint(equalTo: table.centerYAnchor),
            messageLabel.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 24),
            messageLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -24),
        ])
    }

    /// 換內容：每次打開面板、讀到新的、釘選或刪除後呼叫
    func show(_ content: Content) {
        applyTheme()
        disarmClear()
        switch content {
        case let .entries(list):
            entries = list
            messageLabel.text = "還沒有存下任何文字\n在別的 App 複製文字後，回來按剪貼簿鍵就會存進來"
            messageLabel.isHidden = !list.isEmpty
            clearButton.isHidden = !list.contains { !$0.pinned }
        case .needsFullAccess:
            entries = []
            messageLabel.text = "要開「允許完全取用」才能讀剪貼簿\n設定 → 一般 → 鍵盤 → 鍵盤 → 豆鍵 → 允許完全取用"
            messageLabel.isHidden = false
            clearButton.isHidden = true
        }
        table.reloadData()
    }

    /// 打開時捲回最上面
    func scrollToTop() {
        table.setContentOffset(.zero, animated: false)
    }

    private func applyTheme() {
        backButton.iconView.tintColor = SamsungTheme.keyText
        titleLabel.textColor = SamsungTheme.keyText
        clearButton.label.textColor = SamsungTheme.keyText
        messageLabel.textColor = SamsungTheme.hintText
    }

    private func tapClear() {
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

    private func disarmClear() {
        clearTimer?.invalidate()
        clearTimer = nil
        clearArmed = false
        clearButton.label.text = "清空"
    }

    // MARK: - 清單

    func tableView(_: UITableView, numberOfRowsInSection _: Int) -> Int {
        entries.count
    }

    func tableView(_ tv: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let reused = tv.dequeueReusableCell(withIdentifier: "c", for: indexPath)
        guard let cell = reused as? Cell else { return reused }
        let entry = entries[indexPath.row]
        cell.show(entry)
        cell.onTogglePin = { [weak self] in self?.onTogglePin?(entry.id) }
        return cell
    }

    func tableView(_ tv: UITableView, didSelectRowAt indexPath: IndexPath) {
        tv.deselectRow(at: indexPath, animated: false)
        guard indexPath.row < entries.count else { return }
        onPick?(entries[indexPath.row])
    }

    func tableView(
        _: UITableView,
        trailingSwipeActionsConfigurationForRowAt indexPath: IndexPath
    ) -> UISwipeActionsConfiguration? {
        guard indexPath.row < entries.count else { return nil }
        let id = entries[indexPath.row].id
        let delete = UIContextualAction(style: .destructive, title: "刪除") { [weak self] _, _, done in
            self?.onDelete?(id)
            done(true)
        }
        return UISwipeActionsConfiguration(actions: [delete])
    }

    /// 一筆：最多兩行預覽（長文只顯示開頭，點了照樣貼整段），右邊一顆圖釘
    private final class Cell: UITableViewCell {
        var onTogglePin: (() -> Void)?
        private let card = UIView()
        private let preview = UILabel()
        private let pinButton = KeyButton()

        override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
            super.init(style: style, reuseIdentifier: reuseIdentifier)
            backgroundColor = .clear
            contentView.backgroundColor = .clear
            selectionStyle = .none
            preview.numberOfLines = 2
            preview.lineBreakMode = .byTruncatingTail
            preview.font = .systemFont(ofSize: ClipboardPanel.textFontSize)
            pinButton.normalColor = .clear
            pinButton.layer.shadowOpacity = 0
            pinButton.tapsWhenCancelled = false
            pinButton.onTap = { [weak self] in self?.onTogglePin?() }
            for v in [card, preview, pinButton] {
                v.translatesAutoresizingMaskIntoConstraints = false
                contentView.addSubview(v)
            }
            NSLayoutConstraint.activate([
                card.topAnchor.constraint(equalTo: contentView.topAnchor, constant: SamsungTheme.keyGap / 2),
                card.bottomAnchor.constraint(equalTo: contentView.bottomAnchor, constant: -SamsungTheme.keyGap / 2),
                card.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: SamsungTheme.sideInset),
                card.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -SamsungTheme.sideInset),

                preview.topAnchor.constraint(equalTo: card.topAnchor, constant: 12),
                preview.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -12),
                preview.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 14),
                preview.trailingAnchor.constraint(equalTo: pinButton.leadingAnchor),

                pinButton.topAnchor.constraint(equalTo: card.topAnchor),
                pinButton.bottomAnchor.constraint(equalTo: card.bottomAnchor),
                pinButton.trailingAnchor.constraint(equalTo: card.trailingAnchor),
                pinButton.widthAnchor.constraint(equalToConstant: 48),
            ])
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("not used")
        }

        func show(_ entry: ClipboardHistory.Entry) {
            card.backgroundColor = SamsungTheme.keyWhite
            card.layer.cornerRadius = SamsungTheme.keyCornerRadius
            preview.textColor = SamsungTheme.keyText
            // 換行換成空白，兩行預覽才看得到比較多字
            preview.text = entry.text.replacingOccurrences(of: "\n", with: " ")
            pinButton.setIcon(entry.pinned ? "pin.fill" : "pin", pointSize: 17)
            pinButton.iconView.tintColor = entry.pinned ? SamsungTheme.keyText : SamsungTheme.hintText
            pinButton.accessibilityLabel = entry.pinned ? "取消固定" : "固定"
        }

        override func setHighlighted(_ highlighted: Bool, animated _: Bool) {
            card.backgroundColor = highlighted ? SamsungTheme.keyPressed : SamsungTheme.keyWhite
        }
    }
}
