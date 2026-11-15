import StoreKit
import SwiftUI

/// 一款主題在主題頁上的狀態
enum ThemeStatus: Equatable {
    /// 擁有，而且鍵盤正在用
    case inUse
    /// 擁有，沒在用
    case owned
    /// 沒買，Apple 給的價格
    case price(String)
    /// 沒買，還在跟 Apple 問價格
    case loading
    /// 沒買，價格沒載到（逾時、沒網路）
    case unavailable
}

/// 主題頁：選鍵盤的鍵帽配色、字體、圓角。冷灰免費，其他主題要先買（App 內購買，非消耗性）。
/// 點主題卡只換上面的大預覽，看完再按預覽下面的按鈕換上或購買。選好後鍵盤下次叫出來就換上
struct ThemeView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @State private var selected = KeyboardTheme.saved
    /// 上面大預覽正在看的那款
    @State private var previewing = KeyboardTheme.saved
    /// 跟 Apple 拿到的商品（價格），以產品 ID 為 key
    @State private var products: [String: Product] = [:]
    /// 擁有的付費主題產品 ID
    @State private var owned: Set<String> = []
    /// 價格載入中：轉圈。載不到（逾時、沒網路）改顯示「點一下重試」，不能讓人看著一直轉
    @State private var loading = true
    /// 購買、回復購買進行中：整頁先不能點
    @State private var busy = false
    @State private var reloading = false
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Gap.s5) {
                DomyTitle("主題")
                ThemeHero(theme: previewing, dark: dark, status: status(previewing)) {
                    Task { await tap(previewing) }
                }
                grid
                Text("鍵盤正開著的話，收起來再叫出來就會換上。")
                    .font(Typo.footnote.font)
                    .foregroundStyle(Ink.textSecondary)
                    .padding(.horizontal, Gap.s1)
                DomySection(footer: "要開「允許完全取用」，鍵盤才換得了主題；沒開時鍵盤一律用冷灰。") {
                    Button {
                        AppSettings.open()
                    } label: {
                        HStack {
                            Text("前往設定")
                                .foregroundStyle(Ink.textPrimary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(Ink.textTertiary)
                                .accessibilityHidden(true)
                        }
                        .font(Typo.body.font)
                        .frame(minHeight: Metric.row)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
                DomySection(footer: "換手機或重裝 App 後，用這個把買過的主題拿回來。") {
                    Button {
                        Task { await restore() }
                    } label: {
                        Text("回復購買")
                            .font(Typo.body.font)
                            .foregroundStyle(Brand.theme.strong)
                            .frame(maxWidth: .infinity, minHeight: Metric.row, alignment: .leading)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, PageMetric.titleTop)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
        .disabled(busy)
        .alert(message ?? "", isPresented: messageShown) {
            Button("好") {}
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

    private var dark: Bool {
        colorScheme == .dark
    }

    /// 8 款主題排成兩欄，同一排的兩張卡一樣高
    private var grid: some View {
        Grid(horizontalSpacing: Gap.s2 + Gap.s1 / 2, verticalSpacing: Gap.s2 + Gap.s1 / 2) {
            ForEach(Self.pairs, id: \.self) { pair in
                GridRow {
                    ForEach(pair) { theme in
                        Button {
                            previewing = theme
                        } label: {
                            ThemeCard(
                                theme: theme,
                                dark: dark,
                                status: status(theme),
                                previewing: theme == previewing
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(theme == previewing ? .isSelected : [])
                    }
                }
            }
        }
    }

    /// 主題兩個一組（一排兩張卡）
    private static let pairs: [[KeyboardTheme]] = {
        let all = KeyboardTheme.allCases
        return stride(from: 0, to: all.count, by: 2).map { Array(all[$0 ..< min($0 + 2, all.count)]) }
    }()

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

    private func status(_ theme: KeyboardTheme) -> ThemeStatus {
        if isOwned(theme) {
            return theme == selected ? .inUse : .owned
        }
        if let id = theme.productID, let product = products[id] {
            return .price(product.displayPrice)
        }
        return loading ? .loading : .unavailable
    }

    private func isOwned(_ theme: KeyboardTheme) -> Bool {
        theme.productID.map(owned.contains) ?? true
    }

    /// 預覽下面那顆按鈕：擁有的就換上；沒買的跳出 Apple 的購買視窗，買到就直接換上
    private func tap(_ theme: KeyboardTheme) async {
        if isOwned(theme) {
            select(theme)
            return
        }
        guard let id = theme.productID, let product = products[id] else {
            // 價格沒載入時點了就重新跟 Apple 要一次
            await reload()
            return
        }
        busy = true
        let outcome = await ThemePurchases.buy(product)
        busy = false
        switch outcome {
        case .purchased:
            owned.insert(id)
            select(theme)
            // 付款視窗剛關不接著跳評分視窗；新主題也還沒在鍵盤上看過
            ReviewPrompt.hold()
        case .pending:
            message = "購買等待確認中（例如等家長同意），確認後回到這頁就會解鎖。"
        case .failed:
            message = "購買沒有完成，請稍後再試。"
            ReviewPrompt.hold()
        case .cancelled:
            break
        }
    }

    private func select(_ theme: KeyboardTheme) {
        selected = theme
        theme.save()
    }

    /// 跟 Apple 對一次：價格、擁有哪些主題；選中的主題不再擁有就換回冷灰。
    /// 兩件同時問，都有時限：價格最久約 20 秒（試兩次）、購買紀錄最久約 10 秒，時間到一定停止轉圈
    private func reload() async {
        // 打開 App 時 .task 和回到前景會同時叫，正在載就不再疊一次
        guard !reloading else { return }
        reloading = true
        loading = true
        async let freshOwned = ThemePurchases.owned()
        // 這次沒拿到就留著上次的價格
        if let fetched = await ThemePurchases.products() {
            products = fetched
        }
        loading = false
        // 購買紀錄沒讀完是「不知道」，不是「沒買」：不能拿來把主題換回冷灰
        if let fresh = await freshOwned {
            owned = fresh
            ThemePurchases.checkSavedTheme(owned: fresh)
            selected = KeyboardTheme.saved
        }
        reloading = false
    }

    private func restore() async {
        busy = true
        let restored = await ThemePurchases.restore()
        busy = false
        guard let restored else {
            message = "回復失敗，請確認已登入 Apple 帳號後再試。"
            ReviewPrompt.hold()
            return
        }
        owned = restored
        message = restored.isEmpty ? "這個 Apple 帳號沒有買過主題。" : "已回復 \(restored.count) 款主題。"
    }
}
