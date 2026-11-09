import SwiftUI

/// 管理剪貼簿標籤：新增、改名、左滑刪除（刪標籤不會刪掉文字）
struct TagManagerView: View {
    let tags: [String]
    /// 把改動交給剪貼簿頁寫檔
    let apply: ((inout ClipboardHistory.File) -> Void) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newTag = ""
    @State private var renaming: String?
    @State private var renameText = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        TextField("新標籤，例如：文章素材", text: $newTag)
                            .onSubmit(add)
                        Button("加入", action: add)
                            .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
                Section {
                    ForEach(tags, id: \.self) { tag in
                        Button {
                            renameText = tag
                            renaming = tag
                        } label: {
                            Text("＃" + tag)
                                .foregroundStyle(Color.primary)
                        }
                        .swipeActions {
                            Button("刪除", role: .destructive) {
                                apply { $0.deleteTag(tag) }
                            }
                        }
                    }
                } footer: {
                    Text("點標籤可以改名；左滑刪除。刪掉標籤不會刪掉文字。")
                }
            }
            .navigationTitle("標籤")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
            .alert("改名", isPresented: renamingBinding) {
                TextField("標籤名稱", text: $renameText)
                Button("取消", role: .cancel) {}
                Button("儲存") {
                    if let old = renaming {
                        let new = renameText
                        apply { $0.renameTag(old, to: new) }
                    }
                }
            }
        }
    }

    private var renamingBinding: Binding<Bool> {
        Binding(
            get: { renaming != nil },
            set: { shown in
                if !shown {
                    renaming = nil
                }
            }
        )
    }

    private func add() {
        let name = newTag
        apply { $0.addTag(name) }
        newTag = ""
    }
}
