import SwiftUI

/// 使用說明：加入鍵盤、讓豆鍵自動學詞、收鍵盤。
/// 放在設定頁的下半段（2026-11-14 多米：說明併進設定，分頁剩四格），自己不捲動、沒有畫面外框
struct GuideView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Gap.s6) {
            Text("使用說明")
                .font(Typo.title1.font)
                .foregroundStyle(Ink.textPrimary)
                .accessibilityAddTraits(.isHeader)
            startCard
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
            privacy
            review
        }
    }

    /// 開始用的三步。第三步（完全取用）是選用的：不開也能打字（審核指南 4.4.1），文案不能寫成必開
    private var startCard: some View {
        VStack(alignment: .leading, spacing: Gap.s4) {
            Text("開始用豆鍵")
                .font(Typo.title2.font)
                .foregroundStyle(Ink.textPrimary)
                .accessibilityAddTraits(.isHeader)
            step(1, title: "加入鍵盤", detail: "設定 → 一般 → 鍵盤 → 鍵盤 → 新增鍵盤 → 豆鍵")
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
                Text("豆鍵預設不連網，字典只存在這支手機上。打開上面的「用 iCloud 同步字典」，字典才會存到你自己的 iCloud。")
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

    @ViewBuilder private var review: some View {
        if let url = ReviewPrompt.writeReviewURL {
            DomySection("喜歡豆鍵的話") {
                Link(destination: url) {
                    HStack {
                        Text("到 App Store 寫評論")
                            .foregroundStyle(Brand.theme.strong)
                        Spacer()
                        Image(systemName: "arrow.up.right")
                            .foregroundStyle(Ink.textTertiary)
                            .accessibilityHidden(true)
                    }
                    .font(Typo.body.font)
                    .frame(minHeight: Metric.row)
                }
            }
        }
    }
}
