import SwiftUI

/// 設定頁的一列：圖示＋名稱＋右側狀態或箭頭（› 是 app 內下一頁，↗ 是跳出 app）
struct VeggieRow: View {
    enum Accessory {
        case none
        /// app 內的下一頁
        case push
        /// 跳出 app（瀏覽器、App Store、寄信）
        case external
    }

    let icon: String
    let title: String
    var value: String?
    var accessory = Accessory.none
    var destructive = false

    var body: some View {
        HStack(spacing: Gap.s3) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(destructive ? Ink.destructive : Brand.theme.accent)
                .frame(width: Gap.s6)
                .accessibilityHidden(true)
            Text(title)
                .font(Typo.body.font)
                .foregroundStyle(destructive ? Ink.destructive : Ink.textPrimary)
            Spacer(minLength: Gap.s2)
            if let value {
                Text(value)
                    .font(Typo.body.font)
                    .foregroundStyle(Ink.textSecondary)
            }
            switch accessory {
            case .none:
                EmptyView()
            case .push:
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Ink.textTertiary)
                    .accessibilityHidden(true)
            case .external:
                Image(systemName: "arrow.up.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Ink.textTertiary)
                    .accessibilityHidden(true)
            }
        }
        .frame(minHeight: Metric.row)
        .contentShape(Rectangle())
    }
}

/// 設定頁的開關列：圖示＋名稱＋開關
struct VeggieToggleRow: View {
    let icon: String
    let title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(spacing: Gap.s3) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Brand.theme.accent)
                .frame(width: Gap.s6)
                .accessibilityHidden(true)
            Toggle(title, isOn: $isOn)
                .font(Typo.body.font)
                .foregroundStyle(Ink.textPrimary)
                .tint(Brand.theme.accent)
        }
        .frame(minHeight: Metric.row)
    }
}
