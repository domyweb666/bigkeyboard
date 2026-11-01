import UIKit

/// 工具列那排：橫向列出候選字（或打完字後的聯想詞），右端一顆展開鍵看全部候選。
/// 正在組的注音不顯示在這裡——它直接顯示在輸入框游標處（跟原生鍵盤一樣）。
final class CandidateBar: UIView {
    var onSelect: ((Int) -> Void)?
    var onToggleExpand: (() -> Void)?

    private let scroll = UIScrollView()
    private let stack = UIStackView()
    private let expandButton = KeyButton()
    private let divider = UIView()
    /// 右端淡出：讓人看得出候選還能往右滑，最後一個字也不會被分隔線硬切一半
    private let fade = CAGradientLayer()
    private let fadeWidth: CGFloat = 36

    override init(frame: CGRect) {
        super.init(frame: frame)
        fade.startPoint = CGPoint(x: 0, y: 0.5)
        fade.endPoint = CGPoint(x: 1, y: 0.5)
        updateFadeColors()
        stack.axis = .horizontal
        stack.spacing = 2
        stack.alignment = .fill
        scroll.showsHorizontalScrollIndicator = false
        scroll.addSubview(stack)

        expandButton.normalColor = .clear
        expandButton.layer.shadowOpacity = 0
        expandButton.setIcon("chevron.down")
        expandButton.onTap = { [weak self] in self?.onToggleExpand?() }

        divider.backgroundColor = SamsungTheme.hintText.withAlphaComponent(0.4)

        for v in [scroll, expandButton, divider] {
            v.translatesAutoresizingMaskIntoConstraints = false
            addSubview(v)
        }
        stack.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            scroll.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 4),
            scroll.trailingAnchor.constraint(equalTo: divider.leadingAnchor),
            scroll.topAnchor.constraint(equalTo: topAnchor),
            scroll.bottomAnchor.constraint(equalTo: bottomAnchor),

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
            stack.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 4),
            stack.bottomAnchor.constraint(equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -4),
            stack.heightAnchor.constraint(equalTo: scroll.frameLayoutGuide.heightAnchor, constant: -8),
        ])
        layer.addSublayer(fade)
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let f = scroll.frame
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        fade.frame = CGRect(x: f.maxX - fadeWidth, y: f.minY, width: fadeWidth, height: f.height)
        CATransaction.commit()
        updateFadeVisibility()
    }

    override func traitCollectionDidChange(_ previous: UITraitCollection?) {
        super.traitCollectionDidChange(previous)
        updateFadeColors()
    }

    private func updateFadeColors() {
        let bg = SamsungTheme.background.resolvedColor(with: traitCollection)
        fade.colors = [bg.withAlphaComponent(0).cgColor, bg.cgColor]
    }

    /// 候選放得下就不淡出
    private func updateFadeVisibility() {
        fade.isHidden = stack.frame.width <= scroll.frame.width
    }

    /// highlightFirst：第一個是「按空白會送出的那個」時打亮（組字中）；聯想詞不打亮
    func update(candidates: [String], highlightFirst: Bool, expanded: Bool) {
        stack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        for (i, c) in candidates.enumerated() {
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
