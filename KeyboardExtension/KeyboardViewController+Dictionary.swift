import UIKit

/// 一段組字（從開始打注音到全部送出）裡選過的字，用來判斷要不要自動加詞
struct LearningSession {
    struct Piece {
        let text: String
        let reading: String
    }

    var pieces: [Piece] = []
    /// 有沒有選過不是第一個的候選（全選第一個表示引擎本來就猜對，不用學）
    var choseNonDefault = false
    /// 選過字之後又打了或刪了注音（這段就不是單純的一個詞）
    var typedAfterPick = false

    mutating func noteTyped() {
        if !pieces.isEmpty {
            typedAfterPick = true
        }
    }
}

/// 使用者字典：鍵盤出現時讀進引擎；選字時自動學詞，寫回 App 共用的字典檔（要開完全取用）
extension KeyboardViewController {
    /// 寫檔放背景，不卡打字
    private static let dictionaryQueue = DispatchQueue(label: "org.domyweb.bigkeyboard.dictionary")

    /// 讀字典給引擎；有完全取用就順便留下「鍵盤有在用」的時間，App 看到才顯示「自動學習中」
    func loadUserDictionary() {
        applyUserWords(UserDictionary.load().words)
        guard hasFullAccess else { return }
        Self.dictionaryQueue.async {
            UserDictionary.update { $0.keyboardSeen = Date() }
        }
    }

    /// 選字時記下來：選了不是第一個的多字詞，馬上記一次
    func notePick(_ text: String, reading: String, index: Int) {
        learning.pieces.append(.init(text: text, reading: reading))
        guard index > 0 else { return }
        learning.choseNonDefault = true
        if text.count >= 2 {
            learn(text, reading: reading)
        }
    }

    /// 一段組字全部選完：一個字一個字選、其中有改過候選、中間沒再打注音、共 2～6 個字 → 整段記成新詞
    func finishLearningSession() {
        let s = learning
        learning = LearningSession()
        guard s.pieces.count >= 2, s.pieces.count <= 6, s.choseNonDefault, !s.typedAfterPick,
              s.pieces.allSatisfy({ $0.text.count == 1 }) else { return }
        learn(s.pieces.map(\.text).joined(), reading: s.pieces.map(\.reading).joined(separator: "-"))
    }

    private func learn(_ text: String, reading: String) {
        guard hasFullAccess, !reading.isEmpty else { return }
        Self.dictionaryQueue.async { [weak self] in
            UserDictionary.update {
                $0.learn(text, reading: reading)
                $0.keyboardSeen = Date()
            }
            let words = UserDictionary.load().words
            DispatchQueue.main.async {
                self?.applyUserWords(words)
            }
        }
    }

    private func applyUserWords(_ words: [UserDictionary.Word]) {
        // 同一個讀音有好幾個詞時：手動加的排前面，其次用過次數多的
        let sorted = words.sorted { a, b in
            if a.source != b.source {
                return a.source == .manual
            }
            return a.count > b.count
        }
        engine?.setUserPhrases(readings: sorted.map(\.reading), words: sorted.map(\.text))
    }
}
