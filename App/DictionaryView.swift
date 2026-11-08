import StoreKit
import SwiftUI
import UIKit

/// 字典頁：自動學到的詞和手動加的詞，可篩選、搜尋、左滑刪除，右下角＋加詞
struct DictionaryView: View {
    enum Filter: CaseIterable {
        case all
        case auto
        case manual

        var title: String {
            switch self {
            case .all: "所有"
            case .auto: "自動添加"
            case .manual: "手動添加"
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
    @State private var filter = Filter.all
    @State private var search = ""
    @State private var adding = false
    /// 這次加詞視窗是按「加入」收起的（不是取消）
    @State private var justAdded = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            list
                .navigationTitle("字典")
                .searchable(text: $search, prompt: "搜尋字詞")
                .overlay(alignment: .bottomTrailing) {
                    addButton
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
        }
        .onAppear(perform: reload)
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
        guard ReviewPrompt.shouldAsk(autoWords: autoWords, keyboardSeen: file.keyboardSeen) else { return }
        ReviewPrompt.markAsked()
        requestReview()
    }

    private var list: some View {
        List {
            statusRow
            filterRow
            if file.words.isEmpty {
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
        }
        .listStyle(.plain)
        .overlay {
            if shown.isEmpty, !search.isEmpty {
                ContentUnavailableView.search(text: search)
            }
        }
    }

    /// 鍵盤寫過資料：顯示「自動學習中」；還沒：教你開完全取用
    @ViewBuilder private var statusRow: some View {
        if let seen = file.keyboardSeen {
            HStack(spacing: 8) {
                Circle()
                    .fill(Palette.teal)
                    .frame(width: 8, height: 8)
                Text("自動學習中・\(seen.formatted(.relative(presentation: .named)))更新")
            }
            .font(.subheadline)
            .foregroundStyle(Palette.statusText)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.statusBackground, in: RoundedRectangle(cornerRadius: 12))
            .listRowSeparator(.hidden)
        } else {
            FullAccessCard()
                .listRowSeparator(.hidden)
        }
    }

    private var filterRow: some View {
        HStack(spacing: 2) {
            ForEach(Filter.allCases, id: \.self) { item in
                Button {
                    filter = item
                } label: {
                    pill(item)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(Color(.systemGray6), in: Capsule())
        .listRowSeparator(.hidden)
    }

    private func pill(_ item: Filter) -> some View {
        let selected = filter == item
        return HStack(spacing: 4) {
            if let icon = item.icon {
                Image(systemName: icon)
                    .foregroundStyle(item == .auto ? Palette.teal : Color.secondary)
            }
            Text(item.title)
        }
        .font(.subheadline.weight(selected ? .semibold : .regular))
        .frame(maxWidth: .infinity, minHeight: 38)
        .background(selected ? Color(.systemBackground) : Color.clear, in: Capsule())
        .shadow(color: .black.opacity(selected ? 0.12 : 0), radius: 2, y: 1)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private var emptyRow: some View {
        VStack(spacing: 10) {
            Text("還沒有字詞")
                .font(.title3.weight(.bold))
            Text(Self.emptyHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .listRowSeparator(.hidden)
    }

    private var addButton: some View {
        Button {
            adding = true
        } label: {
            Image(systemName: "plus")
                .font(.title2.weight(.semibold))
                .foregroundStyle(Color(.systemBackground))
                .frame(width: 60, height: 60)
                .background(Color.primary, in: Circle())
                .shadow(color: .black.opacity(0.22), radius: 8, y: 4)
        }
        .accessibilityLabel("加詞")
        .padding(.trailing, 20)
        .padding(.bottom, 24)
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
        } else {
            saveFailed = true
            ReviewPrompt.hold()
        }
    }

    private func reload() {
        file = UserDictionary.load()
    }
}

/// 字典裡的一列：字、注音、來源
private struct WordRow: View {
    let word: UserDictionary.Word

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(word.text)
                    .font(.title3.weight(.medium))
                Text(word.displayReading)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Label {
                Text(word.source == .auto ? "自動" : "手動")
            } icon: {
                Image(systemName: word.source == .auto ? "sparkle" : "pencil")
                    .foregroundStyle(word.source == .auto ? Palette.teal : Color.secondary)
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
    }
}
