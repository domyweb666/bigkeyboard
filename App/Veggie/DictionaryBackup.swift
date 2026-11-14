import CoreTransferable
import Foundation
import UniformTypeIdentifiers

/// 資料匯出與匯入：整本字典（詞、刪除紀錄、不再學的詞、接續紀錄、英文字次數）存成一個 JSON。剪貼簿不放進備份。
/// 一律帶 app、schemaVersion、exportedAt；新版要讀得懂舊版的備份
struct DictionaryBackup: Codable {
    static let currentSchema = 1

    var app: String
    var schemaVersion: Int
    var exportedAt: Date
    var dictionary: UserDictionary.File

    enum ReadError: Error {
        /// 不是這個 app 的備份，或比這一版還新
        case wrongFile
    }

    /// 「豆鍵-備份-2026-11-14.json」
    static var fileName: String {
        let day = Date.now.formatted(.iso8601.year().month().day())
        return "\(VeggieConfig.current.name)-備份-\(day).json"
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

    /// 把現在的字典寫成暫存檔，交給系統分享面板
    static func writeTemporaryFile() throws -> URL {
        let backup = DictionaryBackup(
            app: VeggieConfig.current.slug,
            schemaVersion: currentSchema,
            exportedAt: .now,
            dictionary: UserDictionary.load()
        )
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName)
        try encoder.encode(backup).write(to: url, options: .atomic)
        return url
    }

    /// 讀使用者從「檔案」選的備份
    static func read(_ url: URL) throws -> DictionaryBackup {
        let scoped = url.startAccessingSecurityScopedResource()
        defer {
            if scoped {
                url.stopAccessingSecurityScopedResource()
            }
        }
        let backup = try decoder.decode(DictionaryBackup.self, from: Data(contentsOf: url))
        guard backup.app == VeggieConfig.current.slug, backup.schemaVersion <= currentSchema else {
            throw ReadError.wrongFile
        }
        return backup
    }

    /// 合併：兩邊的詞都留（同一個詞以最後更新的為準）；取代：整本換成備份裡的。寫不進去回傳 false
    func apply(merge: Bool) -> Bool {
        UserDictionary.update { file in
            guard merge else {
                let seen = file.keyboardSeen
                file = dictionary
                file.keyboardSeen = seen
                return
            }
            let merged = DictionarySync.Payload.merge(
                DictionarySync.Payload(file),
                DictionarySync.Payload(dictionary),
                maxRemoved: DictionarySync.maxRemoved
            )
            merged.apply(to: &file)
            for (context, next) in dictionary.follows {
                for (text, count) in next {
                    file.follows[context, default: [:]][text] = max(file.follows[context]?[text] ?? 0, count)
                }
            }
            for (word, count) in dictionary.english {
                file.english[word] = max(file.english[word] ?? 0, count)
            }
        }
    }
}

/// 分享面板要的檔案：按下分享時才產生
struct DictionaryBackupFile: Transferable {
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(exportedContentType: .json) { _ in
            try SentTransferredFile(DictionaryBackup.writeTemporaryFile())
        }
    }
}
