import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            DictionaryView()
                .tabItem {
                    Label("字典", systemImage: "book")
                }
            ThemeView()
                .tabItem {
                    Label("主題", systemImage: "paintpalette")
                }
            GuideView()
                .tabItem {
                    Label("使用說明", systemImage: "questionmark.circle")
                }
        }
    }
}
