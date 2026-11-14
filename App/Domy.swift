import SwiftUI

/// 豆鍵的產品色：Domy 設計系統的鼠尾草綠（毛豆綠）
enum Brand {
    static let theme = DomyTheme.sage
}

// Domy 代號的短名。數值全在 Design/DomyTokens.swift（從 domy-design 的 tokens.json 產生），
// 畫面不寫死色碼、字級、間距、圓角

typealias Gap = DomyTokens.Space
typealias Corner = DomyTokens.Radius
typealias Metric = DomyTokens.Size
typealias Ink = DomyTokens.Neutral
typealias Typo = DomyTokens.TypeScale

extension View {
    /// Domy 的陰影（level1：卡片、圓鈕；level2：懸浮分頁列、＋按鈕）
    func domyShadow(_ level: DomyShadow) -> some View {
        shadow(color: Ink.shadow.opacity(level.opacity), radius: level.radius, y: level.y)
    }

    /// 有懸浮分頁列的畫面：捲動內容底部留空，最後一筆才不會被分頁列蓋住
    func tabBarClearance() -> some View {
        safeAreaInset(edge: .bottom, spacing: 0) {
            Color.clear
                .frame(height: DomyTabBar.clearance)
        }
    }
}
