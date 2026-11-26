import UIKit

/// 英文預測字：工具列照游標前正在打的字的開頭給建議（Android 原生鍵盤的詞頻表），點了換掉那個字、補一個空格。
/// 自己用豆鍵打過的字排前面。不做自動更正：打錯不會自己改，只給建議讓人點
extension KeyboardViewController {
    /// 工具列最多擺幾個英文建議
    private static let englishLimit = 12
    /// 自己打過的字最多排幾個在前面（其餘照詞表的頻率）
    private static let mineLimit = 5
    /// 緊接在字後面的標點：點了建議自動補的空格，碰到它們要拿掉
    private static let closingPunctuation: Set = [".", ",", "!", "?", ":", ";", ")"]

    /// 游標前面正在打的英文字（字母和撇號；開頭的撇號是引號，不算）
    var currentEnglishWord: String {
        let before = textDocumentProxy.documentContextBeforeInput ?? ""
        let tail = before.reversed().prefix { $0.isASCII && ($0.isLetter || $0 == "'") }
        return String(tail.reversed().drop { $0 == "'" })
    }

    /// 切到英文時先在背景讀詞表，打第一個字母時就有建議
    func preloadEnglishWords() {
        EnglishWords.shared.loadIfNeeded { [weak self] in self?.refreshBar() }
    }

    func englishSuggestions() -> [String] {
        let typed = currentEnglishWord
        let words = EnglishWords.shared
        guard !typed.isEmpty, words.isLoaded else { return [] }
        let prefix = typed.lowercased()
        // 自己打過的：詞表裡有的打過一次就排前面；詞表沒有的（名字、自創字）要打過兩次，免得打錯的字跑出來
        let mine = typedEnglish(prefix, words: words).prefix(Self.mineLimit).map(\.key)
        let common = words.completions(of: prefix, limit: Self.englishLimit * 2).map(\.word)
        var out: [String] = []
        for word in mine + common {
            let shown = Self.matchCase(word, typed: typed)
            // 跟已經打的一模一樣就不用擺（ill → I'll、i → I 這種寫法不同的照樣擺）
            if shown != typed, !out.contains(shown) {
                out.append(shown)
            }
            if out.count == Self.englishLimit {
                break
            }
        }
        return out
    }

    /// 自己打過、開頭是 prefix 的字，打過多的在前。englishCounts 沒變、這次的開頭是接著上次的往下打時，
    /// 只在上次篩出來的裡面再篩：上次的已經整串排好，再篩一次跟整表重篩、重排的結果一樣
    private func typedEnglish(_ prefix: String, words: EnglishWords) -> [(key: String, lower: String)] {
        let continues = prefix.hasPrefix(TypedEnglishCache.prefix) && TypedEnglishCache.counts == englishCounts
        if continues, let last = TypedEnglishCache.matches {
            let matches = last.filter { $0.lower.hasPrefix(prefix) }
            TypedEnglishCache.prefix = prefix
            TypedEnglishCache.matches = matches
            return matches
        }
        let matches = englishCounts
            .filter { $0.key.lowercased().hasPrefix(prefix) && ($0.value >= 2 || words.contains($0.key)) }
            .sorted { a, b in a.value != b.value ? a.value > b.value : a.key < b.key }
            .map { (key: $0.key, lower: $0.key.lowercased()) }
        TypedEnglishCache.counts = englishCounts
        TypedEnglishCache.prefix = prefix
        TypedEnglishCache.matches = matches
        return matches
    }

    /// 照已經打的大小寫：全大寫（兩個字母以上）→ 建議也全大寫；開頭大寫 → 建議開頭大寫
    private static func matchCase(_ word: String, typed: String) -> String {
        if typed.count >= 2, typed == typed.uppercased() {
            return word.uppercased()
        }
        if typed.first?.isUppercase == true {
            return word.prefix(1).uppercased() + word.dropFirst()
        }
        return word
    }

    /// 點了建議：刪掉正在打的那個字，換成建議的字、後面補空格
    func pickEnglish(_ word: String) {
        let typed = currentEnglishWord
        for _ in 0 ..< typed.count {
            textDocumentProxy.deleteBackward()
        }
        textDocumentProxy.insertText(word + " ")
        englishAutoSpace = true
        noteEnglishWord(word)
    }

    /// 點了建議會自動補空格；接著打標點時把那個空格拿掉（hello . → hello.）。按了別的鍵就不再管
    private func dropAutoSpace(before action: KeySpec.Action) {
        defer { englishAutoSpace = false }
        guard englishAutoSpace, case let .text(s) = action, Self.closingPunctuation.contains(s),
              textDocumentProxy.documentContextBeforeInput?.hasSuffix(" ") == true else { return }
        textDocumentProxy.deleteBackward()
    }

    /// 英文鍵面每按一顆鍵、送進輸入框之前：拿掉自動補的空格；打完一個字（空白、標點、換行）就記下來
    func prepareEnglishKey(_ action: KeySpec.Action) {
        dropAutoSpace(before: action)
        switch action {
        case .space:
            // 這串等一下會被替代文字換掉：是輸入碼，不是英文字，不記
            if typedReplacement(after: lastReplacement) == nil {
                noteEnglishWord(currentEnglishWord)
            }
        case .text, .newline:
            noteEnglishWord(currentEnglishWord)
        default:
            break
        }
    }

    /// 記一個打過的英文字。單一字母不記；要開完全取用才寫得進字典檔
    private func noteEnglishWord(_ word: String) {
        guard word.count >= 2 else { return }
        let stored = Self.englishKey(word)
        // 先放掉快取記著的那份，englishCounts 才能原地加一、不用整份複製
        TypedEnglishCache.clear()
        englishCounts[stored, default: 0] += 1
        guard hasFullAccess else { return }
        pendingEnglish.append(stored)
        scheduleDictionaryFlush()
    }

    /// 存哪種寫法：只有開頭大寫（多半是句首按了 ⇧）、詞表裡又有全小寫的，存小寫；其他照打的存（iPhone、人名）
    private static func englishKey(_ word: String) -> String {
        let lower = word.lowercased()
        let capitalizedOnly = word.first?.isUppercase == true && word.dropFirst().allSatisfy { !$0.isUppercase }
        return capitalizedOnly && EnglishWords.shared.hasPlain(lower) ? lower : word
    }
}

/// 自己打過的英文字照開頭篩好、排好的那份。控制器每次叫出可能是新的，所以放 static；只在主執行緒用。
/// englishCounts 不管在哪裡被換掉（讀檔、忘掉字），下次比對 counts 不一樣就整表重篩
private enum TypedEnglishCache {
    /// 篩的時候 englishCounts 長什麼樣
    static var counts: [String: Int] = [:]
    static var prefix = ""
    /// 開頭是 prefix 的字（存的寫法、小寫），打過多的在前
    static var matches: [(key: String, lower: String)]?

    static func clear() {
        counts = [:]
        matches = nil
    }
}
