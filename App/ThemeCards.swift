import SwiftUI
import UIKit

/// 主題頁上方的大預覽：整張注音鍵盤照這款主題畫出來，下面是名稱、說明和一顆按鈕（換成這款／買下這款）
struct ThemeHero: View {
    let theme: KeyboardTheme
    let dark: Bool
    let status: ThemeStatus
    /// 按下面那顆按鈕：擁有的換上、沒買的購買、價格沒載到的重試
    let action: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Gap.s4) {
            ThemeKeyboardPreview(theme: theme, dark: dark)
            HStack(spacing: Gap.s3) {
                VStack(alignment: .leading, spacing: Gap.s1 / 2) {
                    Text(theme.name)
                        .font(Font(theme.font(ofSize: Typo.title2.size) as CTFont))
                        .foregroundStyle(Ink.textPrimary)
                    Text(theme.summary)
                        .font(Typo.subheadline.font)
                        .foregroundStyle(Ink.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                if status == .inUse {
                    DomyPill(text: "使用中", icon: "checkmark")
                }
            }
            actionButton
        }
        .padding(Gap.s4)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.xxl))
        .domyShadow(DomyTokens.Elevation.level1)
    }

    @ViewBuilder private var actionButton: some View {
        switch status {
        case .inUse:
            EmptyView()
        case .owned:
            Button("換成這款") {
                action()
            }
            .buttonStyle(DomyButtonStyle(kind: .secondary))
        case let .price(price):
            VStack(spacing: Gap.s2) {
                Button("買下這款　\(price)") {
                    action()
                }
                .buttonStyle(DomyButtonStyle())
                Text("買一次永久有。")
                    .font(Typo.footnote.font)
                    .foregroundStyle(Ink.textSecondary)
            }
        case .loading:
            ProgressView()
                .frame(maxWidth: .infinity, minHeight: Metric.button)
                .accessibilityLabel("價格載入中")
        case .unavailable:
            Button {
                action()
            } label: {
                Label("價格沒載入，點一下重試", systemImage: "arrow.clockwise")
            }
            .buttonStyle(DomyButtonStyle(kind: .secondary))
        }
    }
}

/// 主題卡：小縮圖、名稱（用這款主題的字體）、說明、狀態（使用中／已擁有／價格）
struct ThemeCard: View {
    let theme: KeyboardTheme
    let dark: Bool
    let status: ThemeStatus
    /// 上面的大預覽正在看這款：加產品色外框
    let previewing: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: Gap.s2) {
            ThemePreview(colors: dark ? theme.dark : theme.light, dark: dark)
            Text(theme.name)
                .font(Font(theme.font(ofSize: Typo.headline.size + 1) as CTFont))
                .foregroundStyle(Ink.textPrimary)
                .padding(.horizontal, Gap.s1)
            Text(theme.summary)
                .font(Typo.footnote.font)
                .foregroundStyle(Ink.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, Gap.s1)
            Spacer(minLength: 0)
            pill
                .padding(.horizontal, Gap.s1)
                .padding(.bottom, Gap.s1)
        }
        .padding(Gap.s2 + Gap.s1 / 2)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(previewing ? Brand.theme.accent : Color.clear, lineWidth: Metric.hairline * 2)
        }
        .contentShape(RoundedRectangle(cornerRadius: Corner.xl))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder private var pill: some View {
        switch status {
        case .inUse:
            DomyPill(text: "使用中", icon: "checkmark", tone: .solid)
        case .owned:
            DomyPill(text: "已擁有", tone: .muted)
        case let .price(price):
            DomyPill(text: price)
                .accessibilityLabel("要購買，\(price)")
        case .loading:
            ProgressView()
                .accessibilityLabel("價格載入中")
        case .unavailable:
            DomyPill(text: "價格沒載入", tone: .muted)
        }
    }
}

/// 主題的小縮圖：注音鍵盤其中三排，每顆鍵一個色塊（k 字鍵、t 聲調、m 介音、f 韻母、x 功能鍵、- 半顆空位）
struct ThemePreview: View {
    let colors: KeyboardTheme.Colors
    let dark: Bool

    private static let rows = ["kkttkttffff", "-kkkkkkmfff-", "kkkkkkmfffx"]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, zone in
                        chip(zone)
                    }
                }
            }
        }
        .padding(.vertical, Gap.s2)
        .padding(.horizontal, Gap.s1 + Gap.s1 / 2)
        .frame(maxWidth: .infinity)
        // 系統畫在鍵盤底下的底色（淺色約 #E2E3E7）
        .background(
            Color(uiColor: KeyboardTheme.color(dark ? 0x2C2C2E : 0xE2E3E7)),
            in: RoundedRectangle(cornerRadius: Corner.md)
        )
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func chip(_ zone: Character) -> some View {
        if zone == "-" {
            Color.clear.frame(width: 3, height: 14)
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(uiColor: KeyboardTheme.color(hex(zone))))
                .frame(height: 14)
        }
    }

    private func hex(_ zone: Character) -> Int {
        switch zone {
        case "t": colors.tone
        case "m": colors.medial
        case "f": colors.finals
        case "x": colors.function
        default: colors.key
        }
    }
}
