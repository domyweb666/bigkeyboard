import UIKit

/// 工具列那排：橫向列出候選字（或打完字後的聯想詞），右端一顆展開鍵看全部候選。
/// 正在組的注音不顯示在這裡——它直接顯示在輸入框游標處（跟原生鍵盤一樣）。
final class CandidateBar: UIView {
    var onSelect: ((Int) -> Void)?
    var onToggleExpand: (() -> Void)?

    /// 一列最多放幾個。每打一個注音這列就重建一次，常見的音候選有上百個，全放打字會卡；更多的按 ⌄ 展開看
    private static let maxShown = 30

    /// 套淡出遮罩用的外框（遮罩不能直接套在會捲動的 scroll 上，會跟著內容跑）
    private let clip = UIView()
    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let expandButton = KeyButton()
    private let divider = UIView()
    /// 右端淡出：讓人看得出候選還能往右滑，最後一個字也不會被分隔線硬切一半。
    /// 用遮罩讓字本身漸漸透明，不是蓋一層底色上去：鍵盤底是透明的，蓋什麼顏色都會穿幫
    private let fade = CAGradientLayer()
    private let fadeWidth: CGFloat = 36

    override init(frame: CGRect) {
        super.init(frame: frame)
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        fade.colors = [UIColor.black.cgColor, UIColor.black.cgColor, UIColor.clear.cgColor]
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .fill
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(stack)
        clip.addSubview(scroll)

        expandButton.normalColor = .clear
        expandButton.layer.shadowOpacity = 0
        expandButton.setIcon("chevron.down")
        expandButton.onTap = { [weak self] in self?.onToggleExpand?() }

        divider.backgroundColor = SamsungTheme.hintText.withAlphaComponent(0.4)

        for v in [clip, expandButton, divider] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        scroll.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false

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

            expandButton.trailingAnchor.constraint(equalTo: trailingAnchor),
            expandButton.topAnchor.constraint(equalTo: topAnchor),
            expandButton.bottomAnchor.constraint(equalTo: bottomAnchor),
            expandButton.widthAnchor.constraint(equalToConstant: 44),

            stack.leadingAnchor.constraint(equalTo: scroll.contentLayoutGuide.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: scroll.contentLayoutGuide.trailingAnchor),
            // 上面多留一點給收鍵盤的拖曳條，候選字不跟它疊在一起
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 8),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -2),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -10),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        // 先排好 scroll 裡面，才量得到這一列候選實際多寬
        scroll.layoutIfNeeded()
        updateFade()
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

    /// highlightFirst：第一個是「按空白會送出的那個」時打亮（組字中）；聯想詞不打亮
    func update(candidates: [String], highlightFirst: Bool, expanded: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, c) in candidates.prefix(Self.maxShown).enumerated() {
            let b = KeyButton()
            b.label.text = c
            b.label.font = .systemFont(ofSize: SamsungTheme.candidateFontSize)
            b.label.adjustsFontSizeToFitWidth = false
            b.layer.shadowOpacity = 0
            b.normalColor = (i == 0 && highlightFirst) ? SamsungTheme.keyWhite : .clear
            b.tag = i
            b.onTap = { [weak self] in self?.onSelect?(i) }
            b.widthAnchor.constraint(greaterThanOrEqualTo: b.label.widthAnchor, constant: 18).isActive = true
            b.widthAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
            stack.addArrangedSubview(b)
        }
        scroll.setContentOffset(.zero, animated: false)
        setNeedsLayout()
        let canExpand = candidates.count > 0
        expandButton.isHidden = !canExpand
        divider.isHidden = !canExpand
        expandButton.setIcon(expanded ? "chevron.up" : "chevron.down")
    }
}
