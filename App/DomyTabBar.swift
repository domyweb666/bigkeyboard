import SwiftUI

/// App 底部的四個分頁。使用說明併在設定頁裡
enum AppTab: Hashable, CaseIterable {
    case dictionary
    case clipboard
    case themes
    case settings

    var title: String {
        switch self {
        case .dictionary: "字典"
        case .clipboard: "剪貼簿"
        case .themes: "主題"
        case .settings: "設定"
        }
    }

    var icon: String {
        switch self {
        case .dictionary: "book"
        case .clipboard: "doc.on.clipboard"
        case .themes: "paintpalette"
        case .settings: "gearshape"
        }
    }
}

/// Domy 的懸浮膠囊分頁列：白底膠囊浮在畫面底部，選中的那格是產品色淡底
struct DomyTabBar: View {
    /// 捲動內容底部要留的高度（分頁列＋離底的距離＋一點空隙）
    static let clearance = Metric.tabBarBottom + Metric.tabBar + Gap.s4

    @Binding var selection: AppTab

    var body: some View {
        HStack(spacing: Gap.s1) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                Button {
                    selection = tab
                } label: {
                    item(tab)
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == tab ? .isSelected : [])
            }
        }
        .padding(Gap.s1 + Gap.s1 / 2)
        .frame(width: Metric.tabBarWidth, height: Metric.tabBar)
        .background(Ink.surface, in: Capsule())
        .domyShadow(DomyTokens.Elevation.level2)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func item(_ tab: AppTab) -> some View {
        let selected = selection == tab
        return VStack(spacing: Gap.s1 / 2) {
            Image(systemName: tab.icon)
                .font(.system(size: Metric.row / 2 - Gap.s1))
            Text(tab.title)
                .font(Typo.caption.font.weight(selected ? .semibold : .medium))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .foregroundStyle(selected ? Brand.theme.strong : Ink.textPrimary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(selected ? Brand.theme.soft : Color.clear, in: Capsule())
        .contentShape(Capsule())
    }
}
