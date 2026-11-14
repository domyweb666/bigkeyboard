import SwiftUI

// Domy 設計系統在豆鍵 App 裡的本地元件：按鈕、分組卡、大標題、搜尋框、＋按鈕、空狀態、小膠囊。
// 全部只用 Design/DomyTokens.swift 的代號組出來

/// Domy 的按鈕。primary 一個畫面最多一顆；secondary 中性；destructive 給危險操作
struct DomyButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
        case destructive
    }

    var kind = Kind.primary
    /// 小顆：36 高、不撐滿寬
    var compact = false

    func makeBody(configuration: Configuration) -> some View {
        DomyButtonBody(configuration: configuration, kind: kind, compact: compact)
    }
}

/// 按鈕的長相。另外包一層 View 才讀得到 isEnabled（ButtonStyle 自己讀不到）
private struct DomyButtonBody: View {
    let configuration: ButtonStyleConfiguration
    let kind: DomyButtonStyle.Kind
    let compact: Bool
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        configuration.label
            .font((compact ? Typo.callout : Typo.headline).font)
            .foregroundStyle(isEnabled ? foreground : Ink.textDisabled)
            .padding(.horizontal, compact ? Gap.s4 : Gap.s6)
            .frame(maxWidth: compact ? nil : .infinity, minHeight: compact ? Metric.buttonCompact : Metric.button)
            .background(isEnabled ? background : Ink.surfaceMuted, in: Capsule())
            .contentShape(Capsule())
            .scaleEffect(configuration.isPressed ? DomyTokens.Motion.pressScale : 1)
            .animation(.easeOut(duration: DomyTokens.Motion.pressDuration), value: configuration.isPressed)
    }

    private var foreground: Color {
        switch kind {
        case .primary: Brand.theme.onAccent
        case .secondary: Ink.textPrimary
        case .destructive: Ink.destructive
        }
    }

    private var background: Color {
        switch kind {
        case .primary: Brand.theme.accent
        case .secondary: Ink.surfaceMuted
        case .destructive: Ink.destructiveSoft
        }
    }
}

/// 分組：標題＋一張白卡＋說明小字。卡裡的列之間自己放 DomyDivider
struct DomySection<Content: View>: View {
    private let title: String?
    private let footer: String?
    private let content: Content

    init(_ title: String? = nil, footer: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.footer = footer
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Gap.s2) {
            if let title {
                Text(title)
                    .font(Typo.title3.font)
                    .foregroundStyle(Ink.textPrimary)
                    .padding(.horizontal, Gap.s1)
                    .accessibilityAddTraits(.isHeader)
            }
            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, Gap.s4)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.xl))
            if let footer {
                Text(footer)
                    .font(Typo.footnote.font)
                    .foregroundStyle(Ink.textSecondary)
                    .padding(.horizontal, Gap.s4)
            }
        }
    }
}

/// 卡片裡列與列之間的 1pt 分隔線
struct DomyDivider: View {
    var body: some View {
        Rectangle()
            .fill(Ink.separator)
            .frame(height: Metric.hairline)
    }
}

/// 畫面最上面的大標題
struct DomyTitle: View {
    private let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text)
            .font(Typo.largeTitle.font)
            .foregroundStyle(Ink.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }
}

/// 白底膠囊搜尋框
struct DomySearchField: View {
    let prompt: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: Gap.s2) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(Ink.textSecondary)
                .accessibilityHidden(true)
            TextField(prompt, text: $text, prompt: Text(prompt).foregroundStyle(Ink.textSecondary))
                .font(Typo.body.font)
                .foregroundStyle(Ink.textPrimary)
                .submitLabel(.search)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Ink.textTertiary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("清除搜尋")
            }
        }
        .padding(.horizontal, Gap.s4)
        .frame(minHeight: Metric.touch)
        .background(Ink.surface, in: Capsule())
    }
}

/// 右下角的＋按鈕：產品色圓鈕，浮在分頁列上方
struct DomyAddButton: View {
    /// 給讀螢幕軟體念的名稱（只有圖示，沒有字）
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Brand.theme.onAccent)
                .frame(width: Metric.button + Gap.s2, height: Metric.button + Gap.s2)
                .background(Brand.theme.accent, in: Circle())
                .domyShadow(DomyTokens.Elevation.level2)
        }
        .accessibilityLabel(label)
    }
}

/// 空狀態：說清楚這裡會出現什麼、下一步按哪裡
struct DomyEmptyState: View {
    var icon: String?
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: Gap.s3) {
            if let icon {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Brand.theme.accent)
                    .frame(width: Metric.emptyIcon, height: Metric.emptyIcon)
                    .background(Brand.theme.soft, in: Circle())
                    .accessibilityHidden(true)
            }
            Text(title)
                .font(Typo.title3.font)
                .foregroundStyle(Ink.textPrimary)
            Text(message)
                .font(Typo.subheadline.font)
                .foregroundStyle(Ink.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, Gap.s8)
        .padding(.horizontal, Gap.s6)
    }
}

/// 小膠囊標記：自動／手動、選用、使用中、價格、標籤
struct DomyPill: View {
    enum Tone {
        /// 產品色淡底
        case soft
        /// 中性灰底
        case muted
        /// 產品色實底
        case solid
    }

    let text: String
    var icon: String?
    var tone = Tone.soft

    var body: some View {
        HStack(spacing: Gap.s1) {
            if let icon {
                Image(systemName: icon)
                    .imageScale(.small)
            }
            Text(text)
                .lineLimit(1)
        }
        .font(Typo.caption.font.weight(.semibold))
        .foregroundStyle(foreground)
        .padding(.horizontal, Gap.s2 + Gap.s1 / 2)
        .padding(.vertical, Gap.s1)
        .background(background, in: Capsule())
    }

    private var foreground: Color {
        switch tone {
        case .soft: Brand.theme.strong
        case .muted: Ink.textSecondary
        case .solid: Brand.theme.onAccent
        }
    }

    private var background: Color {
        switch tone {
        case .soft: Brand.theme.soft
        case .muted: Ink.surfaceMuted
        case .solid: Brand.theme.accent
        }
    }
}

/// 一排放不下就換行（標籤膠囊用）
struct FlowLayout: Layout {
    var spacing: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout Void) -> CGSize {
        let width = proposal.width ?? .infinity
        let rows = arrange(subviews, width: width)
        return CGSize(width: width.isFinite ? width : rows.width, height: rows.height)
    }

    func placeSubviews(in bounds: CGRect, proposal _: ProposedViewSize, subviews: Subviews, cache _: inout Void) {
        let rows = arrange(subviews, width: bounds.width)
        for (i, point) in rows.points.enumerated() {
            subviews[i].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    /// 每個子畫面的左上角位置，和排完的總寬高
    private struct Rows {
        var points: [CGPoint] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(_ subviews: Subviews, width: CGFloat) -> Rows {
        var rows = Rows()
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            rows.points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
            rows.width = max(rows.width, x - spacing)
        }
        rows.height = y + rowHeight
        return rows
    }
}
