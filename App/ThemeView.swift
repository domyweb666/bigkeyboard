import StoreKit
import SwiftUI
import UIKit

/// 主題頁：選鍵盤的鍵帽配色、字體、圓角。冷灰免費，其他主題要先買（App 內購買，非消耗性）。
/// 選好後鍵盤下次叫出來就換上
struct ThemeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected = KeyboardTheme.saved
    /// 跟 Apple 拿到的商品（價格），以產品 ID 為 key
    @State private var products: [String: Product] = [:]
    /// 擁有的付費主題產品 ID
    @State private var owned: Set<String> = []
    @State private var loaded = false
    /// 購買、回復購買進行中：整頁先不能點
    @State private var busy = false
    @State private var message: String?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(KeyboardTheme.allCases) { theme in
                        Button {
                            Task { await tap(theme) }
                        } label: {
                            row(theme)
                        }
                        .foregroundStyle(.primary)
                    }
                } footer: {
                    Text("鍵盤正開著的話，收起來再叫出來就會換上。")
                }
                Section {
                    Button("前往設定") {
                        AppSettings.open()
                    }
                } footer: {
                    Text("要開「允許完全取用」，鍵盤才換得了主題；沒開時鍵盤一律用冷灰。")
                }
                Section {
                    Button("回復購買") {
                        Task { await restore() }
                    }
                } footer: {
                    Text("換手機或重裝 App 後，用這個把買過的主題拿回來。")
                }
            }
            .navigationTitle("主題")
            .disabled(busy)
            .alert(message ?? "", isPresented: messageShown) {
                Button("好") {}
            }
        }
        .task {
            await reload()
        }
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                Task { await reload() }
            }
        }
    }

    private var messageShown: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { shown in
                if !shown {
                    message = nil
                }
            }
        )
    }

    /// 價格放在說明下面：放右邊會把說明擠成一行三、四個字（字放大時更明顯）
    private func row(_ theme: KeyboardTheme) -> some View {
        HStack(alignment: .top, spacing: 12) {
            ThemePreview(colors: colorScheme == .dark ? theme.dark : theme.light, dark: colorScheme == .dark)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(theme.name)
                        .font(Font(theme.font(ofSize: 18) as CTFont))
                    Spacer(minLength: 0)
                    if isOwned(theme), theme == selected {
                        Image(systemName: "checkmark")
                            .fontWeight(.semibold)
                            .foregroundStyle(Palette.teal)
                            .accessibilityLabel("使用中")
                    }
                }
                Text(theme.summary)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                status(theme)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    /// 說明下面：沒買的顯示 Apple 給的價格；還在問價格時轉圈；買過的不顯示
    @ViewBuilder
    private func status(_ theme: KeyboardTheme) -> some View {
        if isOwned(theme) {
            EmptyView()
        } else if let id = theme.productID, let product = products[id] {
            Text(product.displayPrice)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Palette.statusText)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Palette.statusBackground, in: .capsule)
                .accessibilityLabel("購買，\(product.displayPrice)")
        } else if !loaded {
            ProgressView()
        } else {
            Text("暫時買不到")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func isOwned(_ theme: KeyboardTheme) -> Bool {
        theme.productID.map(owned.contains) ?? true
    }

    /// 擁有的就選用；沒買的跳出 Apple 的購買視窗，買到就直接選用
    private func tap(_ theme: KeyboardTheme) async {
        if isOwned(theme) {
            select(theme)
            return
        }
        guard let id = theme.productID, let product = products[id] else { return }
        busy = true
        let outcome = await ThemePurchases.buy(product)
        busy = false
        switch outcome {
        case .purchased:
            owned.insert(id)
            select(theme)
        case .pending:
            message = "購買等待確認中（例如等家長同意），確認後回到這頁就會解鎖。"
        case .failed:
            message = "購買沒有完成，請稍後再試。"
        case .cancelled:
            break
        }
    }

    private func select(_ theme: KeyboardTheme) {
        selected = theme
        theme.save()
    }

    /// 跟 Apple 對一次：價格、擁有哪些主題；選中的主題不再擁有就換回冷灰
    private func reload() async {
        async let freshProducts = ThemePurchases.products()
        async let freshOwned = ThemePurchases.owned()
        let fetched = await freshProducts
        // 這次沒拿到（沒網路）就留著上次的價格
        if !fetched.isEmpty {
            products = fetched
        }
        owned = await freshOwned
        loaded = true
        ThemePurchases.checkSavedTheme(owned: owned)
        selected = KeyboardTheme.saved
    }

    private func restore() async {
        busy = true
        let restored = await ThemePurchases.restore()
        busy = false
        guard let restored else {
            message = "回復失敗，請確認已登入 Apple 帳號後再試。"
            return
        }
        owned = restored
        message = restored.isEmpty ? "這個 Apple 帳號沒有買過主題。" : "已回復 \(restored.count) 款主題。"
    }
}

/// 主題的小縮圖：注音鍵盤其中三排，每顆鍵一個色塊（k 字鍵、t 聲調、m 介音、f 韻母、x 功能鍵、- 半顆空位）
private struct ThemePreview: View {
    let colors: KeyboardTheme.Colors
    let dark: Bool

    private static let rows = ["kkttkttffff", "-kkkkkkmfff-", "kkkkkkmfffx"]

    var body: some View {
        VStack(spacing: 3) {
            ForEach(Self.rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(Array(row.enumerated()), id: \.offset) { _, zone in
                        chip(zone)
                    }
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .frame(width: 132)
        // 系統畫在鍵盤底下的底色（淺色約 #E2E3E7）
        .background(Color(uiColor: KeyboardTheme.color(dark ? 0x2C2C2E : 0xE2E3E7)), in: .rect(cornerRadius: 10))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func chip(_ zone: Character) -> some View {
        if zone == "-" {
            Color.clear.frame(width: 3, height: 14)
        } else {
            RoundedRectangle(cornerRadius: 3)
                .fill(Color(uiColor: KeyboardTheme.color(hex(zone))))
                .frame(height: 14)
        }
    }

    private func hex(_ zone: Character) -> Int {
        switch zone {
        case "t": colors.tone
        case "m": colors.medial
        case "f": colors.finals
        case "x": colors.function
        default: colors.key
        }
    }
}
