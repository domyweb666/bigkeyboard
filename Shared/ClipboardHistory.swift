import Foundation

/// 剪貼簿紀錄：鍵盤在使用者按剪貼簿鍵時讀到的文字，存在 App Group 資料夾裡的 clipboard.json。
/// 只存在手機上、不上傳。寫法跟字典一樣：讀出、改、整份原子寫回（要開完全取用）。
enum ClipboardHistory {
    /// 沒釘選的最多留幾筆，超過刪最舊的；釘選的不算在內、不會被自動刪
    static let maxUnpinned = 50

    struct Entry: Codable, Equatable, Identifiable {
        var id: UUID
        var text: String
        var pinned: Bool
        /// 鍵盤讀到（或再次讀到）這段文字的時間，不是原本複製的時間
        var updated: Date
    }

    struct File: Codable {
        var entries: [Entry] = []
        /// 上次讀系統剪貼簿時的變更次數：沒變就不再讀內容（每讀一次系統都會跳「已貼上」提示）
        var changeCount: Int?
    }

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: UserDictionary.groupID)?
            .appendingPathComponent("clipboard.json")
    }

    /// 讀整份紀錄；還沒建立、讀不到或讀不懂時回傳空的
    static func load() -> File {
        guard let url = fileURL else { return File() }
        return read(url) ?? File()
    }

    /// 讀出、改、寫回，回傳改完的內容。寫不進去（沒有 App Group、沒開完全取用）回傳 nil
    @discardableResult
    static func update(_ change: (inout File) -> Void) -> File? {
        // 檔案在但讀不懂時不寫，免得把整份紀錄蓋成空的
        guard let url = fileURL, var file = read(url) else { return nil }
        change(&file)
        guard let data = try? encoder.encode(file), (try? data.write(to: url, options: .atomic)) != nil else {
            return nil
        }
        return file
    }

    /// 檔案不存在回傳空的；存在但讀不到或讀不懂回傳 nil
    private static func read(_ url: URL) -> File? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return File() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(File.self, from: data)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension ClipboardHistory.File {
    /// 顯示順序：釘選的在上面，各自新的在前
    var sorted: [ClipboardHistory.Entry] {
        entries.sorted { a, b in
            a.pinned != b.pinned ? a.pinned : a.updated > b.updated
        }
    }

    /// 存一段讀到的文字：已經有一樣的就移到最上面，不重複存
    mutating func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let i = entries.firstIndex(where: { $0.text == text }) {
            entries[i].updated = Date()
        } else {
            entries.append(.init(id: UUID(), text: text, pinned: false, updated: Date()))
        }
        let unpinned = entries.filter { !$0.pinned }.sorted { $0.updated > $1.updated }
        guard unpinned.count > ClipboardHistory.maxUnpinned else { return }
        let dropped = Set(unpinned.dropFirst(ClipboardHistory.maxUnpinned).map(\.id))
        entries.removeAll { dropped.contains($0.id) }
    }

    mutating func togglePin(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].pinned.toggle()
    }

    mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// 清空：只清沒釘選的
    mutating func clearUnpinned() {
        entries.removeAll { !$0.pinned }
    }
}
