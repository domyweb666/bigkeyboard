import SwiftUI

/// 還沒收到鍵盤的資料時，教你打開「允許完全取用」。這是選用的：不開也能打字（審核指南 4.4.1），文案不能寫成必開
struct FullAccessCard: View {
    private static let steps = [
        "按下面的「前往設定」",
        "點「鍵盤」",
        "打開「允許完全取用」，跳出警告時按「允許」",
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: Gap.s4) {
            VStack(alignment: .leading, spacing: Gap.s2) {
                DomyPill(text: "選用")
                Text("想讓豆鍵自動學詞？")
                    .font(Typo.title3.font)
                    .foregroundStyle(Ink.textPrimary)
                Text(Self.reason)
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Ink.textPrimary)
            }
            VStack(alignment: .leading, spacing: Gap.s2) {
                ForEach(Array(Self.steps.enumerated()), id: \.offset) { i, step in
                    HStack(alignment: .firstTextBaseline, spacing: Gap.s3) {
                        Text("\(i + 1)")
                            .font(Typo.footnote.font.weight(.bold))
                            .foregroundStyle(Brand.theme.strong)
                            .frame(width: Gap.s6, height: Gap.s6)
                            .background(Ink.surface, in: Circle())
                        Text(step)
                            .font(Typo.subheadline.font)
                            .foregroundStyle(Ink.textPrimary)
                    }
                }
            }
            Button("前往設定") {
                AppSettings.open()
            }
            .buttonStyle(DomyButtonStyle())
        }
        .padding(Gap.s5)
        .background(Brand.theme.tint, in: RoundedRectangle(cornerRadius: Corner.xl))
        .overlay {
            RoundedRectangle(cornerRadius: Corner.xl)
                .stroke(Brand.theme.soft, lineWidth: Metric.hairline)
        }
    }

    private static let reason = "不開「允許完全取用」也能用豆鍵打字。"
        + "開了之後，你選出來的詞才會存進這裡，主題和剪貼簿也要開了才能用。"
        + "豆鍵預設不連網，字典只存在這支手機上；在設定打開 iCloud 同步，才會存到你自己的 iCloud。"
}
