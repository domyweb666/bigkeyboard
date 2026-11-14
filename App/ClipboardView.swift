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
        content
            .overlay(alignment: .bottomTrailing) {
                DomyAddButton(label: "新增", action: addNew)
                    .padding(.trailing, Metric.screenMargin)
                    .padding(.bottom, DomyTabBar.clearance)
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
                TagManagerView(tags: file.tags, counts: tagCounts) {
                    change($0)
                }
            }
            .alert("剪貼簿存不進去", isPresented: $saveFailed) {
                Button("好") {}
            } message: {
                Text("App 跟鍵盤共用的資料夾打不開，請截圖給開發者。")
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
            VStack(alignment: .leading, spacing: Gap.s4) {
                header
                DomySearchField(prompt: "搜尋文字", text: $search)
                filterRow
                if shown.isEmpty {
                    DomyEmptyState(
                        icon: file.entries.isEmpty ? "doc.on.clipboard" : nil,
                        title: file.entries.isEmpty ? "還沒有東西" : "找不到符合的",
                        message: file.entries.isEmpty ? Self.emptyHint : "換個關鍵字或篩選看看。"
                    )
                } else {
                    columns
                }
            }
            .padding(.horizontal, Metric.screenMargin)
            .padding(.top, Gap.s2)
        }
        .background(Brand.theme.canvas)
        .tabBarClearance()
    }

    /// 大標題，右邊是管理標籤的白底圓鈕
    private var header: some View {
        HStack(spacing: Gap.s3) {
            DomyTitle("剪貼簿")
            Button {
                managingTags = true
            } label: {
                Image(systemName: "tag")
                    .foregroundStyle(Brand.theme.accent)
                    .frame(width: Metric.iconButton, height: Metric.iconButton)
                    .background(Ink.surface, in: Circle())
                    .domyShadow(DomyTokens.Elevation.level1)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("管理標籤")
        }
    }

    // MARK: - 篩選

    /// 橫向一排，可以滑到螢幕邊緣外
    private var filterRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Gap.s2) {
                chip(.all, title: "全部")
                chip(.pinned, title: "固定", icon: "pin")
                ForEach(file.tags, id: \.self) { tag in
                    chip(.tag(tag), title: "＃" + tag)
                }
            }
            .padding(.horizontal, Metric.screenMargin)
        }
        .padding(.horizontal, -Metric.screenMargin)
    }

    private func chip(_ item: Filter, title: String, icon: String? = nil) -> some View {
        let selected = filter == item
        return Button {
            filter = item
        } label: {
            HStack(spacing: Gap.s1) {
                if let icon {
                    Image(systemName: icon)
                        .imageScale(.small)
                }
                Text(title)
            }
            .font(Typo.subheadline.font.weight(selected ? .semibold : .regular))
            .foregroundStyle(selected ? Brand.theme.onAccent : Ink.textPrimary)
            .padding(.horizontal, Gap.s4)
            .frame(minHeight: Metric.buttonCompact)
            .background(selected ? Brand.theme.accent : Ink.surface, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    // MARK: - 兩欄卡片

    /// 兩欄：每張放進目前估起來比較矮的那欄（像 Google Keep）
    private var columns: some View {
        let split = Self.split(shown)
        return HStack(alignment: .top, spacing: Gap.s2 + Gap.s1 / 2) {
            column(split[0])
            column(split[1])
        }
    }

    private func column(_ entries: [ClipboardHistory.Entry]) -> some View {
        LazyVStack(spacing: Gap.s2 + Gap.s1 / 2) {
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

    private static let emptyHint = "在別的 App 複製文字後，打字時按豆鍵工具列的剪貼簿鍵，就會存到這裡。"
        + "也可以按右下角的＋自己新增常用的文字。"

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

    /// 每個標籤有幾筆（管理標籤那頁顯示用）
    private var tagCounts: [String: Int] {
        var counts: [String: Int] = [:]
        for entry in file.entries {
            for tag in entry.tags {
                counts[tag, default: 0] += 1
            }
        }
        return counts
    }

    /// 按＋：開一筆還沒存的空白
    private func addNew() {
        editing = ClipboardHistory.Entry(id: UUID(), text: "", pinned: false, updated: Date(), manual: true)
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
        VStack(alignment: .leading, spacing: Gap.s2) {
            Text(entry.text)
                .font(Typo.subheadline.font)
                .foregroundStyle(Ink.textPrimary)
                .lineLimit(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.trailing, entry.pinned ? Gap.s4 : 0)
            if !entry.tags.isEmpty {
                DomyPill(text: entry.tags.map { "＃" + $0 }.joined(separator: " "))
            }
        }
        .padding(Gap.s3 + Gap.s1 / 2)
        .overlay(alignment: .topTrailing) {
            if entry.pinned {
                Image(systemName: "pin.fill")
                    .font(.caption2)
                    .foregroundStyle(Brand.theme.accent)
                    .padding(Gap.s3)
                    .accessibilityLabel("已固定")
            }
        }
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.lg))
        .contentShape(RoundedRectangle(cornerRadius: Corner.lg))
    }
}
