import SwiftUI

struct ContentView: View {
    @State private var tab = AppTab.dictionary

    var body: some View {
        // 系統的分頁列藏起來，換成 Domy 的懸浮膠囊分頁列（疊在最上層）
        TabView(selection: $tab) {
            DictionaryView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.dictionary)
            ClipboardView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.clipboard)
            ThemeView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.themes)
            SettingsView()
                .toolbar(.hidden, for: .tabBar)
                .tag(AppTab.settings)
        }
        .overlay {
            VStack {
                Spacer()
                DomyTabBar(selection: $tab)
                    .padding(.bottom, Metric.tabBarBottom)
            }
            // 鍵盤叫出來時分頁列留在原位，不跟著被推到鍵盤上面
            .ignoresSafeArea(.keyboard, edges: .bottom)
        }
        .tint(Brand.theme.strong)
    }
}
