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
    /// 沒網路、或 App Store Connect 的商品還沒建好時回傳空的
    static func products() async -> [String: Product] {
        let ids = KeyboardTheme.allCases.compactMap(\.productID)
        let list = await (try? Product.products(for: ids)) ?? []
        return Dictionary(uniqueKeysWithValues: list.map { ($0.id, $0) })
    }

    /// 目前擁有的付費主題產品 ID（退款的不算）。讀手機上 Apple 存的購買紀錄，不用連網
    static func owned() async -> Set<String> {
        var ids: Set<String> = []
        for await result in Transaction.currentEntitlements {
            if case let .verified(transaction) = result, transaction.revocationDate == nil {
                ids.insert(transaction.productID)
            }
        }
        return ids
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

    /// 回復購買：請 Apple 重新同步這個帳號的購買紀錄（可能會要使用者登入）。失敗回傳 nil
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
}
