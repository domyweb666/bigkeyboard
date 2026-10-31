import UIKit

/// 把一張鍵位表（資料）渲染成按鍵。所有鍵面共用這一份程式。
final class KeyboardView: UIView {
    var onKey: ((KeySpec) -> Void)?

    private let rowsStack = UIStackView()
    private var specs: [UIButton: KeySpec] = [:]

    override init(frame: CGRect) {
        super.init(frame: frame)
        rowsStack.axis = .vertical
        rowsStack.spacing = SamsungTheme.rowGap
        rowsStack.distribution = .fillEqually
        rowsStack.translatesAutoresizingMaskIntoConstraints = false
        addSubview(rowsStack)
        NSLayoutConstraint.activate([
            rowsStack.topAnchor.constraint(equalTo: topAnchor, constant: SamsungTheme.rowGap),
            rowsStack.bottomAnchor.constraint(equalTo: bottomAnchor, constant: -SamsungTheme.rowGap),
            rowsStack.leadingAnchor.constraint(equalTo: leadingAnchor, constant: SamsungTheme.sideInset),
            rowsStack.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -SamsungTheme.sideInset),
        ])
    }

    @available(*, unavailable)
    required init?(coder _: NSCoder) {
        fatalError("not used")
    }

    func load(_ rows: [KeyRow]) {
        rowsStack.arrangedSubviews.forEach { $0.removeFromSuperview() }
        specs.removeAll()
        for row in rows {
            let rowStack = UIStackView()
            rowStack.axis = .horizontal
            rowStack.spacing = SamsungTheme.keyGap
            rowStack.alignment = .fill
            let total = row.reduce(0) { $0 + $1.width }
            for spec in row {
                let b = makeButton(spec)
                rowStack.addArrangedSubview(b)
                // 寬度照相對權重分配；扣掉間距後的可用寬度 × 權重比例
                let gaps = SamsungTheme.keyGap * CGFloat(row.count - 1)
                b.widthAnchor.constraint(
                    equalTo: rowStack.widthAnchor,
                    multiplier: spec.width / total,
                    constant: -gaps * spec.width / total
                ).isActive = true
            }
            rowsStack.addArrangedSubview(rowStack)
        }
    }

    private func makeButton(_ spec: KeySpec) -> UIButton {
        let b = UIButton(type: .custom)
        b.setTitle(spec.label, for: .normal)
        b.titleLabel?.font = .systemFont(ofSize: spec.isFunction ? SamsungTheme.functionFontSize : SamsungTheme.keyFontSize)
        b.setTitleColor(SamsungTheme.keyText, for: .normal)
        b.backgroundColor = spec.isFunction ? SamsungTheme.keyGray : SamsungTheme.keyWhite
        b.layer.cornerRadius = SamsungTheme.keyCornerRadius
        b.addTarget(self, action: #selector(tapped(_:)), for: .touchUpInside)
        b.addTarget(self, action: #selector(pressed(_:)), for: .touchDown)
        b.addTarget(self, action: #selector(released(_:)), for: [.touchUpInside, .touchUpOutside, .touchCancel])
        specs[b] = spec
        return b
    }

    @objc private func tapped(_ sender: UIButton) {
        guard let spec = specs[sender] else { return }
        onKey?(spec)
    }

    @objc private func pressed(_ sender: UIButton) {
        sender.backgroundColor = SamsungTheme.keyPressed
    }

    @objc private func released(_ sender: UIButton) {
        guard let spec = specs[sender] else { return }
        sender.backgroundColor = spec.isFunction ? SamsungTheme.keyGray : SamsungTheme.keyWhite
    }
}
