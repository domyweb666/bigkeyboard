import SwiftUI

/// 管理剪貼簿標籤：新增、改名、左滑刪除（刪標籤不會刪掉文字）
struct TagManagerView: View {
    let tags: [String]
    /// 每個標籤有幾筆
    let counts: [String: Int]
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
                    addRow
                }
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: Gap.s2, leading: 0, bottom: Gap.s2, trailing: 0))
                Section {
                    ForEach(tags, id: \.self) { tag in
                        tagRow(tag)
                            .swipeActions {
                                Button("刪除", role: .destructive) {
                                    apply { $0.deleteTag(tag) }
                                }
                            }
                    }
                    .listRowBackground(Ink.surface)
                    .listRowSeparatorTint(Ink.separator)
                } footer: {
                    Text("點標籤可以改名；左滑刪除。刪掉標籤不會刪掉文字。")
                        .font(Typo.footnote.font)
                        .foregroundStyle(Ink.textSecondary)
                }
            }
            .listStyle(.insetGrouped)
            .listSectionSpacing(Gap.s2)
            .scrollContentBackground(.hidden)
            .background(Brand.theme.canvas)
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
        .tint(Brand.theme.strong)
    }

    /// 新增標籤：輸入框＋「加入」
    private var addRow: some View {
        VStack(alignment: .leading, spacing: Gap.s2) {
            Text("新增標籤")
                .font(Typo.subheadline.font.weight(.semibold))
                .foregroundStyle(Ink.textPrimary)
            HStack(spacing: Gap.s2) {
                TextField("例如：文章素材", text: $newTag)
                    .font(Typo.body.font)
                    .foregroundStyle(Ink.textPrimary)
                    .onSubmit(add)
                    .accessibilityLabel("新標籤")
                    .padding(.horizontal, Gap.s4)
                    .frame(minHeight: Metric.field)
                    .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.md))
                    .overlay {
                        RoundedRectangle(cornerRadius: Corner.md)
                            .stroke(Ink.fieldBorder, lineWidth: Metric.hairline)
                    }
                Button("加入", action: add)
                    .buttonStyle(DomyButtonStyle(compact: true))
                    .disabled(newTag.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    /// 一列標籤：名稱、幾筆、箭頭；點了改名
    private func tagRow(_ tag: String) -> some View {
        Button {
            renameText = tag
            renaming = tag
        } label: {
            HStack(spacing: Gap.s3) {
                Text("＃" + tag)
                    .font(Typo.body.font)
                    .foregroundStyle(Ink.textPrimary)
                Spacer()
                Text("\(counts[tag] ?? 0) 筆")
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Ink.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Ink.textTertiary)
                    .accessibilityHidden(true)
            }
            .frame(minHeight: Metric.touch)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
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
