import SwiftUI

/// 還沒收到鍵盤的資料時，教你打開「允許完全取用」
struct FullAccessCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("先開「允許完全取用」")
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

    private static let reason = "豆鍵要把學到的詞存進這裡，iOS 規定要開這個開關。"
        + "豆鍵沒有連網功能，字典只存在這支手機上。"
}
