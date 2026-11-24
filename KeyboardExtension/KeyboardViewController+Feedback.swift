import AudioToolbox
import UIKit

/// 按鍵的回饋：震動、聲音。兩個開關都在豆鍵 App 的設定頁（存在 App Group，要開完全取用才讀得到）。
extension KeyboardViewController {
    /// 按鍵震動：每按一顆鍵輕點一下（刪除鍵按住連刪時每刪一下也點）。
    /// 第三方鍵盤讀不到系統「鍵盤回饋 → 觸覺」的開關，所以自己放開關（預設關，跟系統一樣）；
    /// 鍵盤擴充要開完全取用才震得了
    func tapHaptic() {
        guard keyHaptics else { return }
        keyHaptic.impactOccurred(intensity: SamsungTheme.keyHapticIntensity)
        // 先叫醒震動馬達，下一下才不會慢半拍
        keyHaptic.prepare()
    }

    /// 空白鍵一按下就叫醒震動馬達：按住 0.4 秒進觸控板要震，按鍵震動關著時馬達是冷的，到時候才叫會慢半拍
    func warmUpCursorHaptic(for spec: KeySpec) {
        guard case .space = spec.action else { return }
        keyHaptic.prepare()
    }

    /// 按鍵聲（手指碰到鍵的那一下），照 App 設定頁選的：
    /// 跟隨 iPhone 設定走系統的那一種（iPhone 的「設定 → 聲音與觸覺 → 鍵盤回饋 → 聲音」關著就不響）；
    /// 三種按鍵聲是字母、刪除、功能鍵各用系統鍵盤的那三種聲音，光聽就知道按了哪一類；
    /// 機械鍵盤聲音包隨機播一個「按下去」的錄音，空白、刪除、換行這些大鍵播比較低的那幾個；關閉就不出聲
    func playKeySound(for spec: KeySpec) {
        playPressSound(systemSound: Self.soundID(for: spec.action), bigKey: !KeyboardView.isCharacterKey(spec))
    }

    /// 選了一個候選字（候選列、展開的全部候選）：跟按一顆字鍵一樣響、一樣震（2026-11-22 多米要求）。
    /// 選字是手指放開才算，聲音也在那時響：候選列能左右捲，按下就響的話，捲一下也會響。
    /// 機械鍵盤只播按下那聲，不接彈回聲（選字是一下，兩聲擠在一起像連按兩次）
    func candidateFeedback() {
        playPressSound(systemSound: Self.characterSound, bigKey: false)
        tapHaptic()
    }

    private func playPressSound(systemSound: SystemSoundID, bigKey: Bool) {
        switch keySound {
        case .system:
            UIDevice.current.playInputClick()
        case .distinct:
            AudioServicesPlaySystemSound(systemSound)
        case .crisp, .thick, .vintage, .beans, .woodblock, .typewriter, .laptop:
            // 這一套的音檔沒包進來、播放器還沒在背景開好、或開不起來，就退回系統的按鍵聲，不要變成沒聲音
            if !Self.keySoundPlayer.play(.down, bigKey: bigKey) {
                UIDevice.current.playInputClick()
            }
        case .off:
            break
        }
    }

    /// 手指離開鍵的那一下：機械鍵盤聲音包播鍵「彈回來」的聲音。
    /// 真的鍵盤按下、放開各響一聲，兩聲隔多久看手指按多久；其他按鍵聲放開不出聲。
    /// 豆子、木魚、打字機、筆電這幾套沒有彈回聲的音檔，play 找不到就不播
    func playKeyReleaseSound(for spec: KeySpec) {
        guard keySound.pack != nil else { return }
        Self.keySoundPlayer.play(.up, bigKey: !KeyboardView.isCharacterKey(spec))
    }

    /// 系統鍵盤的字母鍵聲
    private static let characterSound: SystemSoundID = 1104

    /// 系統鍵盤的三種按鍵聲：字母 1104、刪除 1155、空白與功能鍵 1156
    private static func soundID(for action: KeySpec.Action) -> SystemSoundID {
        switch action {
        case .bopomofo, .letter, .text: characterSound
        case .backspace: 1155
        default: 1156
        }
    }
}
