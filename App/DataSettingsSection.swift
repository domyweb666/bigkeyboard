import SwiftUI
import UniformTypeIdentifiers

/// 設定頁「資料」區：iCloud 同步、匯出資料、匯入資料、清除所有資料（規格：蔬菜家族共用基本元素「資料」）
struct DataSettingsSection: View {
    /// 清除所有資料時要一起回到預設的設定
    @Binding var spaceSelectsFirstCandidate: Bool
    @Binding var appearance: Appearance
    /// 上方跳提示（設定頁的）
    let show: (String) -> Void

    @AppStorage(DictionarySync.enabledKey) private var iCloudSync = false
    /// 剛關掉同步：問要不要一起刪掉 iCloud 上那份
    @State private var askDeleteCloud = false
    /// 清除所有資料時順手關掉同步，這次不問要不要刪 iCloud 那份（清除時已經刪了）
    @State private var resetting = false
    @State private var importing = false
    @State private var pendingImport: DictionaryBackup?
    @State private var resetStep1 = false
    @State private var resetStep2 = false

    private let config = VeggieConfig.current

    var body: some View {
        DomySection("資料", footer: Self.iCloudFooter) {
            VeggieToggleRow(icon: "icloud", title: VeggieText.sync, isOn: $iCloudSync)
                .onChange(of: iCloudSync) {
                    if iCloudSync {
                        DictionarySync.sync()
                    } else if !resetting {
                        askDeleteCloud = true
                    }
                }
                .confirmationDialog(
                    "iCloud 上的字典要一起刪掉嗎？",
                    isPresented: $askDeleteCloud,
                    titleVisibility: .visible
                ) {
                    Button("刪掉 iCloud 上的字典", role: .destructive) {
                        DictionarySync.deleteCloudCopy()
                    }
                    Button("留著", role: .cancel) {}
                } message: {
                    Text("手機裡的字典不會動。留著的話，之後再打開同步會接著用。")
                }
            DomyDivider()
            ShareLink(item: DictionaryBackupFile(), preview: SharePreview(DictionaryBackup.fileName)) {
                VeggieRow(icon: "square.and.arrow.up", title: VeggieText.export, accessory: .push)
            }
            .buttonStyle(.plain)
            DomyDivider()
            importRow
            DomyDivider()
            resetRow
        }
    }

    private static let iCloudFooter = "打開 iCloud 同步後，字典裡的詞（自動學到的、自己加的）會存到你自己的 iCloud，"
        + "同一個 Apple ID 的其他 iPhone 打開豆鍵 App 就會合併過去。"
        + "剪貼簿和打字紀錄不會上傳。\n"
        + "鍵盤本身不連網：鍵盤學到的新詞，要打開豆鍵 App 才會同步。"
        + "手機沒登入 iCloud 時，字典照常存在手機上。\n"
        + "匯出的備份檔是整本字典（不含剪貼簿），可以存到「檔案」，換手機時再匯入。"

    private var importRow: some View {
        Button {
            importing = true
        } label: {
            VeggieRow(icon: "square.and.arrow.down", title: VeggieText.importData, accessory: .push)
        }
        .buttonStyle(.plain)
        .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
            guard case let .success(url) = result else { return }
            do {
                pendingImport = try DictionaryBackup.read(url)
            } catch {
                show("這不是豆鍵的備份檔，或是比這一版豆鍵還新的備份。")
            }
        }
        .confirmationDialog(
            importTitle,
            isPresented: importDialogShown,
            titleVisibility: .visible
        ) {
            Button("合併（兩邊的詞都留）") {
                finishImport(merge: true)
            }
            Button("取代（換成備份裡的）", role: .destructive) {
                finishImport(merge: false)
            }
            Button("取消", role: .cancel) {
                pendingImport = nil
            }
        }
    }

    /// 選好備份檔後跳「將匯入 N 個詞」；關掉就丟掉這份
    private var importDialogShown: Binding<Bool> {
        Binding(
            get: { pendingImport != nil },
            set: { shown in
                if !shown {
                    pendingImport = nil
                }
            }
        )
    }

    private var importTitle: String {
        let count = pendingImport?.dictionary.words.count ?? 0
        return VeggieText.importPreview(count, counter: config.dataCounter, noun: config.dataNoun)
    }

    private func finishImport(merge: Bool) {
        guard let backup = pendingImport else { return }
        pendingImport = nil
        guard backup.apply(merge: merge) else {
            show("沒有匯入成功。打開豆鍵 App 的字典頁看看，再試一次。")
            return
        }
        NotificationCenter.default.post(name: DictionarySync.didChangeLocal, object: nil)
        DictionarySync.sync()
        show("已匯入")
    }

    private var resetRow: some View {
        Button {
            resetStep1 = true
        } label: {
            VeggieRow(icon: "trash", title: VeggieText.reset, destructive: true)
        }
        .buttonStyle(.plain)
        .alert(VeggieText.resetTitle, isPresented: $resetStep1) {
            Button("繼續", role: .destructive) {
                // 等第一個視窗收完再跳第二個，不然第二個跳不出來
                Task {
                    try? await Task.sleep(for: .milliseconds(400))
                    resetStep2 = true
                }
            }
            Button("取消", role: .cancel) {}
        } message: {
            Text(resetMessage)
        }
        .confirmationDialog(VeggieText.resetTitle, isPresented: $resetStep2, titleVisibility: .visible) {
            Button(VeggieText.resetConfirm, role: .destructive) {
                clearAll()
            }
            Button("取消", role: .cancel) {}
        }
    }

    private var resetMessage: String {
        var text = VeggieText.resetBody(config.resetScope) + "（用上面的「匯出資料」）"
        if iCloudSync {
            text += "\niCloud 上的字典也會一起刪除。"
        }
        return text
    }

    /// 回到第一次打開的狀態：字典、剪貼簿清空，設定回到預設。買過的主題不動
    private func clearAll() {
        if iCloudSync {
            DictionarySync.deleteCloudCopy()
            resetting = true
            iCloudSync = false
        }
        let cleared = UserDictionary.update { $0 = UserDictionary.File() }
        ClipboardHistory.update { $0 = ClipboardHistory.File() }
        spaceSelectsFirstCandidate = false
        appearance = .system
        NotificationCenter.default.post(name: DictionarySync.didChangeLocal, object: nil)
        show(cleared ? "已清除所有資料" : VeggieText.errorGeneric)
        Task {
            try? await Task.sleep(for: .milliseconds(400))
            resetting = false
        }
    }
}
