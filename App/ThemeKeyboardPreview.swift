import SwiftUI
import UIKit

/// 大預覽裡的一顆鍵
private struct PreviewKey {
    var label = ""
    /// SF Symbol 名稱；有的話畫圖示不畫字
    var icon: String?
    /// k 字鍵、t 聲調、m 介音、f 韻母、x 功能鍵
    var zone: Character = "k"
    /// 相對寬度，1 = 一般鍵
    var width: CGFloat = 1
}

/// 主題頁的大預覽：整張注音鍵面照這款主題的配色、字體、圓角畫出來（只給人看，不能按）。
/// 鍵位跟鍵盤擴充的 BopomofoLayout 一樣；那份在擴充裡，App 讀不到，所以這裡另外寫一份只有字的
struct ThemeKeyboardPreview: View {
    let theme: KeyboardTheme
    let dark: Bool

    private static let keyHeight: CGFloat = 34
    private static let gap: CGFloat = 3
    private static let rowGap: CGFloat = 5

    private static let rows: [[PreviewKey]] = [
        zhuyin("ㄅㄉˇˋㄓˊ˙ㄚㄞㄢㄦ"),
        zhuyin("ㄆㄊㄍㄐㄔㄗㄧㄛㄟㄣ"),
        zhuyin("ㄇㄋㄎㄑㄕㄘㄨㄜㄠㄤ"),
        zhuyin("ㄈㄌㄏㄒㄖㄙㄩㄝㄡㄥ") + [PreviewKey(icon: "delete.left", zone: "x")],
        [
            PreviewKey(label: "符", zone: "x", width: 1.3),
            PreviewKey(label: "ABC", zone: "x", width: 1.3),
            PreviewKey(label: "，"),
            PreviewKey(label: "注音", width: 4.3),
            PreviewKey(label: "。"),
            PreviewKey(icon: "return", zone: "x", width: 1.6),
        ],
    ]

    private static func zhuyin(_ symbols: String) -> [PreviewKey] {
        symbols.map { PreviewKey(label: String($0), zone: zone(of: $0)) }
    }

    private static func zone(of symbol: Character) -> Character {
        if "ˇˋˊ˙".contains(symbol) {
            return "t"
        }
        if "ㄧㄨㄩ".contains(symbol) {
            return "m"
        }
        return "ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ".contains(symbol) ? "f" : "k"
    }

    var body: some View {
        GeometryReader { geo in
            VStack(spacing: Self.rowGap) {
                ForEach(Array(Self.rows.enumerated()), id: \.offset) { _, row in
                    HStack(spacing: Self.gap) {
                        ForEach(Array(row.enumerated()), id: \.offset) { _, key in
                            cap(key)
                                .frame(width: width(of: key, in: row, total: geo.size.width), height: Self.keyHeight)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
        }
        .frame(height: Self.keyHeight * 5 + Self.rowGap * 4)
        .padding(.vertical, Gap.s2)
        .padding(.horizontal, Gap.s1)
        // 系統畫在鍵盤底下的底色（淺色約 #E2E3E7）
        .background(
            Color(uiColor: KeyboardTheme.color(dark ? 0x2C2C2E : 0xE2E3E7)),
            in: RoundedRectangle(cornerRadius: Corner.lg)
        )
        .accessibilityHidden(true)
    }

    private var colors: KeyboardTheme.Colors {
        dark ? theme.dark : theme.light
    }

    /// 第一排、第四排 11 顆和底排撐滿整排；第二、三排 10 顆用第一排的鍵寬，置中後左右各空半顆
    private func width(of key: PreviewKey, in row: [PreviewKey], total: CGFloat) -> CGFloat {
        let units = row.reduce(0) { $0 + $1.width }
        let unit = if units > 10 {
            (total - Self.gap * CGFloat(row.count - 1)) / units
        } else {
            (total - Self.gap * 10) / 11
        }
        return max(0, unit * key.width)
    }

    private func cap(_ key: PreviewKey) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: min(theme.cornerRadius, 10))
                .fill(Color(uiColor: KeyboardTheme.color(hex(key.zone))))
            if let icon = key.icon {
                Image(systemName: icon)
                    .font(.system(size: 13))
            } else {
                Text(key.label)
                    .font(Font(theme.font(ofSize: fontSize(key), bold: key.zone == "t") as CTFont))
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
            }
        }
        .foregroundStyle(Color(uiColor: KeyboardTheme.color(colors.text)))
    }

    /// 聲調放大（跟真鍵盤一樣）；兩個字以上的功能鍵縮小
    private func fontSize(_ key: PreviewKey) -> CGFloat {
        if key.zone == "t" {
            return 20
        }
        return key.label.count > 1 ? 11 : 16
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
