import SwiftUI

/// 使用說明：加入鍵盤、讓豆鍵自動學詞、收鍵盤。
/// 從設定頁「支援 → 使用說明」點進來（GuidePage 包外框和標題），自己不捲動
struct GuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Gap.s6) {
            startCard
            DomySection("空白鍵") {
                paragraph(Self.spaceDetail)
                DomyDivider()
                paragraph("想要空白鍵直接送出第一個候選字，到設定頁打開「空白鍵直接選第一個字」。")
                DomyDivider()
                note("要打開「允許完全取用」，鍵盤才讀得到這個設定；沒打開時空白鍵是當一聲。")
            }
            DomySection("照你的寫法排候選") {
                paragraph("豆鍵會看游標前面的一兩個字，把你平常接在它後面打的字詞排在候選和聯想的最前面。")
                DomyDivider()
                note("只記「前面一兩個字 → 你打了什麼」，整段文字不會存下來。")
            }
            DomySection("收起鍵盤") {
                iconRow("keyboard.chevron.compact.down", title: "注音鍵盤", detail: "點候選列最右邊那顆鍵盤圖示。")
                DomyDivider()
                iconRow("return", title: "英文、符號、數字鍵盤", detail: "按住換行鍵（鍵上有個小 ⌄）。")
            }
            DomySection("表情符號") {
                iconRow("globe", title: "按住左下角的地球鍵", detail: Self.emojiDetail)
            }
            DomySection("iCloud 同步與備份") {
                paragraph(Self.iCloudDetail)
                DomyDivider()
                paragraph(Self.offlineDetail)
                DomyDivider()
                paragraph(Self.backupDetail)
            }
            privacy
        }
    }

    /// 開始用的三步。第三步（完全取用）是選用的：不開也能打字（審核指南 4.4.1），文案不能寫成必開
    private var startCard: some View {
        VStack(alignment: .leading, spacing: Gap.s4) {
            Text("開始用豆鍵")
                .font(Typo.title2.font)
                .foregroundStyle(Ink.textPrimary)
                .accessibilityAddTraits(.isHeader)
            step(1, title: "加入鍵盤", detail: "按下面的「前往設定」→ 點「鍵盤」→ 打開「豆鍵」")
            step(2, title: "切到豆鍵", detail: Self.switchDetail)
            step(3, title: "讓豆鍵自動學詞", detail: Self.fullAccessDetail, optional: true)
            Button("前往設定") {
                AppSettings.open()
            }
            .buttonStyle(DomyButtonStyle())
        }
        .padding(Gap.s5)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.xxl))
        .domyShadow(DomyTokens.Elevation.level1)
    }

    private static let spaceDetail = "打 ㄉㄧ 按空白，會先定成一聲，候選只剩 低、滴 這些一聲字，再按一下空白送出。"
        + "打了聲調的音，按一下空白就送出。"

    private static let iCloudDetail = "在設定頁打開「iCloud 同步」，"
        + "字典裡的詞（自動學到的、自己加的）會存到你自己的 iCloud，"
        + "同一個 Apple ID 的其他 iPhone 打開豆鍵 App 就會合併過去。剪貼簿和打字紀錄不會上傳。"

    private static let offlineDetail = "鍵盤本身不連網，鍵盤學到的新詞，要打開豆鍵 App 才會同步。"
        + "手機沒登入 iCloud 時，字典照常存在手機上。"

    private static let backupDetail = "「匯出資料」會把整本字典（不含剪貼簿）存成一個檔案，可以放到「檔案」裡，"
        + "換手機時再用「匯入資料」放回來。"

    private static let switchDetail = "打字時按左下角的地球鍵。"
        + "加入鍵盤後就能打注音、選候選字和聯想詞，也能切英文、符號、數字鍵盤。"

    private static let fullAccessDetail = "「允許完全取用」可以不開。"
        + "打開之後，豆鍵才能把你選出來的詞存進字典，也才換得了主題、存得了剪貼簿。"

    private static let emojiDetail = "選「表情符號」，就是 iPhone 原本的表情鍵盤（可以搜尋、選膚色）。"
        + "選完按地球鍵就回到豆鍵。"

    /// 一步：圓圈數字、標題、說明。選用的那步圓圈是空心的，標題旁邊多一顆「選用」
    private func step(_ number: Int, title: String, detail: String, optional: Bool = false) -> some View {
        HStack(alignment: .top, spacing: Gap.s3) {
            Text("\(number)")
                .font(Typo.subheadline.font.weight(.bold))
                .foregroundStyle(optional ? Brand.theme.strong : Brand.theme.onAccent)
                .frame(width: Gap.s8 - Gap.s1 / 2, height: Gap.s8 - Gap.s1 / 2)
                .background(optional ? Brand.theme.soft : Brand.theme.accent, in: Circle())
            VStack(alignment: .leading, spacing: Gap.s1) {
                HStack(spacing: Gap.s2) {
                    Text(title)
                        .font(Typo.headline.font)
                        .foregroundStyle(Ink.textPrimary)
                    if optional {
                        DomyPill(text: "選用")
                    }
                }
                Text(detail)
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Ink.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    /// 卡片裡的一段正文
    private func paragraph(_ text: String) -> some View {
        Text(text)
            .font(Typo.body.font)
            .foregroundStyle(Ink.textPrimary)
            .padding(.vertical, Gap.s3)
    }

    /// 卡片裡的一段灰色補充
    private func note(_ text: String) -> some View {
        Text(text)
            .font(Typo.subheadline.font)
            .foregroundStyle(Ink.textSecondary)
            .padding(.vertical, Gap.s3)
    }

    /// 左邊一顆鍵的圖示，右邊標題和說明
    private func iconRow(_ icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Gap.s3) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Ink.textPrimary)
                .frame(width: Metric.touch, height: Metric.touch)
                .background(Ink.surfaceMuted, in: RoundedRectangle(cornerRadius: Corner.sm))
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Gap.s1 / 2) {
                Text(title)
                    .font(Typo.headline.font)
                    .foregroundStyle(Ink.textPrimary)
                Text(detail)
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Ink.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.vertical, Gap.s3)
    }

    private var privacy: some View {
        VStack(alignment: .leading, spacing: Gap.s2) {
            Text("隱私")
                .font(Typo.title3.font)
                .foregroundStyle(Ink.textPrimary)
                .padding(.horizontal, Gap.s1)
                .accessibilityAddTraits(.isHeader)
            HStack(spacing: Gap.s3) {
                Image(systemName: "lock")
                    .foregroundStyle(Brand.theme.accent)
                    .accessibilityHidden(true)
                Text("豆鍵預設不連網，字典只存在這支手機上。在設定頁打開「iCloud 同步」，字典才會存到你自己的 iCloud。")
                    .foregroundStyle(Brand.theme.strong)
            }
            .font(Typo.body.font)
            .padding(.horizontal, Gap.s4)
            .padding(.vertical, Gap.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.theme.tint, in: RoundedRectangle(cornerRadius: Corner.xl))
            .overlay {
                RoundedRectangle(cornerRadius: Corner.xl)
                    .stroke(Brand.theme.soft, lineWidth: Metric.hairline)
            }
        }
    }
}
