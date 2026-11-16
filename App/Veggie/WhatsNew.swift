import SwiftUI

/// 新功能：記住使用者上次看過的版本，更新後第一次打開跳一張卡片（最多 3 點、只有一個「好」）。
/// 小修正（1.1.0 → 1.1.1）不跳；第一次安裝不跳。設定頁「新功能」可以重看歷次紀錄
@MainActor
enum WhatsNew {
    struct Point: Identifiable {
        let icon: String
        let text: String

        var id: String {
            text
        }
    }

    struct Release: Identifiable {
        let version: String
        let points: [Point]

        var id: String {
            version
        }
    }

    /// 各版的新功能，新的在前。每版最多 3 點（這份是豆鍵自己的內容；搬成 VeggieKit 時改由設定檔帶入）
    static let releases = [
        Release(version: "1.2", points: [
            Point(
                icon: "arrow.left.and.right",
                text: "按住空白鍵可以移游標：按住半秒，鍵上的字淡掉之後左右拖。"
                    + "按住刪除鍵久一點，會一次刪好幾個字。"
            ),
            Point(
                icon: "hand.draw",
                text: "按錯了先別放開，滑到對的鍵再放開就好。"
                    + "按住「符」往上滑，可以直接滑到符號，打完還在注音。"
            ),
            Point(
                icon: "speaker.wave.2",
                text: "設定頁多了按鍵震動和按鍵聲。"
                    + "按鍵聲有三套機械鍵盤的聲音可以選，也可以關掉。"
            ),
        ]),
        Release(version: "1.1", points: [
            Point(
                icon: "space",
                text: "空白鍵可以當一聲：打 ㄉㄧ 按空白，候選只剩 低、滴 這些一聲字。"
                    + "不習慣的話，設定頁可以改回直接選字。"
            ),
            Point(
                icon: "icloud",
                text: "字典可以用 iCloud 同步，也能匯出成檔案備份。預設是關的，到設定頁打開。"
            ),
            Point(
                icon: "paintpalette",
                text: "換了新的外觀和圖示；英文鍵盤拿掉上面那排工具列，鍵變大了。"
            ),
        ]),
        Release(version: "1.0", points: [
            Point(icon: "keyboard", text: "第一版：字大、鍵緊、少按錯的注音鍵盤，8 款主題。"),
        ]),
    ]

    private static let lastSeenKey = "whatsNew.lastSeenVersion"
    /// 1.0 就有記的「第一次打開」日期：有它代表是從舊版更新上來的，不是新安裝
    private static let firstOpenKey = "review.firstOpen"

    /// 這次打開要跳的卡片（App 啟動時算一次）
    private(set) static var pending: Release?

    /// App 啟動時呼叫，要在 ReviewPrompt.recordLaunch() 之前（才分得出新安裝和更新）
    static func prepare() {
        let defaults = UserDefaults.standard
        let current = majorMinor(appVersion)
        let lastSeen = defaults.string(forKey: lastSeenKey)
        defer { defaults.set(current, forKey: lastSeenKey) }
        let updated = lastSeen.map { majorMinor($0) != current } ?? (defaults.object(forKey: firstOpenKey) != nil)
        guard updated, let release = releases.first(where: { $0.version == current }) else { return }
        pending = release
        // 剛打開就跳了卡片，這次不再請系統跳評分
        ReviewPrompt.hold()
    }

    static func clearPending() {
        pending = nil
    }

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    /// 「1.1.2」→「1.1」
    private static func majorMinor(_ version: String) -> String {
        version.split(separator: ".").prefix(2).joined(separator: ".")
    }
}

/// 更新後跳的那張卡片
struct WhatsNewCard: View {
    let release: WhatsNew.Release
    let onDone: () -> Void

    var body: some View {
        // 內容比半頁高時（字放大、三點都長）標題會被頂到拉桿後面：內容放進捲動區、從上往下排，按鈕固定在底下
        VStack(spacing: Gap.s4) {
            ScrollView {
                VStack(alignment: .leading, spacing: Gap.s5) {
                    Text("\(VeggieConfig.current.name) \(release.version) 新功能")
                        .font(Typo.title2.font)
                        .foregroundStyle(Ink.textPrimary)
                        .accessibilityAddTraits(.isHeader)
                    WhatsNewPoints(points: release.points)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, Gap.s8)
            }
            .scrollBounceBehavior(.basedOnSize)
            Button("好", action: onDone)
                .buttonStyle(DomyButtonStyle())
        }
        .padding(.horizontal, Gap.s6)
        .padding(.bottom, Gap.s6)
        .background(Brand.theme.canvas)
        .presentationDetents([.fraction(0.7), .large])
        .presentationDragIndicator(.visible)
    }
}

/// 設定頁「新功能」：歷次紀錄
struct WhatsNewHistoryView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Gap.s6) {
                ForEach(WhatsNew.releases) { release in
                    DomySection(release.version) {
                        WhatsNewPoints(points: release.points)
                            .padding(.vertical, Gap.s3)
                    }
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.vertical, Gap.s4)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
        .navigationTitle(VeggieText.whatsNew)
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 一版的幾點：圖示＋一句話
private struct WhatsNewPoints: View {
    let points: [WhatsNew.Point]

    var body: some View {
        VStack(alignment: .leading, spacing: Gap.s4) {
            ForEach(points) { point in
                HStack(alignment: .top, spacing: Gap.s3) {
                    Image(systemName: point.icon)
                        .font(.body)
                        .foregroundStyle(Brand.theme.accent)
                        .frame(width: Gap.s6)
                        .accessibilityHidden(true)
                    Text(point.text)
                        .font(Typo.body.font)
                        .foregroundStyle(Ink.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}
