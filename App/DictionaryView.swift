import StoreKit
import SwiftUI

/// 字典頁：自動學到的詞和手動加的詞，可篩選、搜尋、左滑刪除，右下角＋加詞
struct DictionaryView: View {
    enum Filter: CaseIterable {
        case all
        case auto
        case manual

        var title: String {
            switch self {
            case .all: "所有"
            case .auto: "自動"
            case .manual: "手動"
            }
        }

        var icon: String? {
            switch self {
            case .all: nil
            case .auto: "sparkle"
            case .manual: "pencil"
            }
        }
    }

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.requestReview) private var requestReview
    @State private var file = UserDictionary.File()
    /// file.words 照新的在上面排好的一份：讀進字典時排一次，搜尋每打一個字只篩選、不重排
    @State private var newestFirst: [UserDictionary.Word] = []
    /// 還在背景寫的改動數：還有沒寫完的，先寫完的那次結果不換上畫面（不然連刪兩個，第二個會閃回來）
    @State private var pendingWrites = 0
    /// 鍵盤最後一次用到字典的時間
    @State private var keyboardSeen: Date?
    @State private var filter = Filter.all
    @State private var search = ""
    @State private var adding = false
    /// 這次加詞視窗是按「加入」收起的（不是取消）
    @State private var justAdded = false
    @State private var saveFailed = false

    var body: some View {
        list
            .overlay(alignment: .bottomTrailing) {
                DomyAddButton(label: "加詞") {
                    adding = true
                }
                .padding(.trailing, Metric.screenMargin)
                .padding(.bottom, DomyTabBar.clearance)
            }
            .sheet(isPresented: $adding, onDismiss: afterAdding) {
                AddWordView { text, reading in
                    change { $0.addManual(text, reading: reading) }
                    justAdded = true
                }
            }
            .alert("字典存不進去", isPresented: $saveFailed) {
                Button("好") {}
            } message: {
                Text("App 跟鍵盤共用的資料夾打不開，請截圖給開發者。")
            }
            .onAppear(perform: reload)
            .onReceive(NotificationCenter.default.publisher(for: DictionarySync.didChangeLocal)) { _ in
                reloadInBackground()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    reloadInBackground()
                }
            }
            // 字典頁出現（或從背景回來）停一下才問；切走分頁、進背景時 task 會被取消
            .task(id: scenePhase) {
                guard scenePhase == .active else { return }
                await askForReviewIfReady(after: .seconds(1.5))
            }
    }

    private func afterAdding() {
        guard justAdded else { return }
        justAdded = false
        Task { await askForReviewIfReady(after: .seconds(0.6)) }
    }

    /// 評分提示：條件見 ReviewPrompt；加詞視窗開著時不問
    private func askForReviewIfReady(after delay: Duration) async {
        try? await Task.sleep(for: delay)
        guard !Task.isCancelled, !adding else { return }
        let autoWords = file.words.filter { $0.source == .auto }.count
        guard ReviewPrompt.shouldAsk(autoWords: autoWords, keyboardSeen: keyboardSeen) else { return }
        ReviewPrompt.markAsked()
        requestReview()
    }

    /// 上半段（標題、搜尋、狀態、篩選）是透明底的列，下半段的詞是一張白卡；左滑刪除要 List 才有
    private var list: some View {
        let shown = shown
        return List {
            Section {
                DomyTitle("字典")
                DomySearchField(prompt: "搜尋字詞或注音", text: $search)
                statusRow
                filterRow
            }
            .listRowBackground(Color.clear)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: Gap.s2, leading: 0, bottom: Gap.s2, trailing: 0))
            Section {
                if shown.isEmpty {
                    emptyRow
                }
                ForEach(shown) { word in
                    WordRow(word: word)
                        .swipeActions {
                            Button("刪除", role: .destructive) {
                                change { $0.remove(word) }
                            }
                        }
                }
                .listRowBackground(Ink.surface)
                .listRowSeparatorTint(Ink.separator)
            }
        }
        .listStyle(.insetGrouped)
        .listSectionSpacing(Gap.s2)
        .scrollContentBackground(.hidden)
        .background(Brand.theme.canvas)
        .tabBarClearance()
    }

    /// 鍵盤寫過資料：顯示「自動學習中」；還沒：教你開完全取用
    @ViewBuilder private var statusRow: some View {
        if let seen = keyboardSeen {
            HStack(spacing: Gap.s2) {
                Circle()
                    .fill(Brand.theme.accent)
                    .frame(width: Gap.s2, height: Gap.s2)
                Text("**自動學習中**・\(seen.formatted(.relative(presentation: .named)))更新")
                    .font(Typo.subheadline.font)
                    .foregroundStyle(Brand.theme.strong)
                Spacer(minLength: Gap.s2)
                Text("\(file.words.count) 個詞")
                    .font(Typo.footnote.font)
                    .foregroundStyle(Ink.textSecondary)
            }
            .padding(.horizontal, Gap.s4)
            .padding(.vertical, Gap.s3)
            .background(Brand.theme.tint, in: RoundedRectangle(cornerRadius: Corner.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Corner.lg)
                    .stroke(Brand.theme.soft, lineWidth: Metric.hairline)
            }
        } else {
            FullAccessCard()
        }
    }

    private var filterRow: some View {
        HStack(spacing: Gap.s1 / 2) {
            ForEach(Filter.allCases, id: \.self) { item in
                Button {
                    filter = item
                } label: {
                    pill(item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(Gap.s1)
        .background(Ink.surfaceMuted, in: Capsule())
    }

    private func pill(_ item: Filter) -> some View {
        let selected = filter == item
        return HStack(spacing: Gap.s1) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .imageScale(.small)
                    .foregroundStyle(item == .auto ? Brand.theme.accent : Ink.textSecondary)
            }
            Text(item.title)
        }
        .font(Typo.subheadline.font.weight(selected ? .semibold : .regular))
        .foregroundStyle(selected ? Ink.textPrimary : Ink.textSecondary)
        .frame(maxWidth: .infinity, minHeight: Metric.buttonCompact)
        .background(selected ? Ink.surface : Color.clear, in: Capsule())
        .shadow(color: Ink.shadow.opacity(selected ? 0.1 : 0), radius: 3, y: 1)
        .contentShape(Capsule())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var emptyRow: some View {
        DomyEmptyState(
            icon: file.words.isEmpty ? "book" : nil,
            title: file.words.isEmpty ? "還沒有字詞" : "找不到符合的",
            message: file.words.isEmpty ? Self.emptyHint : "換個關鍵字或篩選看看。"
        )
        .listRowBackground(Color.clear)
        .listRowSeparator(.hidden)
    }

    /// 篩選＋搜尋後要顯示的詞，新的在上面
    private var shown: [UserDictionary.Word] {
        let query = search.trimmingCharacters(in: .whitespaces)
        return newestFirst.filter { word in
            let kept = switch filter {
            case .all: true
            case .auto: word.source == .auto
            case .manual: word.source == .manual
            }
            return kept && (query.isEmpty || word.text.contains(query) || word.displayReading.contains(query))
        }
    }

    private static let emptyHint = "你在鍵盤上一個字一個字選出來的詞，豆鍵會記下來，"
        + "下次直接排在候選第一個。也可以按右下角的＋自己加。"

    /// 畫面先照改好的樣子換掉（左滑刪詞馬上消失），讀檔、寫檔、同步排到背景
    private func change(_ edit: @escaping (inout UserDictionary.File) -> Void) {
        var shownNow = file
        edit(&shownNow)
        show(shownNow, sorted: Self.newestFirst(shownNow.words))
        pendingWrites += 1
        DictionarySync.fileQueue.async {
            // 寫檔前重讀一次：鍵盤這段時間可能寫過，edit 套在最新的那份上
            let written = UserDictionary.updatedFile(edit)
            let sorted = written.map { Self.newestFirst($0.words) }
            DispatchQueue.main.async {
                pendingWrites -= 1
                if let written, let sorted {
                    if pendingWrites == 0 {
                        show(written, sorted: sorted)
                    }
                    DictionarySync.sync()
                } else {
                    saveFailed = true
                    ReviewPrompt.hold()
                    reloadInBackground()
                }
            }
        }
    }

    /// 頁面出現時直接讀（不然會先閃一下「還沒有字詞」）
    private func reload() {
        let loaded = UserDictionary.load()
        show(loaded, sorted: Self.newestFirst(loaded.words))
    }

    /// 回到前景、iCloud 合併後：排在還沒寫完的檔後面讀，讀好再換畫面
    private func reloadInBackground() {
        DictionarySync.fileQueue.async {
            let loaded = UserDictionary.load()
            let sorted = Self.newestFirst(loaded.words)
            DispatchQueue.main.async {
                // 讀完之後又改了詞：等那次寫完的結果
                if pendingWrites == 0 {
                    show(loaded, sorted: sorted)
                }
            }
        }
    }

    private func show(_ loaded: UserDictionary.File, sorted: [UserDictionary.Word]) {
        file = loaded
        newestFirst = sorted
        keyboardSeen = KeyboardSeen.date(in: loaded)
    }

    private static func newestFirst(_ words: [UserDictionary.Word]) -> [UserDictionary.Word] {
        words.sorted { $0.updated > $1.updated }
    }
}

/// 字典裡的一列：字、注音、來源
private struct WordRow: View {
    let word: UserDictionary.Word

    var body: some View {
        HStack(spacing: Gap.s3) {
            VStack(alignment: .leading, spacing: Gap.s1 / 2) {
                Text(word.text)
                    .font(Typo.title3.font.weight(.medium))
                    .foregroundStyle(Ink.textPrimary)
                Text(word.displayReading)
                    .font(Typo.footnote.font)
                    .foregroundStyle(Ink.textSecondary)
            }
            Spacer()
            if word.source == .auto {
                DomyPill(text: "自動", icon: "sparkle")
            } else {
                DomyPill(text: "手動", icon: "pencil", tone: .muted)
            }
        }
        .padding(.vertical, Gap.s1 + Gap.s1 / 2)
    }
}
