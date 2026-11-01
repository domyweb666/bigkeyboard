import Foundation

/// 使用者字典：豆鍵 App 和鍵盤共用的一份檔案（App Group 資料夾裡的 dictionary.json）。
/// 鍵盤要寫入（自動學到的詞、最後上線時間）必須開「允許完全取用」；沒開時只讀得到。
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
        /// 鍵盤最後一次寫入的時間（App 用來顯示「自動學習中」）
        var keyboardSeen: Date?
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
        // 檔案在但讀不懂時不寫，免得把整本字典蓋成空的
        guard let url = fileURL, var file = read(url) else { return false }
        change(&file)
        guard let data = try? encoder.encode(file) else { return false }
        return (try? data.write(to: url, options: .atomic)) != nil
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
        e.outputFormatting = [.prettyPrinted, .sortedKeys]
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
        keyboardSeen = try c.decodeIfPresent(Date.self, forKey: .keyboardSeen)
    }

    /// 自動學到一個詞：已經有就加次數；在 App 裡刪過的不再學
    mutating func learn(_ text: String, reading: String) {
        let id = UserDictionary.key(text, reading: reading)
        guard !ignored.contains(id) else { return }
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
        if let i = words.firstIndex(where: { $0.id == id }) {
            words[i].source = .manual
            words[i].updated = Date()
        } else {
            words.append(.init(text: text, reading: reading, source: .manual, count: 0, updated: Date()))
        }
    }

    /// 刪掉一個詞；自動學到的記進 ignored，鍵盤不再學回來
    mutating func remove(_ word: UserDictionary.Word) {
        words.removeAll { $0.id == word.id }
        if word.source == .auto, !ignored.contains(word.id) {
            ignored.append(word.id)
        }
    }
}
