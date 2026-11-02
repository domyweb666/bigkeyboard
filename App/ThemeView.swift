import SwiftUI
import UIKit

/// 主題頁：選鍵盤的鍵帽配色、字體、圓角。選好後鍵盤下次叫出來就換上
struct ThemeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @State private var selected = KeyboardTheme.saved

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(KeyboardTheme.allCases) { theme in
                        Button {
                            selected = theme
                            theme.save()
                        } label: {
                            row(theme)
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("鍵盤正開著的話，收起來再叫出來就會換上。")
                }
            }
            .navigationTitle("主題")
        }
    }

    private func row(_ theme: KeyboardTheme) -> some View {
        HStack(spacing: 12) {
            ThemePreview(colors: colorScheme == .dark ? theme.dark : theme.light, dark: colorScheme == .dark)
            VStack(alignment: .leading, spacing: 2) {
                Text(theme.name)
                    .font(Font(theme.font(ofSize: 18) as CTFont))
                Text(theme.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
            if theme == selected {
                Image(systemName: "checkmark")
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.teal)
                    .accessibilityLabel("使用中")
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

/// 主題的小縮圖：注音鍵盤其中三排，每顆鍵一個色塊（k 字鍵、t 聲調、m 介音、f 韻母、x 功能鍵、- 半顆空位）
private struct ThemePreview: View {
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
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(width: 132)
        // 系統畫在鍵盤底下的底色（淺色約 #E2E3E7）
        .background(Color(uiColor: KeyboardTheme.color(dark ? 0x2C2C2E : 0xE2E3E7)), in: .rect(cornerRadius: 10))
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
