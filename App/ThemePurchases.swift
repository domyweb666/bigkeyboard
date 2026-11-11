import StoreKit

/// 主題內購（非消耗性：買一次永久有，換手機用「回復購買」拿回來）。
/// 只有 App 會用；鍵盤不碰購買，只讀 App 存好的目前主題
enum ThemePurchases {
    enum Outcome {
        case purchased
        case cancelled
        case pending
        case failed
    }

    /// 跟 Apple 拿主題商品（價格照使用者所在地區），以產品 ID 為 key。
    /// StoreKit 有時一直不回（審核的 iPad 就遇過，畫面轉圈轉不停）：每次最多等 10 秒，沒拿到再試一次。
    /// 兩次都沒拿到（沒網路、卡住、商品還沒建好）回傳 nil，讓畫面改顯示「重試」
    static func products() async -> [String: Product]? {
        let ids = KeyboardTheme.allCases.compactMap(\.productID)
        for _ in 0 ..< 2 {
            let fetched = await withTimeout(seconds: 10) { try? await Product.products(for: ids) }
            if let fetched, let list = fetched, !list.isEmpty {
                return Dictionary(list.map { ($0.id, $0) }) { first, _ in first }
            }
        }
        return nil
    }

    /// 目前擁有的付費主題產品 ID（退款的不算）。讀手機上 Apple 存的購買紀錄。
    /// 最多等 10 秒，沒讀完回傳 nil：呼叫的人要當成「不知道」，不能當成「一款都沒買」
    static func owned() async -> Set<String>? {
        await withTimeout(seconds: 10) {
            var ids: Set<String> = []
            for await result in Transaction.currentEntitlements {
                if case let .verified(transaction) = result, transaction.revocationDate == nil {
                    ids.insert(transaction.productID)
                }
            }
            return ids
        }
    }

    static func buy(_ product: Product) async -> Outcome {
        guard let result = try? await product.purchase() else { return .failed }
        switch result {
        case let .success(.verified(transaction)):
            await transaction.finish()
            return .purchased
        case .success(.unverified):
            return .failed
        case .pending:
            return .pending
        case .userCancelled:
            return .cancelled
        @unknown default:
            return .failed
        }
    }

    /// 回復購買：請 Apple 重新同步這個帳號的購買紀錄（可能會要使用者登入，所以同步本身不設時限）。失敗回傳 nil
    static func restore() async -> Set<String>? {
        guard await (try? AppStore.sync()) != nil else { return nil }
        return await owned()
    }

    /// 選中的主題已經不擁有（退款、換了 Apple 帳號）就換回冷灰
    static func checkSavedTheme(owned: Set<String>) {
        if let id = KeyboardTheme.saved.productID, !owned.contains(id) {
            KeyboardTheme.gray.save()
        }
    }

    /// 不是在主題頁按出來的購買（等家長同意、在別台裝置買）會從這裡進來：收下並結束交易
    static func listenForUpdates() {
        Task.detached {
            for await result in Transaction.updates {
                if case let .verified(transaction) = result {
                    await transaction.finish()
                }
            }
        }
    }

    /// 最多等幾秒，逾時回傳 nil。StoreKit 不理會取消，不能用 task group（group 結束前會等它跑完，等於沒設時限）；
    /// 改成兩個各自跑的工作搶著回覆，先到的算數，晚到的丟掉
    private static func withTimeout<T>(seconds: Double, _ work: @escaping () async -> T) async -> T? {
        await withCheckedContinuation { continuation in
            let reply = ReplyOnce(continuation)
            Task { await reply.send(work()) }
            Task {
                try? await Task.sleep(for: .seconds(seconds))
                reply.send(nil)
            }
        }
    }
}

/// 只讓第一個回覆送出去，第二個直接丟掉（continuation 回覆兩次會閃退）
private final class ReplyOnce<T>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<T?, Never>?

    init(_ continuation: CheckedContinuation<T?, Never>) {
        self.continuation = continuation
    }

    func send(_ value: T?) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(returning: value)
    }
}
