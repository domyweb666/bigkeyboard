import UIKit

/// 一段組字（從開始打注音到全部送出）裡選過的字，用來判斷要不要自動加詞
struct LearningSession {
    struct Piece {
        let text: String
        let reading: String
    }

    var pieces: [Piece] = []
    /// 有沒有選過引擎猜的以外的候選（全選引擎猜的表示本來就猜對，不用學）
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
        // 排在背景寫檔的後面讀，才讀得到剛收鍵盤時寫進去的接續紀錄。先空等一次，等多久、讀多久才分得開
        OpenTiming.measure(\.waitForWrite) { Self.dictionaryQueue.sync {} }
        // 檔案沒變就拿上次那份，不再解碼
        let cached = OpenTiming.measure(\.readDictionary) {
            Self.dictionaryQueue.sync { DictionaryCache.current() }
        }
        // 這個控制器的引擎已經有同一版的詞就不重建（新的控制器沒套過，一定會套）
        OpenTiming.measure(\.applyWords) {
            guard cached.wordsVersion != appliedWordsVersion else { return }
            applyUserWords(cached.file.words, version: cached.wordsVersion)
        }
        follows = cached.file.follows
        englishCounts = cached.file.english
        guard hasFullAccess else { return }
        KeyboardSeen.mark()
    }

    /// 選字時記下來：選了引擎猜的以外的多字詞，馬上記一次
    func notePick(_ text: String, reading: String, isDefault: Bool) {
        learning.pieces.append(.init(text: text, reading: reading))
        guard !isDefault else { return }
        learning.choseNonDefault = true
        if text.count >= 2 {
            learn(text, reading: reading)
        }
    }

    /// 一段組字全部選完：分好幾次選（字或詞都算，如「陳炳」＋「彰」）、其中有改過候選、中間沒再打注音、
    /// 共 2～6 個字 → 整段記成新詞
    func finishLearningSession() {
        let s = learning
        learning = LearningSession()
        let text = s.pieces.map(\.text).joined()
        guard s.pieces.count >= 2, (2 ... 6).contains(text.count), s.choseNonDefault, !s.typedAfterPick,
              s.pieces.allSatisfy({ !$0.reading.isEmpty }) else { return }
        learn(text, reading: s.pieces.map(\.reading).joined(separator: "-"))
    }

    // MARK: - 接續紀錄：游標前面的字 → 自己在後面打了什麼

    /// 查接續紀錄的鑰匙：游標前最後 2 個字、最後 1 個字。碰到空白或換行就不算（那是新的一句）
    static func followKeys(_ context: String) -> [String] {
        let tail = Array(context.suffix(2))
        guard let last = tail.last, !last.isWhitespace else { return [] }
        var keys = [String(last)]
        if tail.count == 2, !tail[0].isWhitespace {
            keys.insert(String(tail), at: 0)
        }
        return keys
    }

    /// 自己在這段字後面打過的字詞，常打的在前。看前 2 個字的打過一次就算；只看前 1 個字的要打過兩次，
    /// 免得「的」「我」這種字後面被偶爾打一次的字佔走
    func followers(after context: String) -> [String] {
        var out: [String] = []
        for key in Self.followKeys(context) {
            let minCount = key.count == 2 ? 1 : 2
            let ranked = (follows[key] ?? [:])
                .filter { $0.value >= minCount }
                .sorted { a, b in a.value != b.value ? a.value > b.value : a.key < b.key }
            for (text, _) in ranked where !out.contains(text) {
                out.append(text)
            }
        }
        return out
    }

    /// 用豆鍵在 context 後面打出了 text（1～4 個字）：記下來，下次游標停在一樣的字後面時它排前面。
    /// 只記這兩小段字，整段文字不存；要開完全取用才寫得進檔案
    func noteFollow(_ text: String, after context: String) {
        guard hasFullAccess, (1 ... 4).contains(text.count) else { return }
        for key in Self.followKeys(context) {
            follows[key, default: [:]][text, default: 0] += 1
            pendingFollows.append((context: key, text: text))
        }
        scheduleDictionaryFlush()
    }

    /// 停手 3 秒再寫檔（接續紀錄、英文字），收鍵盤時也會寫
    func scheduleDictionaryFlush() {
        followFlushTimer?.invalidate()
        followFlushTimer = Timer.scheduledTimer(withTimeInterval: 3, repeats: false) { [weak self] _ in
            self?.flushFollows()
        }
    }

    /// 把還沒寫的接續紀錄、英文字一次寫進字典檔（每選一個字就寫一次太頻繁）
    func flushFollows() {
        followFlushTimer?.invalidate()
        followFlushTimer = nil
        let batch = pendingFollows
        let english = pendingEnglish
        pendingFollows = []
        pendingEnglish = []
        guard !batch.isEmpty || !english.isEmpty else { return }
        Self.dictionaryQueue.async {
            DictionaryCache.update { file in
                for item in batch {
                    file.addFollow(item.text, after: item.context)
                }
                for word in english {
                    file.addEnglish(word)
                }
            }
            KeyboardSeen.mark()
        }
    }

    private func learn(_ text: String, reading: String) {
        guard hasFullAccess, !reading.isEmpty else { return }
        Self.dictionaryQueue.async { [weak self] in
            let version = DictionaryCache.update { $0.learn(text, reading: reading) }
            KeyboardSeen.mark()
            let words = UserDictionary.load().words
            DispatchQueue.main.async {
                self?.applyUserWords(words, version: version)
            }
        }
    }

    /// 長按候選字「忘掉這個詞」：鍵盤記著的（字典的詞、接續紀錄、英文打過的字，連還沒寫進檔案的）先拿掉、
    /// 引擎換上新的使用者詞，再在背景寫進字典檔（要開完全取用）。呼叫的人負責重排候選
    func forgetLearned(_ text: String) {
        // 寫進檔案前不知道是第幾版（沒開完全取用也寫不進去），給 nil 讓下次叫出重套
        applyUserWords(userWords.filter { $0.text != text }, version: nil)
        follows = follows.compactMapValues { next in
            let rest = next.filter { $0.key != text }
            return rest.isEmpty ? nil : rest
        }
        pendingFollows.removeAll { $0.text == text }
        let lower = text.lowercased()
        englishCounts = englishCounts.filter { $0.key.lowercased() != lower }
        pendingEnglish.removeAll { $0.lowercased() == lower }
        Self.dictionaryQueue.async {
            DictionaryCache.update { $0.forget(text) }
        }
    }

    /// version：這批詞是字典快取的第幾版，下次叫出時比對；不確定就給 nil，下次叫出一定重套
    private func applyUserWords(_ words: [UserDictionary.Word], version: Int?) {
        userWords = words
        appliedWordsVersion = version
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

/// 上次讀進來、或鍵盤自己寫進去的字典，跟當時檔案的修改時間＋大小。叫出鍵盤時檔案沒變就不用再解碼。
/// 控制器每次叫出可能是新的，所以放 static。只在 dictionaryQueue 上讀寫（主執行緒在 dictionaryQueue.sync 裡拿）
private enum DictionaryCache {
    struct Stamp: Equatable {
        let modified: Date
        let size: Int
    }

    private static var stamp: Stamp?
    private static var file = UserDictionary.File()
    /// 詞的版本：詞真的不一樣才加一（只改了接續紀錄、英文字不加），引擎已經套用同一版就不用重建
    private static var wordsVersion = 0

    /// 檔案沒變就給上次那份；變了（App 加詞、刪詞、iCloud 同步）或查不到修改時間就重讀
    static func current() -> (file: UserDictionary.File, wordsVersion: Int) {
        // 先查修改時間再讀：中間 App 剛好寫入的話，存到的是新內容配舊時間，下次只是多讀一次
        let now = currentStamp()
        if now == nil || now != stamp {
            remember(UserDictionary.load(), stamp: now)
        }
        return (file, wordsVersion)
    }

    /// 鍵盤自己寫字典：寫完把快取換成寫進去的內容和新的修改時間，下次叫出才不用重讀。
    /// 回傳寫入後詞的版本；寫不進去回傳 nil（檔案沒變，快取也不動）
    @discardableResult
    static func update(_ change: (inout UserDictionary.File) -> Void) -> Int? {
        guard let written = UserDictionary.updatedFile(change) else { return nil }
        remember(written, stamp: currentStamp())
        return wordsVersion
    }

    private static func remember(_ new: UserDictionary.File, stamp now: Stamp?) {
        if new.words != file.words {
            wordsVersion += 1
        }
        file = new
        stamp = now
    }

    private static func currentStamp() -> Stamp? {
        guard let path = UserDictionary.fileURL?.path(percentEncoded: false),
              let attributes = try? FileManager.default.attributesOfItem(atPath: path),
              let modified = attributes[.modificationDate] as? Date,
              let size = attributes[.size] as? Int else { return nil }
        return Stamp(modified: modified, size: size)
    }
}
