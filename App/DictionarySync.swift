import Foundation

/// 字典 iCloud 同步（預設關）。只有 App 做，鍵盤不連網：
/// iCloud 鍵值儲存裡放一份壓縮過的字典（詞、刪除紀錄、不再學的詞），
/// App 打開、回到前景、字典頁改了詞、iCloud 傳來別支手機的更新時，跟手機裡的字典合併一次，兩邊寫成同一份。
/// 剪貼簿、接續紀錄、英文字次數不上傳。
@MainActor
enum DictionarySync {
    nonisolated static let enabledKey = "iCloudDictionarySync"
    /// 合併後手機裡的字典變了（字典頁要重讀）
    nonisolated static let didChangeLocal = Notification.Name("DictionarySync.didChangeLocal")

    private nonisolated static let cloudKey = "dictionary.v1"
    /// 鍵值儲存整個 App 上限 1MB，留一點餘裕
    private nonisolated static let maxBytes = 900_000
    /// 刪除紀錄只留最近的這麼多筆（太舊的刪除，兩支手機早就對齊了）
    nonisolated static let maxRemoved = 3000
    private nonisolated static var store: NSUbiquitousKeyValueStore {
        .default
    }

    /// App 這邊讀寫字典檔都排在這一條（背景、一次一件）：同步、字典頁改詞不卡畫面，也不會兩件同時讀改寫、互相蓋掉
    nonisolated static let fileQueue = DispatchQueue(label: "DictionarySync.file", qos: .userInitiated)

    private static var started = false

    nonisolated static var isEnabled: Bool {
        UserDefaults.standard.bool(forKey: enabledKey)
    }

    /// App 啟動時呼叫：開始聽 iCloud 傳來的更新，並先對一次
    static func start() {
        guard !started else { return }
        started = true
        NotificationCenter.default.addObserver(
            forName: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: NSUbiquitousKeyValueStore.default,
            queue: .main
        ) { _ in
            Task { @MainActor in sync() }
        }
        sync()
    }

    /// 跟 iCloud 對一次（排進 fileQueue，馬上回來）。沒打開同步時什麼都不做
    static func sync() {
        guard isEnabled else { return }
        fileQueue.async(execute: syncNow)
    }

    private nonisolated static func syncNow() {
        // 排隊的時候使用者可能剛關掉同步
        guard isEnabled else { return }
        store.synchronize()
        let remote = store.data(forKey: cloudKey).flatMap(decode) ?? Payload()
        var merged: Payload?
        var localChanged = false
        let written = UserDictionary.update { file in
            let local = Payload(file)
            let result = Payload.merge(local, remote, maxRemoved: maxRemoved)
            merged = result
            if result != local {
                result.apply(to: &file)
                localChanged = true
            }
        }
        // 手機裡的字典讀不懂或寫不進去：不上傳，免得把 iCloud 那份蓋成不完整的
        guard written, let merged else { return }
        if localChanged {
            // 字典頁收到就重讀、改畫面，要在主執行緒送
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: didChangeLocal, object: nil)
            }
        }
        guard merged != remote, let data = encodeFitting(merged) else { return }
        store.set(data, forKey: cloudKey)
        store.synchronize()
    }

    /// 關掉同步時使用者選了「一起刪掉」：把 iCloud 上那份拿掉（手機裡的字典不動）
    static func deleteCloudCopy() {
        // 排在還沒做完的同步後面，不然那次同步會把剛刪掉的再傳上去
        fileQueue.async {
            store.removeObject(forKey: cloudKey)
            store.synchronize()
        }
    }

    // MARK: - 存進 iCloud 的那份

    /// 只放要同步的欄位；詞照 id 排、不再學的詞排序，兩份內容一樣時比較起來就一樣
    struct Payload: Codable, Equatable {
        var words: [UserDictionary.Word] = []
        var removed: [String: Date] = [:]
        var ignored: [String] = []

        init() {}

        init(_ file: UserDictionary.File) {
            var byID: [String: UserDictionary.Word] = [:]
            for w in file.words {
                byID[w.id] = w
            }
            words = byID.values.sorted { $0.id < $1.id }
            removed = file.removed
            ignored = Set(file.ignored).sorted()
        }

        /// 合併兩份：同一個詞以最後更新的為準、次數取大的；
        /// 刪除比那個詞最後更新還晚才算數（算數就拿掉詞，不算數就拿掉刪除紀錄）
        static func merge(_ a: Payload, _ b: Payload, maxRemoved: Int) -> Payload {
            var byID: [String: UserDictionary.Word] = [:]
            for w in a.words + b.words {
                guard let old = byID[w.id] else {
                    byID[w.id] = w
                    continue
                }
                var pick = w.updated > old.updated ? w : old
                pick.count = max(w.count, old.count)
                byID[w.id] = pick
            }
            var removed = a.removed.merging(b.removed) { max($0, $1) }
            for (id, date) in removed {
                guard let w = byID[id] else { continue }
                if date >= w.updated {
                    byID[id] = nil
                } else {
                    removed[id] = nil
                }
            }
            if removed.count > maxRemoved {
                let keep = removed.sorted { $0.value > $1.value }.prefix(maxRemoved)
                removed = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
            }
            var out = Payload()
            out.words = byID.values.sorted { $0.id < $1.id }
            out.removed = removed
            // 手動加回來的詞不算「不再學」
            out.ignored = Set(a.ignored).union(b.ignored).filter { byID[$0]?.source != .manual }.sorted()
            return out
        }

        /// 寫回手機裡的字典：原本有的詞照原本的順序（鍵盤同讀音照這個順序排），新的接在後面
        func apply(to file: inout UserDictionary.File) {
            let byID = Dictionary(words.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
            var seen = Set<String>()
            var out: [UserDictionary.Word] = []
            for w in file.words {
                guard let merged = byID[w.id], seen.insert(w.id).inserted else { continue }
                out.append(merged)
            }
            for w in words where seen.insert(w.id).inserted {
                out.append(w)
            }
            file.words = out
            file.removed = removed
            file.ignored = ignored
        }
    }

    private nonisolated static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = .sortedKeys
        return e
    }()

    private nonisolated static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    private nonisolated static func decode(_ data: Data) -> Payload? {
        guard let raw = try? (data as NSData).decompressed(using: .lzfse) as Data else { return nil }
        return try? decoder.decode(Payload.self, from: raw)
    }

    /// 壓縮後超過上限：先丟最舊的刪除紀錄，再丟最久沒用的自動學詞（手動加的不丟），直到放得下
    private nonisolated static func encodeFitting(_ payload: Payload) -> Data? {
        var p = payload
        while true {
            guard let json = try? encoder.encode(p),
                  let data = try? (json as NSData).compressed(using: .lzfse) as Data else { return nil }
            if data.count <= maxBytes {
                return data
            }
            if p.removed.count > 100 {
                let keep = p.removed.sorted { $0.value > $1.value }.prefix(p.removed.count / 2)
                p.removed = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
                continue
            }
            let autos = p.words.filter { $0.source == .auto }.sorted { $0.updated < $1.updated }
            guard !autos.isEmpty else { return nil }
            let drop = Set(autos.prefix(max(autos.count / 10, 1)).map(\.id))
            p.words.removeAll { drop.contains($0.id) }
        }
    }
}
