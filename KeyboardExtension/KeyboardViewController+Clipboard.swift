import UIKit

/// 剪貼簿：按工具列的剪貼簿鍵 → 讀系統剪貼簿（有變才讀）→ 存進 clipboard.json → 面板列出來 → 點一筆貼上。
/// 只在使用者按鍵那一下讀：不在背景聽、不在叫出鍵盤時讀。讀不到別的 App 以前複製過的東西，只存得到按鍵當下那一筆
extension KeyboardViewController {
    func setUpClipboard() {
        candidateBar.onClipboard = { [weak self] in self?.toggleClipboard() }
        clipboardPanel.onBack = { [weak self] in self?.closeClipboard() }
        clipboardPanel.onPick = { [weak self] entry in self?.pasteClipboard(entry) }
        clipboardPanel.onTogglePin = { [weak self] id in self?.changeClipboard { $0.togglePin(id) } }
        clipboardPanel.onDelete = { [weak self] id in self?.changeClipboard { $0.remove(id) } }
        clipboardPanel.onClear = { [weak self] in self?.changeClipboard { $0.clearUnpinned() } }
    }

    private func toggleClipboard() {
        if clipboardOpen {
            closeClipboard()
        } else {
            openClipboard()
        }
    }

    private func openClipboard() {
        clipboardOpen = true
        expanded = false
        guard hasFullAccess else {
            clipboardPanel.show(.needsFullAccess)
            refreshBar()
            return
        }
        // 先列出已經存的，系統剪貼簿在背景讀完再補上新的那筆
        clipboardPanel.show(.entries(ClipboardHistory.load().sorted))
        clipboardPanel.scrollToTop()
        refreshBar()
        SystemClipboard.queue.async { [weak self] in
            let file = SystemClipboard.capture()
            DispatchQueue.main.async { [weak self] in
                guard let self, clipboardOpen else { return }
                clipboardPanel.show(.entries(file.sorted))
            }
        }
    }

    func closeClipboard() {
        clipboardOpen = false
        refreshBar()
    }

    /// 點一筆：組到一半的注音先送出，再把整段貼在游標處，回到鍵盤
    private func pasteClipboard(_ entry: ClipboardHistory.Entry) {
        commitAllComposing()
        textDocumentProxy.insertText(entry.text)
        associations = []
        closeClipboard()
        refreshContextAssociations()
    }

    /// 釘選、刪除、清空：寫檔放背景，寫完照新內容重列
    private func changeClipboard(_ change: @escaping @Sendable (inout ClipboardHistory.File) -> Void) {
        SystemClipboard.queue.async { [weak self] in
            guard let file = ClipboardHistory.update(change) else { return }
            DispatchQueue.main.async { [weak self] in
                guard let self, clipboardOpen else { return }
                clipboardPanel.show(.entries(file.sorted))
            }
        }
    }
}

/// 讀系統剪貼簿。放在背景：從別台裝置來的內容（通用剪貼簿）要等它傳過來，不能卡住鍵盤
private enum SystemClipboard {
    static let queue = DispatchQueue(label: "org.domyweb.bigkeyboard.clipboard")
    /// 密碼管理 App 複製密碼時標的「隱藏內容」類型：這種不存
    private static let concealedType = "org.nspasteboard.ConcealedType"

    /// 系統剪貼簿從上次讀過之後有變（變更次數不一樣）才讀內容，是文字就存起來。回傳存完的整份紀錄
    static func capture() -> ClipboardHistory.File {
        let board = UIPasteboard.general
        let count = board.changeCount
        let file = ClipboardHistory.load()
        guard file.changeCount != count else { return file }
        // 不是文字（圖片、檔案）或是密碼：只記下這次看過了，不讀內容
        let text = board.hasStrings && !board.types.contains(concealedType) ? board.string : nil
        return ClipboardHistory.update { f in
            f.changeCount = count
            if let text {
                f.add(text)
            }
        } ?? file
    }
}
