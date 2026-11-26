import Foundation

/// 使用者字典：豆鍵 App 和鍵盤共用的一份檔案（App Group 資料夾裡的 dictionary.json）。
/// 鍵盤要寫入（自動學到的詞、接續紀錄）必須開「允許完全取用」；沒開時只讀得到。
/// 兩邊都是「讀出、改、整份寫回」，寫入用原子寫入，不會留下寫一半的檔案。
enum UserDictionary {
    static let groupID = "group.org.domyweb.bigkeyboard"

    enum Source: String, Codable {
        case auto
        case manual
    }

    struct Word: Codable, Equatable, Identifiable {
        /// 字，如「茄記」
        var text: String
        /// 讀音，小麥詞庫的格式：音節以 - 連接，如「ㄑㄧㄝˊ-ㄐㄧˋ」
        var reading: String
        var source: Source
        /// 自動學到的詞被選過幾次
        var count: Int
        var updated: Date

        var id: String {
            UserDictionary.key(text, reading: reading)
        }

        /// 給人看的讀音：音節之間用空白
        var displayReading: String {
            reading.replacingOccurrences(of: "-", with: " ")
        }
    }

    struct File: Codable {
        var words: [Word] = []
        /// 在 App 裡刪掉的自動學詞（id），鍵盤不再自動學回來
        var ignored: [String] = []
        /// 刪掉的詞（id → 刪的時間）。iCloud 同步合併時用：比那個詞最後更新還晚的刪除才算數，另一支手機才不會把它傳回來
        var removed: [String: Date] = [:]
        /// 1.2.2 以前鍵盤最後一次寫入的時間；現在改記在 KeyboardSeen，這裡只留著讀舊檔
        var keyboardSeen: Date?
        /// 接續紀錄：前面的 1～2 個字 → 用豆鍵在它後面打出的字詞 → 次數。只存字，不存整段文字
        var follows: [String: [String: Int]] = [:]
        /// 用豆鍵打過的英文字 → 次數（英文預測字把自己常打的排前面）。只存單字，不存整段文字
        var english: [String: Int] = [:]
    }

    static var fileURL: URL? {
        FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: groupID)?
            .appendingPathComponent("dictionary.json")
    }

    static func key(_ text: String, reading: String) -> String {
        reading + " " + text
    }

    /// 讀整份字典；還沒建立、讀不到或讀不懂時回傳空字典
    static func load() -> File {
        guard let url = fileURL else { return File() }
        return read(url) ?? File()
    }

    /// 讀出、改、寫回。寫不進去（沒有 App Group、鍵盤沒開完全取用）回傳 false
    @discardableResult
    static func update(_ change: (inout File) -> Void) -> Bool {
        updatedFile(change) != nil
    }

    /// 跟 update 一樣讀出、改、寫回，寫成功時回傳寫進去的內容（鍵盤拿來換掉快取，不用再讀一次檔）；寫不進去回傳 nil
    static func updatedFile(_ change: (inout File) -> Void) -> File? {
        // 檔案在但讀不懂時不寫，免得把整本字典蓋成空的
        guard let url = fileURL, var file = read(url) else { return nil }
        change(&file)
        guard let data = try? encoder.encode(file) else { return nil }
        guard (try? data.write(to: url, options: .atomic)) != nil else { return nil }
        return file
    }

    /// 檔案不存在回傳空字典；存在但讀不到或讀不懂回傳 nil
    private static func read(_ url: URL) -> File? {
        guard FileManager.default.fileExists(atPath: url.path(percentEncoded: false)) else { return File() }
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(File.self, from: data)
    }

    private static let encoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        // 不排版：排版用的空白和換行佔檔案四成。省的是空間，讀寫只快一點點（18 萬筆讀 97 → 94 毫秒）
        e.outputFormatting = .sortedKeys
        return e
    }()

    private static let decoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()
}

extension UserDictionary.File {
    /// 欄位缺了就用預設值，之後加欄位時舊檔案也讀得懂
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        words = try c.decodeIfPresent([UserDictionary.Word].self, forKey: .words) ?? []
        ignored = try c.decodeIfPresent([String].self, forKey: .ignored) ?? []
        removed = try c.decodeIfPresent([String: Date].self, forKey: .removed) ?? [:]
        keyboardSeen = try c.decodeIfPresent(Date.self, forKey: .keyboardSeen)
        follows = try c.decodeIfPresent([String: [String: Int]].self, forKey: .follows) ?? [:]
        english = try c.decodeIfPresent([String: Int].self, forKey: .english) ?? [:]
    }

    /// 記一個打過的英文字。超過 3000 個時丟掉次數最少的，剩 2500 個
    mutating func addEnglish(_ word: String) {
        english[word, default: 0] += 1
        guard english.count > 3000 else { return }
        let keep = english.sorted { $0.value > $1.value }.prefix(2500)
        english = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
    }

    /// 記一筆接續：context（前面 1～2 個字）後面打了 text。每個 context 只留最常用的 30 個；
    /// context 超過 6000 個時，丟掉總次數最少的，剩 5000 個（檔案不會無限長大）
    mutating func addFollow(_ text: String, after context: String) {
        var next = follows[context] ?? [:]
        next[text, default: 0] += 1
        if next.count > 30 {
            // 次數一樣時留剛打的這個，新詞才有機會留下來
            let keep = next.sorted { a, b in
                (a.value, a.key == text ? 1 : 0) > (b.value, b.key == text ? 1 : 0)
            }.prefix(30)
            next = Dictionary(uniqueKeysWithValues: keep.map { ($0.key, $0.value) })
        }
        follows[context] = next
        guard follows.count > 6000 else { return }
        let ranked = follows.sorted { $0.value.values.reduce(0, +) > $1.value.values.reduce(0, +) }
        follows = Dictionary(uniqueKeysWithValues: ranked.prefix(5000).map { ($0.key, $0.value) })
    }

    /// 自動學到一個詞：已經有就加次數；在 App 裡刪過的不再學
    mutating func learn(_ text: String, reading: String) {
        let id = UserDictionary.key(text, reading: reading)
        guard !ignored.contains(id) else { return }
        removed[id] = nil
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].count += 1
            words[i].updated = Date()
        } else {
            words.append(.init(text: text, reading: reading, source: .auto, count: 1, updated: Date()))
        }
    }

    /// 手動加詞：已經有（例如自動學過）就改成手動
    mutating func addManual(_ text: String, reading: String) {
        let id = UserDictionary.key(text, reading: reading)
        ignored.removeAll { $0 == id }
        removed[id] = nil
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].source = .manual
            words[i].updated = Date()
        } else {
            words.append(.init(text: text, reading: reading, source: .manual, count: 0, updated: Date()))
        }
    }

    /// 鍵盤長按候選字「忘掉這個詞」：字典裡這個字的詞（自動學的、手動加的）照 App 的刪法刪，
    /// 接續紀錄裡接在任何字後面的它、英文打過的它（不分大小寫）也拿掉。內建詞庫的詞不在這裡，刪不到
    mutating func forget(_ text: String) {
        for word in words where word.text == text {
            remove(word)
        }
        follows = follows.compactMapValues { next in
            let rest = next.filter { $0.key != text }
            return rest.isEmpty ? nil : rest
        }
        let lower = text.lowercased()
        english = english.filter { $0.key.lowercased() != lower }
    }

    /// 刪掉一個詞；自動學到的記進 ignored，鍵盤不再學回來；都記下刪的時間（同步用）
    mutating func remove(_ word: UserDictionary.Word) {
        words.removeAll { $0.id == word.id }
        removed[word.id] = Date()
        if word.source == .auto, !ignored.contains(word.id) {
            ignored.append(word.id)
        }
    }
}
