import SwiftUI

/// 外觀三選一：跟隨系統（預設）／淺色／深色。只管 App 本身；鍵盤照舊跟著正在打字的那個 app
enum Appearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    static let storageKey = "appearance"

    var id: String {
        rawValue
    }

    var title: String {
        switch self {
        case .system: VeggieText.appearanceSystem
        case .light: VeggieText.appearanceLight
        case .dark: VeggieText.appearanceDark
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}
