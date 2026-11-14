import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DictionaryView()
                .tabItem {
                    Label("字典", systemImage: "book")
                }
            ClipboardView()
                .tabItem {
                    Label("剪貼簿", systemImage: "doc.on.clipboard")
                }
            ThemeView()
                .tabItem {
                    Label("主題", systemImage: "paintpalette")
                }
            SettingsView()
                .tabItem {
                    Label("設定", systemImage: "gearshape")
                }
            GuideView()
                .tabItem {
                    Label("使用說明", systemImage: "questionmark.circle")
                }
        }
    }
}
