import SwiftUI
import UIKit

/// 剪貼簿頁（簡化版 Google Keep）：鍵盤存下來的文字和自己新增的素材，兩欄卡片。
/// 可搜尋、照標籤篩選；點卡片編輯（改字、標籤、固定、刪除）；右下角＋新增；右上角管理標籤
struct ClipboardView: View {
    enum Filter: Hashable {
        case all
        case pinned
        case tag(String)
    }

    @Environment(\.scenePhase) private var scenePhase
    @State private var file = ClipboardHistory.File()
    @State private var filter = Filter.all
    @State private var search = ""
    /// 正在編輯的那筆；新增時是一筆還沒存的空白
    @State private var editing: ClipboardHistory.Entry?
    @State private var managingTags = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("剪貼簿")
                .searchable(text: $search, prompt: "搜尋文字")
                .toolbar {
                    Button {
                        managingTags = true
                    } label: {
                        Label("管理標籤", systemImage: "tag")
                    }
                }
                .overlay(alignment: .bottomTrailing) {
                    addButton
                }
                .sheet(item: $editing) { entry in
                    NoteEditorView(
                        entry: entry,
                        isNew: !file.entries.contains { $0.id == entry.id },
                        allTags: file.tags
                    ) {
                        change($0)
                    }
                }
                .sheet(isPresented: $managingTags) {
                    TagManagerView(tags: file.tags) {
                        change($0)
                    }
                }
                .alert("剪貼簿存不進去", isPresented: $saveFailed) {
                    Button("好") {}
                } message: {
                    Text("App 跟鍵盤共用的資料夾打不開，請截圖給開發者。")
                }
        }
        .onAppear(perform: reload)
        .onChange(of: scenePhase) {
            if scenePhase == .active {
                reload()
            }
        }
    }

    private var content: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                filterRow
                if shown.isEmpty {
                    emptyView
                } else {
                    columns
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 96)
        }
    }

    // MARK: - 篩選

    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                chip(.all, title: "全部")
                chip(.pinned, title: "固定")
                ForEach(file.tags, id: \.self) { tag in
                    chip(.tag(tag), title: "＃" + tag)
                }
            }
        }
    }

    private func chip(_ item: Filter, title: String) -> some View {
        let selected = filter == item
        return Button {
            filter = item
        } label: {
            Text(title)
                .font(.subheadline.weight(selected ? .semibold : .regular))
                .padding(.horizontal, 14)
                .frame(minHeight: 34)
                .background(selected ? Color.primary.opacity(0.1) : Color.clear, in: Capsule())
                .overlay(Capsule().stroke(Color.secondary.opacity(0.4), lineWidth: selected ? 0 : 0.5))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 兩欄卡片

    /// 兩欄：每張放進目前估起來比較矮的那欄（像 Google Keep）
    private var columns: some View {
        let split = Self.split(shown)
        return HStack(alignment: .top, spacing: 8) {
            column(split[0])
            column(split[1])
        }
    }

    private func column(_ entries: [ClipboardHistory.Entry]) -> some View {
        LazyVStack(spacing: 8) {
            ForEach(entries) { entry in
                NoteCard(entry: entry)
                    .onTapGesture {
                        editing = entry
                    }
                    .contextMenu {
                        cardMenu(entry)
                    }
            }
        }
        .frame(maxWidth: .infinity, alignment: .top)
    }

    @ViewBuilder private func cardMenu(_ entry: ClipboardHistory.Entry) -> some View {
        Button {
            UIPasteboard.general.string = entry.text
        } label: {
            Label("複製", systemImage: "doc.on.doc")
        }
        Button {
            change { $0.togglePin(entry.id) }
        } label: {
            Label(entry.pinned ? "取消固定" : "固定", systemImage: entry.pinned ? "pin.slash" : "pin")
        }
        Button(role: .destructive) {
            change { $0.remove(entry.id) }
        } label: {
            Label("刪除", systemImage: "trash")
        }
    }

    /// 估每張卡片的高：字數換算成行數（最多 8 行），有標籤多一行
    private static func split(_ entries: [ClipboardHistory.Entry]) -> [[ClipboardHistory.Entry]] {
        var out: [[ClipboardHistory.Entry]] = [[], []]
        var heights = [0, 0]
        for entry in entries {
            let lines = min(8, entry.text.count / 10 + 1) + (entry.tags.isEmpty ? 0 : 1) + 2
            let column = heights[0] <= heights[1] ? 0 : 1
            out[column].append(entry)
            heights[column] += lines
        }
        return out
    }

    private var emptyView: some View {
        VStack(spacing: 10) {
            Text(file.entries.isEmpty ? "還沒有東西" : "找不到符合的")
                .font(.title3.weight(.bold))
            Text(file.entries.isEmpty ? Self.emptyHint : "換個關鍵字或篩選看看。")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }

    private static let emptyHint = "在別的 App 複製文字後，打字時按豆鍵工具列的剪貼簿鍵，就會存到這裡。"
        + "也可以按右下角的＋自己新增常用的文字。"

    private var addButton: some View {
        Button {
            editing = ClipboardHistory.Entry(id: UUID(), text: "", pinned: false, updated: Date(), manual: true)
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 60, height: 60)
                .background(Color.primary, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        }
        .accessibilityLabel("新增")
        .padding(.trailing, 20)
        .padding(.bottom, 24)
    }

    // MARK: - 資料

    /// 篩選＋搜尋後要顯示的，固定的在上面、新的在前
    private var shown: [ClipboardHistory.Entry] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return file.sorted.filter { entry in
            let matches = switch filter {
            case .all: true
            case .pinned: entry.pinned
            case let .tag(name): entry.tags.contains(name)
            }
            return matches && (query.isEmpty || entry.text.localizedCaseInsensitiveContains(query))
        }
    }

    private func change(_ edit: (inout ClipboardHistory.File) -> Void) {
        if ClipboardHistory.update(edit) == nil {
            saveFailed = true
        }
        reload()
    }

    private func reload() {
        file = ClipboardHistory.load()
        if case let .tag(name) = filter, !file.tags.contains(name) {
            filter = .all
        }
    }
}

/// 一張卡片：文字最多 8 行，下面標籤，固定的右上角有圖釘
private struct NoteCard: View {
    let entry: ClipboardHistory.Entry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(entry.text)
                .font(.subheadline)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, entry.pinned ? 14 : 0)
            if !entry.tags.isEmpty {
                Text(entry.tags.map { "＃" + $0 }.joined(separator: " "))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .overlay(alignment: .topTrailing) {
            if entry.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(8)
                    .accessibilityLabel("已固定")
            }
        }
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .contentShape(RoundedRectangle(cornerRadius: 12))
    }
}
