import Foundation

/// 從小麥詞庫查讀音，給加詞畫面自動帶注音。詞庫檔在鍵盤擴充的 bundle 裡，App 直接讀，不另外放一份
enum ReadingLookup {
    struct Result {
        /// 每個字可選的讀音，第一個是預設；查不到讀音的字是空陣列
        var options: [[String]] = []
    }

    private struct Entry {
        let reading: String
        let score: Double
    }

    /// 詞 → 讀音清單。第一次用到時整本詞庫掃一遍建起來
    private static let index: [String: [Entry]] = buildIndex()

    /// App 一打開就在背景先建好，按＋的時候不用等
    static func warmUp() {
        DispatchQueue.global(qos: .utility).async {
            _ = index.count
        }
    }

    static func lookup(_ word: String) -> Result {
        let chars = word.map(String.init)
        guard !chars.isEmpty else { return Result() }
        // 整個詞在詞庫裡：用詞庫的讀音當每個字的預設
        let whole = index[word]?
            .max { $0.score < $1.score }?
            .reading.split(separator: "-").map(String.init)
        var options: [[String]] = []
        for (i, c) in chars.enumerated() {
            var seen = Set<String>()
            var list = (index[c] ?? [])
                .filter { !$0.reading.contains("-") }
                .sorted { $0.score > $1.score }
                .map(\.reading)
                .filter { seen.insert($0).inserted }
            if let whole, whole.count == chars.count {
                list.removeAll { $0 == whole[i] }
                list.insert(whole[i], at: 0)
            }
            options.append(Array(list.prefix(6)))
        }
        return Result(options: options)
    }

    private static func buildIndex() -> [String: [Entry]] {
        guard let data = dataFile(), let text = String(data: data, encoding: .utf8) else { return [:] }
        var result: [String: [Entry]] = [:]
        for line in text.split(separator: "\n") {
            let parts = line.split(separator: " ")
            guard parts.count == 3, !parts[0].hasPrefix("_"), let score = Double(parts[2]) else { continue }
            result[String(parts[1]), default: []].append(Entry(reading: String(parts[0]), score: score))
        }
        return result
    }

    private static func dataFile() -> Data? {
        guard let plugins = Bundle.main.builtInPlugInsURL else { return nil }
        let items = (try? FileManager.default.contentsOfDirectory(at: plugins, includingPropertiesForKeys: nil)) ?? []
        return items
            .filter { $0.pathExtension == "appex" }
            .lazy
            .compactMap { try? Data(contentsOf: $0.appendingPathComponent("mcbopomofo-data.txt")) }
            .first
    }
}
