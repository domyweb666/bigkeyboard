import SwiftUI

/// 設定：空白鍵按下去是當一聲，還是直接選第一個候選
struct SettingsView: View {
    @AppStorage(SpaceKeySetting.storageKey, store: SpaceKeySetting.defaults)
    private var spaceSelectsFirstCandidate = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Toggle("空白鍵直接選第一個字", isOn: $spaceSelectsFirstCandidate)
                } header: {
                    Text("空白鍵")
                } footer: {
                    Text(spaceFooter)
                }
            }
            .navigationTitle("設定")
        }
    }

    private var spaceFooter: String {
        let behavior = spaceSelectsFirstCandidate
            ? "打 ㄉㄧ 按空白，直接送出候選列第一個字。"
            : "打 ㄉㄧ 按空白，先定成一聲，候選只剩 低、滴 這些一聲字，再按一下空白送出。打了聲調的音，按一下空白就送出。"
        return behavior + "\n要打開「允許完全取用」，鍵盤才讀得到這個設定；沒打開時空白鍵是當一聲。"
    }
}
