import UIKit

/// 刪除鍵按久了加速（照 iPhone 原生）：先一個字一個字刪，按住約 2 秒後改成一次刪一截。
/// 英文一截是一個詞；中文沒有詞的邊界，一截最多幾個字，碰到標點就停（標點自己算一截）
extension KeyboardViewController {
    func fastDelete() {
        englishAutoSpace = false
        // 還在組字：照平常的退一格
        if engine?.backspace() == true {
            learning.noteTyped()
            syncMarkedText()
            refreshBar()
            return
        }
        let count = Self.fastDeleteCount(before: textDocumentProxy.documentContextBeforeInput ?? "")
        for _ in 0 ..< count {
            textDocumentProxy.deleteBackward()
        }
        associations = []
        refreshBar()
    }

    /// 游標前面是 text 時，這一截要刪幾個字。
    /// 尾巴的空白跟著前面那個詞一起刪；換行、標點、表情符號一次一個
    static func fastDeleteCount(before text: String) -> Int {
        var rest = Substring(text)
        guard let last = rest.last, !last.isNewline else { return 1 }
        var count = 0
        while let c = rest.last, c.isWhitespace, !c.isNewline {
            rest.removeLast()
            count += 1
        }
        guard let head = rest.last else { return max(count, 1) }
        if isEnglishWord(head) {
            while let c = rest.last, isEnglishWord(c) {
                rest.removeLast()
                count += 1
            }
        } else if isWideWord(head) {
            var taken = 0
            while taken < SamsungTheme.fastDeleteMaxCharacters, let c = rest.last, isWideWord(c) {
                rest.removeLast()
                taken += 1
            }
            count += taken
        } else if count == 0 {
            count = 1
        }
        return count
    }

    /// 英文詞裡的字：字母、數字、撇號（don't）
    private static func isEnglishWord(_ c: Character) -> Bool {
        c.isASCII && (c.isLetter || c.isNumber || c == "'")
    }

    /// 中文字這類（不是標點、符號、表情符號）
    private static func isWideWord(_ c: Character) -> Bool {
        !c.isASCII && (c.isLetter || c.isNumber)
    }
}
