import SwiftUI

/// 設定：空白鍵按下去是當一聲還是直接選第一個候選、字典要不要 iCloud 同步。下半段接使用說明（GuideView）
struct SettingsView: View {
    @AppStorage(SpaceKeySetting.storageKey, store: SpaceKeySetting.defaults)
    private var spaceSelectsFirstCandidate = false
    @AppStorage(DictionarySync.enabledKey) private var iCloudSync = false
    /// 剛關掉同步：問要不要一起刪掉 iCloud 上那份
    @State private var askDeleteCloud = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Gap.s6) {
                DomyTitle("設定")
                DomySection("空白鍵", footer: spaceFooter) {
                    Toggle("空白鍵直接選第一個字", isOn: $spaceSelectsFirstCandidate)
                        .font(Typo.body.font)
                        .foregroundStyle(Ink.textPrimary)
                        .tint(Brand.theme.accent)
                        .frame(minHeight: Metric.row)
                }
                DomySection("iCloud 同步", footer: Self.iCloudFooter) {
                    Toggle("用 iCloud 同步字典", isOn: $iCloudSync)
                        .font(Typo.body.font)
                        .foregroundStyle(Ink.textPrimary)
                        .tint(Brand.theme.accent)
                        .frame(minHeight: Metric.row)
                }
                GuideView()
                    .padding(.top, Gap.s2)
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Gap.s2)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
        .onChange(of: iCloudSync) {
            if iCloudSync {
                DictionarySync.sync()
            } else {
                askDeleteCloud = true
            }
        }
        .confirmationDialog("iCloud 上的字典要一起刪掉嗎？", isPresented: $askDeleteCloud, titleVisibility: .visible) {
            Button("刪掉 iCloud 上的字典", role: .destructive) {
                DictionarySync.deleteCloudCopy()
            }
            Button("留著", role: .cancel) {}
        } message: {
            Text("手機裡的字典不會動。留著的話，之後再打開同步會接著用。")
        }
    }

    private static let iCloudFooter = "打開後，字典裡的詞（自動學到的、自己加的）會存到你自己的 iCloud，"
        + "同一個 Apple ID 的其他 iPhone 打開豆鍵 App 就會合併過去。"
        + "剪貼簿和打字紀錄不會上傳。\n"
        + "鍵盤本身不連網：鍵盤學到的新詞，要打開豆鍵 App 才會同步。"
        + "手機沒登入 iCloud 時，字典照常存在手機上。"

    private var spaceFooter: String {
        let behavior = spaceSelectsFirstCandidate
            ? "打 ㄉㄧ 按空白，直接送出候選列第一個字。"
            : "打 ㄉㄧ 按空白，先定成一聲，候選只剩 低、滴 這些一聲字，再按一下空白送出。"
            + "打了聲調的音，按一下空白就送出。"
        return behavior + "\n要打開「允許完全取用」，鍵盤才讀得到這個設定；沒打開時空白鍵是當一聲。"
    }
}
