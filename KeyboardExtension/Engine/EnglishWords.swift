import Foundation

/// 英文預測字：Android 原生鍵盤的英文詞頻表（Resources/english-words.txt），照開頭查、常用的排前面。
/// 詞表照小寫排好序，用二分搜尋找到開頭一樣的那一段，再挑頻率最高的幾個。不碰 UIKit。
final class EnglishWords {
    static let shared = EnglishWords()

    /// 小寫的字（排好序，跟檔案一樣）
    private var keys: [String] = []
    /// 頻率 0～255
    private var freqs: [UInt8] = []
    /// 顯示跟小寫不一樣的（I、iPhone、don't）：第幾筆 → 顯示的字
    private var displays: [Int: String] = [:]
    private(set) var isLoaded = false
    private var isLoading = false
    /// 查過的開頭 → 結果。詞表讀進來後就不會變，同一個開頭結果永遠一樣：
    /// 每打一個字母工具列會刷新好幾次、每個字的第一個字母也一直重複，查過就不再掃上萬筆
    private var found: [String: [(word: String, freq: Int)]] = [:]
    /// found 是照哪個 limit 查的
    private var foundLimit = 0

    /// 第一次切到英文時才讀（約 3 MB），在背景讀完再回主執行緒
    func loadIfNeeded(then done: @escaping () -> Void) {
        guard !isLoaded, !isLoading else { return }
        isLoading = true
        DispatchQueue.global(qos: .userInitiated).async {
            let parsed = Self.parse()
            DispatchQueue.main.async {
                self.keys = parsed.keys
                self.freqs = parsed.freqs
                self.displays = parsed.displays
                self.isLoaded = true
                self.isLoading = false
                done()
            }
        }
    }

    /// 讀進來的整份詞表
    private struct Table {
        var keys: [String] = []
        var freqs: [UInt8] = []
        var displays: [Int: String] = [:]
    }

    private static func parse() -> Table {
        var t = Table()
        guard let url = Bundle.main.url(forResource: "english-words", withExtension: "txt"),
              let text = try? String(contentsOf: url, encoding: .utf8) else { return t }
        t.keys.reserveCapacity(200_000)
        t.freqs.reserveCapacity(200_000)
        for line in text.split(separator: "\n") where !line.hasPrefix("#") {
            let cols = line.split(separator: "\t", omittingEmptySubsequences: false)
            guard cols.count == 3, let f = UInt8(cols[2]) else { continue }
            if !cols[1].isEmpty {
                t.displays[t.keys.count] = String(cols[1])
            }
            t.keys.append(String(cols[0]))
            t.freqs.append(f)
        }
        return t
    }

    /// 開頭是 prefix（小寫）的字，常用的在前，最多 limit 個
    func completions(of prefix: String, limit: Int) -> [(word: String, freq: Int)] {
        guard isLoaded, !prefix.isEmpty, limit > 0 else { return [] }
        if limit != foundLimit || found.count > 200 {
            found = [:]
            foundLimit = limit
        }
        if let hit = found[prefix] {
            return hit
        }
        let result = scan(prefix, limit: limit)
        found[prefix] = result
        return result
    }

    /// 真的去掃詞表（沒查過的開頭才走這裡）
    private func scan(_ prefix: String, limit: Int) -> [(word: String, freq: Int)] {
        // 跟打的字完全一樣的排最前面（im → I'm、ill → I'll）。詞表照字排序，它們就在這段的開頭
        var exact: [Int] = []
        var i = lowerBound(prefix)
        while i < keys.count, keys[i] == prefix {
            exact.append(i)
            i += 1
        }
        // 只打一個字母時開頭一樣的有上萬個：不整段排序，邊掃邊留最好的 limit 個
        var top: [Int] = []
        while i < keys.count, keys[i].hasPrefix(prefix) {
            if top.count < limit || ranksBefore(i, top[top.count - 1]) {
                let at = top.firstIndex { ranksBefore(i, $0) } ?? top.count
                top.insert(i, at: at)
                if top.count > limit {
                    top.removeLast()
                }
            }
            i += 1
        }
        return (exact + top).prefix(limit).map { (displays[$0] ?? keys[$0], Int(freqs[$0])) }
    }

    /// 頻率高的在前；一樣高時短的在前
    private func ranksBefore(_ a: Int, _ b: Int) -> Bool {
        freqs[a] != freqs[b] ? freqs[a] > freqs[b] : keys[a].utf8.count < keys[b].utf8.count
    }

    /// 詞表裡有沒有這個字（不分大小寫）
    func contains(_ word: String) -> Bool {
        let key = word.lowercased()
        let i = lowerBound(key)
        return i < keys.count && keys[i] == key
    }

    /// 詞表裡有沒有全小寫的這個字（有 monday 的話是 Monday，不算）
    func hasPlain(_ key: String) -> Bool {
        var i = lowerBound(key)
        while i < keys.count, keys[i] == key {
            if displays[i] == nil {
                return true
            }
            i += 1
        }
        return false
    }

    /// 第一個不小於 key 的位置
    private func lowerBound(_ key: String) -> Int {
        var lo = 0
        var hi = keys.count
        while lo < hi {
            let mid = (lo + hi) / 2
            if keys[mid] < key {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        return lo
    }
}
