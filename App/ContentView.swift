import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system
    @State private var tab = AppTab.dictionary
    /// 更新後第一次打開要跳的新功能卡片
    @State private var whatsNew = WhatsNew.pending

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
        .sheet(item: $whatsNew, onDismiss: WhatsNew.clearPending) { release in
            WhatsNewCard(release: release) { whatsNew = nil }
        }
        // 設定頁選的外觀，選完立刻生效
        .preferredColorScheme(appearance.colorScheme)
        // 回到前景：鍵盤這段時間學到的詞跟 iCloud 對一次（沒打開同步時不做事）
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                DictionarySync.sync()
            }
        }
    }
}
