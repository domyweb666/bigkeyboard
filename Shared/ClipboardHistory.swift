import Foundation

/// 剪貼簿紀錄：鍵盤在使用者按剪貼簿鍵時讀到的文字，加上在豆鍵 App 裡自己新增的素材，存在 App Group 資料夾裡的
/// clipboard.json。只存在手機上、不上傳。寫法跟字典一樣：讀出、改、整份原子寫回（鍵盤要開完全取用才寫得進去）。
enum ClipboardHistory {
    /// 會被自動清掉的（沒固定、沒標籤、App 裡沒動過）最多留幾筆，超過刪最舊的
    static let maxLoose = 50

    struct Entry: Codable, Equatable, Identifiable {
        var id: UUID
        var text: String
        var pinned: Bool
        /// 鍵盤讀到（或再次讀到）、在 App 裡改過的時間，不是原本複製的時間
        var updated: Date
        /// 標籤名稱（標籤只在 App 裡建；鍵盤裡從已有的選）
        var tags: [String] = []
        /// 在 App 裡新增或改過：當成整理過的素材，不會被自動清掉、不會被「清空」刪掉
        var manual = false

        /// 整理過的：固定、有標籤、App 裡動過。這些不算在自動清理和清空裡
        var isKept: Bool {
            pinned || manual || !tags.isEmpty
        }
    }

    struct File: Codable {
        var entries: [Entry] = []
        /// 上次讀系統剪貼簿時的變更次數：沒變就不再讀內容（每讀一次系統都會跳「已貼上」提示）
        var changeCount: Int?
        /// 所有標籤，照這個順序顯示
        var tags: [String] = []
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

extension ClipboardHistory.Entry {
    /// 欄位缺了就用預設值，之後加欄位時舊檔案也讀得懂
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        text = try c.decode(String.self, forKey: .text)
        pinned = try c.decodeIfPresent(Bool.self, forKey: .pinned) ?? false
        updated = try c.decodeIfPresent(Date.self, forKey: .updated) ?? Date()
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        manual = try c.decodeIfPresent(Bool.self, forKey: .manual) ?? false
    }
}

extension ClipboardHistory.File {
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        entries = try c.decodeIfPresent([ClipboardHistory.Entry].self, forKey: .entries) ?? []
        changeCount = try c.decodeIfPresent(Int.self, forKey: .changeCount)
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }

    /// 顯示順序：固定的在上面，各自新的在前
    var sorted: [ClipboardHistory.Entry] {
        entries.sorted { a, b in
            a.pinned != b.pinned ? a.pinned : a.updated > b.updated
        }
    }

    // MARK: - 鍵盤讀到的

    /// 存一段讀到的文字：已經有一樣的就移到最上面，不重複存
    mutating func add(_ text: String) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        if let i = entries.firstIndex(where: { $0.text == text }) {
            entries[i].updated = Date()
        } else {
            entries.append(.init(id: UUID(), text: text, pinned: false, updated: Date()))
        }
        let loose = entries.filter { !$0.isKept }.sorted { $0.updated > $1.updated }
        guard loose.count > ClipboardHistory.maxLoose else { return }
        let dropped = Set(loose.dropFirst(ClipboardHistory.maxLoose).map(\.id))
        entries.removeAll { dropped.contains($0.id) }
    }

    // MARK: - 鍵盤和 App 都能做的

    mutating func togglePin(_ id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        entries[i].pinned.toggle()
    }

    /// 這筆有這個標籤就拿掉，沒有就加上
    mutating func toggleTag(_ tag: String, on id: UUID) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if entries[i].tags.contains(tag) {
            entries[i].tags.removeAll { $0 == tag }
        } else {
            entries[i].tags.append(tag)
        }
    }

    mutating func remove(_ id: UUID) {
        entries.removeAll { $0.id == id }
    }

    /// 清空：只清沒整理過的（沒固定、沒標籤、App 裡沒動過）
    mutating func clearLoose() {
        entries.removeAll { !$0.isKept }
    }

    // MARK: - 只有 App 做的（要打字）

    /// 在 App 裡新增一筆素材
    mutating func addNote(_ text: String, tags: [String], pinned: Bool) {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        entries.append(.init(id: UUID(), text: text, pinned: pinned, updated: Date(), tags: tags, manual: true))
    }

    /// 在 App 裡改字：改完算整理過的，不會被自動清掉
    mutating func edit(_ id: UUID, text: String) {
        guard let i = entries.firstIndex(where: { $0.id == id }), entries[i].text != text else { return }
        entries[i].text = text
        entries[i].manual = true
        entries[i].updated = Date()
    }

    /// 新增標籤；空白或已經有的不加，回傳有沒有加
    @discardableResult
    mutating func addTag(_ name: String) -> Bool {
        let name = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, !tags.contains(name) else { return false }
        tags.append(name)
        return true
    }

    /// 標籤改名：每筆用到它的也跟著改
    mutating func renameTag(_ old: String, to new: String) {
        let new = new.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !new.isEmpty, old != new, !tags.contains(new), let t = tags.firstIndex(of: old) else { return }
        tags[t] = new
        for i in entries.indices {
            entries[i].tags = entries[i].tags.map { $0 == old ? new : $0 }
        }
    }

    /// 刪標籤：只拿掉標籤，那幾筆文字留著
    mutating func deleteTag(_ name: String) {
        tags.removeAll { $0 == name }
        for i in entries.indices {
            entries[i].tags.removeAll { $0 == name }
        }
    }
}
