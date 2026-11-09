import UIKit

/// 工具列那排：橫向列出候選字（或打完字後的聯想詞、英文預測字）。
/// 右邊依序是展開鍵（看全部候選）、剪貼簿鍵、收鍵盤鍵（2026-11-09 多米定的順序）
/// 正在組的注音不顯示在這裡——它直接顯示在輸入框游標處（跟原生鍵盤一樣）。
final class CandidateBar: UIView {
    var onSelect: ((Int) -> Void)?
    var onToggleExpand: (() -> Void)?
    /// 收鍵盤
    var onDismiss: (() -> Void)?
    /// 打開／關上剪貼簿
    var onClipboard: (() -> Void)?

    /// 一列最多放幾個。常見的音候選有上百個，全放打字會卡；更多的按 ⌄ 展開看
    private static let maxShown = 30
    /// 候選字的按鈕。每打一個注音都要換一次字：按鈕留著重用，只換字、藏起用不到的，
    /// 不每次拆掉重建（重建 30 顆連同排版要好幾毫秒，快打時會讓按鍵反應慢半拍）
    private var chips: [KeyButton] = []

    /// 套淡出遮罩用的外框（遮罩不能直接套在會捲動的 scroll 上，會跟著內容跑）
    private let clip = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let clipboardButton = KeyButton()
    private let expandButton = KeyButton()
    private let dismissButton = KeyButton()
    private let divider = UIView()
    /// 右端淡出：讓人看得出候選還能往右滑，最後一個字也不會被分隔線硬切一半。
    /// 用遮罩讓字本身漸漸透明，不是蓋一層底色上去：鍵盤底是透明的，蓋什麼顏色都會穿幫
    private let fade = CAGradientLayer()
    private let fadeWidth: CGFloat = 36

    override init(frame: CGRect) {
        super.init(frame: frame)
        // 全透明的地方系統不把觸控送進來：展開鍵、收鍵盤鍵、候選字的底都是透明的，
        // 只有圖示和字的筆畫按得到（2026-11-09 多米：⌄ 按好幾次才有反應）。跟鍵區一樣墊一層近乎透明的底
        backgroundColor = SamsungTheme.keyAreaBackground
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        fade.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .fill
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(stack)
        clip.addSubview(scroll)

        setUpButtons()

        for v in [clip, clipboardButton, expandButton, dismissButton, divider] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        activateConstraints()
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    /// 剪貼簿鍵、展開鍵、收鍵盤鍵、分隔線的樣子與動作
    private func setUpButtons() {
        clipboardButton.normalColor = .clear
        clipboardButton.layer.shadowOpacity = 0
        clipboardButton.setIcon("doc.on.clipboard", pointSize: SamsungTheme.clipboardIconPointSize)
        clipboardButton.onTap = { [weak self] in self?.onClipboard?() }
        clipboardButton.firesOnPress = true
        clipboardButton.accessibilityLabel = "剪貼簿"

        expandButton.normalColor = .clear
        expandButton.layer.shadowOpacity = 0
        expandButton.setIcon("chevron.down", pointSize: SamsungTheme.expandIconPointSize)
        expandButton.onTap = { [weak self] in self?.onToggleExpand?() }
        // 按下就展開，不等放開（放開前觸控被系統取消也不會沒反應）
        expandButton.firesOnPress = true
        expandButton.accessibilityLabel = "全部候選字"

        // 收鍵盤：跟系統工具列同一個圖示。放最右邊貼著螢幕邊緣，把展開鍵讓到裡面一點
        // （2026-11-02 多米：展開鍵在邊緣按了常沒反應）
        dismissButton.normalColor = .clear
        dismissButton.layer.shadowOpacity = 0
        dismissButton.setIcon("keyboard.chevron.compact.down", pointSize: SamsungTheme.dismissIconPointSize)
        dismissButton.onTap = { [weak self] in self?.onDismiss?() }
        dismissButton.firesOnPress = true
        dismissButton.isAccessibilityElement = true
        dismissButton.accessibilityLabel = "收起鍵盤"
        dismissButton.accessibilityTraits = .button

        applyTheme()
    }

    private func activateConstraints() {
        NSLayoutConstraint.activate([
            clip.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            clip.trailingAnchor.constraint(equalTo: divider.leadingAnchor),
            clip.topAnchor.constraint(equalTo: topAnchor),
            clip.bottomAnchor.constraint(equalTo: bottomAnchor),

            scroll.leadingAnchor.constraint(equalTo: clip.leadingAnchor),
            scroll.trailingAnchor.constraint(equalTo: clip.trailingAnchor),
            scroll.topAnchor.constraint(equalTo: clip.topAnchor),
            scroll.bottomAnchor.constraint(equalTo: clip.bottomAnchor),

            divider.trailingAnchor.constraint(equalTo: expandButton.leadingAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),
            divider.topAnchor.constraint(equalTo: topAnchor, constant: 10),
            divider.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -10),

            clipboardButton.trailingAnchor.constraint(equalTo: dismissButton.leadingAnchor),
            clipboardButton.topAnchor.constraint(equalTo: topAnchor),
            clipboardButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            clipboardButton.widthAnchor.constraint(equalToConstant: SamsungTheme.barButtonWidth),

            expandButton.trailingAnchor.constraint(equalTo: clipboardButton.leadingAnchor),
            expandButton.topAnchor.constraint(equalTo: topAnchor),
            expandButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: SamsungTheme.barButtonWidth),

            dismissButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            dismissButton.topAnchor.constraint(equalTo: topAnchor),
            dismissButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            dismissButton.widthAnchor.constraint(equalToConstant: SamsungTheme.barButtonWidth),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            // 頂端的拖曳條拿掉了（2026-11-02），候選字上下置中
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 5),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -5),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -10),
        ])
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 先排好 scroll 裡面，才量得到這一列候選實際多寬
        scroll.layoutIfNeeded()
        updateFade()
    }

    /// 照目前主題上色、換字（候選字按鈕會重複使用，換主題後全部重設）
    func applyTheme() {
        divider.backgroundColor = SamsungTheme.hintText.withAlphaComponent(0.4)
        clipboardButton.iconView.tintColor = SamsungTheme.keyText
        expandButton.iconView.tintColor = SamsungTheme.keyText
        dismissButton.iconView.tintColor = SamsungTheme.hintText
        for chip in chips {
            styleChip(chip)
        }
    }

    private func styleChip(_ b: KeyButton) {
        b.label.font = SamsungTheme.keyFont(ofSize: SamsungTheme.candidateFontSize)
        b.label.textColor = SamsungTheme.keyText
        b.layer.cornerRadius = SamsungTheme.keyCornerRadius
    }

    /// 候選放不下才淡出；放得下就整列清楚
    private func updateFade() {
        let w = clip.bounds.width
        guard w > fadeWidth, stack.frame.width > w else {
            clip.layer.mask = nil
            return
        }
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = clip.bounds
        fade.locations = [0, NSNumber(value: Double((w - fadeWidth) / w)), 1]
        CATransaction.commit()
        clip.layer.mask = fade
    }

    /// highlightFirst：第一個是「按空白會送出的那個」時打亮（組字中）；聯想詞、英文預測字不打亮。
    /// clipboardOpen：剪貼簿開著時剪貼簿鍵打亮
    func update(candidates: [String], highlightFirst: Bool, expanded: Bool, clipboardOpen: Bool) {
        clipboardButton.normalColor = clipboardOpen ? SamsungTheme.keyWhite : .clear
        let shown = Array(candidates.prefix(Self.maxShown))
        while chips.count < shown.count {
            chips.append(makeChip(chips.count))
        }
        for (i, chip) in chips.enumerated() {
            guard i < shown.count else {
                chip.isHidden = true
                continue
            }
            chip.label.text = shown[i]
            chip.normalColor = (i == 0 && highlightFirst) ? SamsungTheme.keyWhite : .clear
            chip.isHidden = false
        }
        scroll.setContentOffset(.zero, animated: false)
        setNeedsLayout()
        // 沒有候選時展開鍵藏起來，分隔線照樣隔開收鍵盤鍵
        expandButton.isHidden = candidates.isEmpty
        expandButton.setIcon(expanded ? "chevron.up" : "chevron.down", pointSize: SamsungTheme.expandIconPointSize)
    }

    /// 第 i 個位置的候選按鈕（點了就選第 i 個）
    private func makeChip(_ i: Int) -> KeyButton {
        let b = KeyButton()
        styleChip(b)
        b.label.adjustsFontSizeToFitWidth = false
        b.layer.shadowOpacity = 0
        b.tag = i
        b.onTap = { [weak self] in self?.onSelect?(i) }
        b.tapsWhenCancelled = false
        b.widthAnchor.constraint(greaterThanOrEqualTo: b.label.widthAnchor, constant: 18).isActive = true
        b.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
        stack.addArrangedSubview(b)
        return b
    }
}
