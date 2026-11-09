import SwiftUI

/// 還沒收到鍵盤的資料時，教你打開「允許完全取用」。這是選用的：不開也能打字（審核指南 4.4.1），文案不能寫成必開
struct FullAccessCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("想讓豆鍵自動學詞？")
                .font(.headline)
            Text(Self.reason)
                .font(.subheadline)
            VStack(alignment: .leading, spacing: 4) {
                Text("1. 按下面的「前往設定」")
                Text("2. 點「鍵盤」")
                Text("3. 打開「允許完全取用」，跳出警告時按「允許」")
            }
            .font(.subheadline)
            Button {
                AppSettings.open()
            } label: {
                Text("前往設定")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 48)
                    .background(Palette.ink, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .padding(.top, 6)
        }
        .foregroundStyle(Palette.cardText)
        .padding(18)
        .background(Palette.cardBackground, in: RoundedRectangle(cornerRadius: 16))
    }

    private static let reason = "不開「允許完全取用」也能用豆鍵打字。"
        + "開了之後，你選出來的詞才會存進這裡，主題和剪貼簿也要開了才能用。"
        + "豆鍵沒有連網功能，字典只存在這支手機上。"
}
