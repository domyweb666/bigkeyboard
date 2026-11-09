import SwiftUI

/// 編輯（或新增）剪貼簿的一筆：改字、勾標籤、固定、刪除。按「儲存」才寫進去
struct NoteEditorView: View {
    let entry: ClipboardHistory.Entry
    let isNew: Bool
    let allTags: [String]
    /// 把改動交給剪貼簿頁寫檔
    let apply: ((inout ClipboardHistory.File) -> Void) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text: String
    @State private var tags: [String]
    @State private var pinned: Bool
    @State private var confirmingDelete = false

    init(
        entry: ClipboardHistory.Entry,
        isNew: Bool,
        allTags: [String],
        apply: @escaping ((inout ClipboardHistory.File) -> Void) -> Void
    ) {
        self.entry = entry
        self.isNew = isNew
        self.allTags = allTags
        self.apply = apply
        _text = State(initialValue: entry.text)
        _tags = State(initialValue: entry.tags)
        _pinned = State(initialValue: entry.pinned)
    }

    var body: some View {
        NavigationStack {
            form
                .navigationTitle(isNew ? "新增" : "編輯")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("取消") {
                            dismiss()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("儲存") {
                            save()
                            dismiss()
                        }
                        .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .confirmationDialog("刪除這筆？", isPresented: $confirmingDelete, titleVisibility: .visible) {
                    Button("刪除", role: .destructive) {
                        let id = entry.id
                        apply { $0.remove(id) }
                        dismiss()
                    }
                }
        }
    }

    private var form: some View {
        Form {
            Section {
                TextEditor(text: $text)
                    .frame(minHeight: 180)
            }
            Section {
                Toggle("固定在最上面", isOn: $pinned)
            }
            Section {
                if allTags.isEmpty {
                    Text("還沒有標籤。回到剪貼簿頁，按右上角的標籤圖示新增。")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(allTags, id: \.self) { tag in
                    tagRow(tag)
                }
            } header: {
                Text("標籤")
            }
            if !isNew {
                Section {
                    Button("刪除這筆", role: .destructive) {
                        confirmingDelete = true
                    }
                }
            }
        }
    }

    private func tagRow(_ tag: String) -> some View {
        let on = tags.contains(tag)
        return Button {
            if on {
                tags.removeAll { $0 == tag }
            } else {
                tags.append(tag)
            }
        } label: {
            HStack {
                Text("＃" + tag)
                    .foregroundStyle(Color.primary)
                Spacer()
                Image(systemName: on ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(on ? Color.accentColor : Color.secondary)
            }
        }
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private func save() {
        let id = entry.id
        let newText = text
        let newTags = tags
        let newPinned = pinned
        if isNew {
            apply { $0.addNote(newText, tags: newTags, pinned: newPinned) }
            return
        }
        apply { file in
            file.edit(id, text: newText)
            guard let i = file.entries.firstIndex(where: { $0.id == id }) else { return }
            file.entries[i].tags = newTags
            file.entries[i].pinned = newPinned
        }
    }
}
