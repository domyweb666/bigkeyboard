import Foundation
import QuartzCore

/// 叫出鍵盤要多久，分段計時（2026-11-25 手感審查 #1：先量再改）。
/// 只留最近 20 次的毫秒數、字典大小、記憶體，不碰打了什麼字；存在 App Group 的設定，要開完全取用才寫得進去。
/// 看的地方：豆鍵 App 設定頁最下面長按版本號，跟版本資訊一起複製。時間都是毫秒。
/// 計時只在主執行緒用
struct OpenTiming: Codable {
    var at = Date()
    /// 建鍵面、開引擎。鍵盤畫面新建時才有，沿用舊畫面是 0
    var setUp = 0.0
    /// 等前面還沒寫完的字典
    var waitForWrite = 0.0
    var readDictionary = 0.0
    /// 把詞交給引擎
    var applyWords = 0.0
    var readSounds = 0.0
    var startAudio = 0.0
    /// 系統說要出現（viewWillAppear）到我們準備好，上面幾段（不含 setUp）都在裡面
    var prepare = 0.0
    /// 系統說要出現，到系統說已經出現（viewDidAppear）
    var shown = 0.0
    var words = 0
    /// 接續紀錄幾筆
    var follows = 0
    var fileKB = 0
    var pack = ""
    /// 現在用的、這個行程到目前最高用過的（MB）。鍵盤擴充用太多會被系統收掉
    var memoryMB = 0
    var peakMemoryMB = 0

    static let storageKey = "openTimings"
    private static let keep = 20
    private static let queue = DispatchQueue(label: "org.domyweb.bigkeyboard.opentiming", qos: .utility)

    /// 正在計時的這一次；沒在計時是 nil
    private static var current: OpenTiming?
    private static var started = 0.0
    private static var setUpStarted = 0.0
    private static var lastSetUp = 0.0

    static func setUpBegan() {
        setUpStarted = CACurrentMediaTime()
    }

    static func setUpEnded() {
        lastSetUp = milliseconds(since: setUpStarted)
    }

    static func appearBegan(enabled: Bool) {
        started = CACurrentMediaTime()
        current = enabled ? OpenTiming(setUp: lastSetUp) : nil
        lastSetUp = 0
    }

    /// 做一段事，順便記它花多久
    static func measure<T>(_ stage: WritableKeyPath<OpenTiming, Double>, _ work: () -> T) -> T {
        guard current != nil else { return work() }
        let start = CACurrentMediaTime()
        defer { current?[keyPath: stage] = milliseconds(since: start) }
        return work()
    }

    static func prepared() {
        current?.prepare = milliseconds(since: started)
    }

    /// 鍵盤已經出現：在背景補上字典大小、記憶體，存起來
    static func appeared(words: Int, follows: [String: [String: Int]], pack: String?) {
        guard let timed = current else { return }
        current = nil
        let shown = milliseconds(since: started)
        queue.async {
            var record = timed
            record.shown = shown
            record.words = words
            record.pack = pack ?? ""
            record.follows = follows.values.reduce(0) { $0 + $1.count }
            let path = UserDictionary.fileURL?.path(percentEncoded: false) ?? ""
            let bytes = (try? FileManager.default.attributesOfItem(atPath: path))?[.size] as? Int
            record.fileKB = (bytes ?? 0) / 1024
            (record.memoryMB, record.peakMemoryMB) = memory()
            guard let data = try? JSONEncoder().encode(Array((saved + [record]).suffix(keep))) else { return }
            SpaceKeySetting.defaults?.set(data, forKey: storageKey)
        }
    }

    private static var saved: [OpenTiming] {
        guard let data = SpaceKeySetting.defaults?.data(forKey: storageKey) else { return [] }
        return (try? JSONDecoder().decode([OpenTiming].self, from: data)) ?? []
    }

    /// 給人看的：一次一行，新的在上。還沒量到就是空字串
    static var report: String {
        let lines = saved.reversed().map(\.line)
        guard !lines.isEmpty else { return "" }
        return "\n\n叫出鍵盤（毫秒，新的在上）\n" + lines.joined(separator: "\n")
    }

    private var line: String {
        let time = at.formatted(.dateTime.month().day().hour().minute().second())
        let stages = [
            ("等寫檔", waitForWrite), ("讀字典", readDictionary), ("給引擎", applyWords),
            ("讀音檔", readSounds), ("開音訊", startAudio),
        ].map { "\($0.0) \(Self.text($0.1))" }.joined(separator: "、")
        return "\(time)｜出現 \(Self.text(shown))｜準備 \(Self.text(prepare))（\(stages)）｜新建 \(Self.text(setUp))"
            + "｜詞 \(words)、接續 \(follows)、檔 \(fileKB) KB｜聲音 \(pack.isEmpty ? "無" : pack)"
            + "｜記憶體 \(memoryMB)、最高 \(peakMemoryMB) MB"
    }

    private static func text(_ milliseconds: Double) -> String {
        String(format: "%.1f", milliseconds)
    }

    private static func milliseconds(since start: Double) -> Double {
        (CACurrentMediaTime() - start) * 1000
    }

    /// 系統算這個行程用了多少記憶體（跟收掉鍵盤的上限同一種算法）：現在、最高（MB）
    private static func memory() -> (now: Int, peak: Int) {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, 0) }
        return (Int(info.phys_footprint) / 1_048_576, Int(info.ledger_phys_footprint_peak) / 1_048_576)
    }
}
