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
                reload()
            }
            .onChange(of: scenePhase) {
                if scenePhase == .active {
                    reload()
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
        List {
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
        return file.words
            .filter { word in
                switch filter {
                case .all: true
                case .auto: word.source == .auto
                case .manual: word.source == .manual
                }
            }
            .filter { query.isEmpty || $0.text.contains(query) || $0.displayReading.contains(query) }
            .sorted { $0.updated > $1.updated }
    }

    private static let emptyHint = "你在鍵盤上一個字一個字選出來的詞，豆鍵會記下來，"
        + "下次直接排在候選第一個。也可以按右下角的＋自己加。"

    private func change(_ edit: (inout UserDictionary.File) -> Void) {
        if UserDictionary.update(edit) {
            reload()
            DictionarySync.sync()
        } else {
            saveFailed = true
            ReviewPrompt.hold()
        }
    }

    private func reload() {
        file = UserDictionary.load()
        keyboardSeen = KeyboardSeen.date(in: file)
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
