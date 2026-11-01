import SwiftUI

/// App 用到的幾個顏色（字色都在對應的底色上算過對比）
enum Palette {
    /// 自動學詞的標記色
    static let teal = Color(red: 0.06, green: 0.61, blue: 0.54)
    /// 「自動學習中」那條的字與底
    static let statusText = Color(red: 0.11, green: 0.36, blue: 0.33)
    static let statusBackground = Color(red: 0.92, green: 0.97, blue: 0.96)
    /// 開完全取用提醒卡的字與底
    static let cardText = Color(red: 0.36, green: 0.24, blue: 0)
    static let cardBackground = Color(red: 1, green: 0.965, blue: 0.898)
    /// 提醒卡上的黑色按鈕
    static let ink = Color(white: 0.11)
    /// 查不到讀音的警示字
    static let danger = Color(red: 0.75, green: 0.1, blue: 0.1)
}
