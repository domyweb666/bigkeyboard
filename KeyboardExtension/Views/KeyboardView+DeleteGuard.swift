import UIKit

/// 刪除串：連續按 ⌫ 的次數與最後一次碰 ⌫ 的時間。按了別的鍵就歸零
struct DeleteStreak {
    private(set) var count = 0
    /// 最後活動：按下、連刪每一下、放開
    private(set) var lastTime: CFTimeInterval = 0

    /// 按一次 +1；停太久再按，從頭算
    mutating func press() {
        let now = CACurrentMediaTime()
        count = now - lastTime <= SamsungTheme.deleteGuardSeconds ? count + 1 : 1
        lastTime = now
    }

    /// 按住連刪的第 repeats 下：整段連刪只多算 1 下（連按下那次共 2 下）
    mutating func tick(_ repeats: Int) {
        guard count > 0 else { return }
        if repeats == 1 {
            count += 1
        }
        lastTime = CACurrentMediaTime()
    }

    mutating func release() {
        lastTime = CACurrentMediaTime()
    }
}

/// 連刪保護：正在連續刪字時，手指偏出 ⌫ 一點照樣算 ⌫，不會打出 ㄥ、按到換行（在聊天 App 會把訊息送出去）。
/// 只管手指按下去的那一刻算哪顆鍵（hitTest），滑動不套
extension KeyboardView {
    /// 有鍵按下或放開：⌫ 記進刪除串，按了別的鍵就歸零
    func noteDeleteStreak(_ b: KeyButton, pressed: Bool) {
        guard let spec = specs[b], case .backspace = spec.action else {
            if pressed {
                deleteStreak = DeleteStreak()
            }
            return
        }
        if pressed {
            deleteStreak.press()
        } else {
            deleteStreak.release()
        }
    }

    /// 連刪中、落點夠靠近 ⌫ 就回傳 ⌫；其他回 nil，照平常找最近的鍵。hitTest 會呼叫，不准有副作用
    func guardedDeleteKey(at location: CGPoint) -> KeyButton? {
        let idle = CACurrentMediaTime() - deleteStreak.lastTime
        guard deleteStreak.count >= 1, idle <= SamsungTheme.deleteGuardSeconds, let key = deleteKey else {
            return nil
        }
        let point = lifted(location)
        let f = key.convert(key.bounds, to: self)
        // ⌫ 自己那格（含四邊各半個縫）：不讓注音的動態感應範圍吃進來
        if f.insetBy(dx: -SamsungTheme.keyGap / 2, dy: -SamsungTheme.rowGap / 2).contains(point) {
            return key
        }
        guard deleteStreak.count >= 2 else { return nil }
        let dx = max(f.minX - point.x, 0, point.x - f.maxX)
        let dy = max(f.minY - point.y, 0, point.y - f.maxY)
        let fast = idle <= SamsungTheme.deleteGuardFastSeconds
        let reach = fast ? SamsungTheme.deleteGuardFastReach : SamsungTheme.deleteGuardReach
        return hypot(dx, dy) <= reach ? key : nil
    }

    private var deleteKey: KeyButton? {
        buttons.first { b in
            guard let spec = specs[b], case .backspace = spec.action else { return false }
            return true
        }
    }
}
