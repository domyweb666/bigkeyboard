import UIKit

/// 長按候選字：說明這個詞為什麼排前面，按「忘掉這個詞」把學到的拿掉（2026-11-21 多米要的：手滑點錯一次就被學起來，
/// 不用再切去 App 刪）。學到的東西有四種：自動學到的詞、手動加的詞、接續紀錄、英文打過的字。
/// 內建詞庫的詞刪不掉，忘掉只是回到詞庫原本的順序。候選列、展開後的全部候選都能長按
extension KeyboardViewController {
    func setUpCandidateMenu() {
        candidateMenu.isHidden = true
        candidateMenu.onClose = { [weak self] in self?.closeCandidateMenu() }
        candidateBar.onLongPress = { [weak self] i in self?.openCandidateMenu(i) }
        candidateGrid.onLongPress = { [weak self] i in self?.openCandidateMenu(i) }
    }

    func openCandidateMenu(_ index: Int) {
        let items = barItems
        guard index < items.count else { return }
        let text = items[index]
        let found = learnedReason(text)
        candidateMenu.onForget = { [weak self] in self?.forget(text) }
        candidateMenu.show(text, reading: found?.reading, reason: found?.reason, canForget: hasFullAccess)
        candidateMenu.isHidden = false
    }

    func closeCandidateMenu() {
        candidateMenu.isHidden = true
    }

    /// 這個詞學過什麼、為什麼排前面。沒學過回傳 nil。學過好幾種時只說最影響排序的那一種，忘掉時全部一起拿掉
    private func learnedReason(_ text: String) -> (reason: String, reading: String?)? {
        let mine = userWords.filter { $0.text == text }
        if let manual = mine.first(where: { $0.source == .manual }) {
            return ("你在豆鍵 App 手動加的詞", manual.displayReading)
        }
        if let auto = mine.max(by: { $0.count < $1.count }) {
            return ("自動學到的詞，選過 \(auto.count) 次", auto.displayReading)
        }
        for key in Self.followKeys(barContext) {
            if let n = follows[key]?[text] {
                return ("在「\(key)」後面打過 \(n) 次", nil)
            }
        }
        let elsewhere = follows.values.compactMap { $0[text] }.reduce(0, +)
        if elsewhere > 0 {
            return ("接在別的字後面打過 \(elsewhere) 次", nil)
        }
        let lower = text.lowercased()
        let typed = englishCounts.filter { $0.key.lowercased() == lower }.values.reduce(0, +)
        if typed > 0 {
            return ("打過 \(typed) 次", nil)
        }
        return nil
    }

    /// 候選列現在照哪段字排：組字中是開始打注音時游標前的字加上已選好的字；其他時候是游標前的字
    private var barContext: String {
        if barSource == .candidates {
            return composeContext + pendingText
        }
        return textDocumentProxy.documentContextBeforeInput ?? ""
    }

    /// 忘掉之後候選馬上重排：組字中照新的使用者詞和接續紀錄重算候選（組字狀態不動）；沒在組字時重算聯想詞
    private func forget(_ text: String) {
        let context = barContext
        forgetLearned(text)
        if let engine, !engine.composing.isEmpty {
            engine.setPreferredFollowers(followers(after: context))
        } else if barSource == .associations {
            associations = suggestions(after: context)
        }
        closeCandidateMenu()
        refreshBar()
    }
}
