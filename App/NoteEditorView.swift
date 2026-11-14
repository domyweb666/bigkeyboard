import SwiftUI

/// 編輯（或新增）剪貼簿的一筆：改字、勾標籤、固定、刪除。按「儲存」才寫進去
struct NoteEditorView: View {
    let entry: ClipboardHistory.Entry
    let isNew: Bool
    let allTags: [String]
    /// 把改動交給剪貼簿頁寫檔
    let apply: ((inout ClipboardHistory.File) -> Void) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var typing: Bool
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
        .tint(Brand.theme.strong)
    }

    private var form: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Gap.s6) {
                editor
                DomySection {
                    Toggle("固定在最上面", isOn: $pinned)
                        .font(Typo.body.font)
                        .foregroundStyle(Ink.textPrimary)
                        .tint(Brand.theme.accent)
                        .frame(minHeight: Metric.row)
                    DomyDivider()
                    Text(Self.keptNote)
                        .font(Typo.footnote.font)
                        .foregroundStyle(Ink.textSecondary)
                        .padding(.vertical, Gap.s3)
                }
                tagSection
                if !isNew {
                    Button {
                        confirmingDelete = true
                    } label: {
                        Label("刪除這筆", systemImage: "trash")
                    }
                    .buttonStyle(DomyButtonStyle(kind: .destructive))
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.vertical, Gap.s4)
        }
        .background(Brand.theme.canvas)
    }

    /// 文字框：白底大圓角，正在打字時框線是產品色
    private var editor: some View {
        TextEditor(text: $text)
            .font(Typo.body.font)
            .foregroundStyle(Ink.textPrimary)
            .focused($typing)
            .scrollContentBackground(.hidden)
            .accessibilityLabel("文字")
            .padding(Gap.s3)
            .frame(minHeight: Metric.heroButton + Gap.s5)
            .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.xl))
            .overlay {
                RoundedRectangle(cornerRadius: Corner.xl)
                    .stroke(typing ? Brand.theme.accent : Color.clear, lineWidth: Metric.hairline * 1.5)
            }
    }

    private var tagSection: some View {
        VStack(alignment: .leading, spacing: Gap.s3) {
            Text("標籤")
                .font(Typo.title3.font)
                .foregroundStyle(Ink.textPrimary)
                .padding(.horizontal, Gap.s1)
                .accessibilityAddTraits(.isHeader)
            if allTags.isEmpty {
                Text("還沒有標籤。回到剪貼簿頁，按右上角的標籤圖示新增。")
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Ink.textSecondary)
                    .padding(.horizontal, Gap.s1)
            } else {
                FlowLayout(spacing: Gap.s2) {
                    ForEach(allTags, id: \.self) { tag in
                        tagChip(tag)
                    }
                }
            }
        }
    }

    /// 一顆標籤膠囊：點一下勾選或取消，勾了的是產品色淡底加打勾
    private func tagChip(_ tag: String) -> some View {
        let on = tags.contains(tag)
        return Button {
            if on {
                tags.removeAll { $0 == tag }
            } else {
                tags.append(tag)
            }
        } label: {
            HStack(spacing: Gap.s1) {
                if on {
                    Image(systemName: "checkmark")
                        .imageScale(.small)
                        .fontWeight(.bold)
                }
                Text("＃" + tag)
                    .lineLimit(1)
            }
            .font(Typo.subheadline.font.weight(on ? .semibold : .regular))
            .foregroundStyle(on ? Brand.theme.strong : Ink.textPrimary)
            .padding(.horizontal, Gap.s3 + Gap.s1 / 2)
            .frame(minHeight: Metric.touch - Gap.s1)
            .background(on ? Brand.theme.soft : Ink.surface, in: Capsule())
            .overlay {
                Capsule()
                    .stroke(on ? Brand.theme.soft : Ink.fieldBorder, lineWidth: Metric.hairline)
            }
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(on ? .isSelected : [])
    }

    private static let keptNote = "固定、有標籤、在 App 裡新增或改過的，不會被自動清掉，"
        + "鍵盤上按「清空」也不會刪。"

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
