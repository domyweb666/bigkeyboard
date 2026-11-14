import SwiftUI

/// 加詞：輸入詞，注音照詞庫自動帶出，多音字點一下換讀音
struct AddWordView: View {
    /// 按「加入」時呼叫：(詞, 讀音)，讀音用小麥詞庫的格式（音節以 - 連接）
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @FocusState private var typing: Bool
    @State private var text = ""
    @State private var lookup = ReadingLookup.Result()
    @State private var picks: [Int] = []

    init(onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Gap.s6) {
                    wordField
                    if !chars.isEmpty {
                        readingSection
                    }
                }
                .padding(.horizontal, Metric.screenMargin)
                .padding(.vertical, Gap.s4)
            }
            .background(Brand.theme.canvas)
            .navigationTitle("加入字典")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("加入") {
                        onSave(word, syllables.joined(separator: "-"))
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .onChange(of: text) {
                lookup = ReadingLookup.lookup(word)
                picks = Array(repeating: 0, count: lookup.options.count)
            }
        }
        .tint(Brand.theme.strong)
    }

    /// 去掉前後空白的詞
    private var word: String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var chars: [String] {
        word.map(String.init)
    }

    /// 每個字目前選的讀音；查不到的字是空字串
    private var syllables: [String] {
        lookup.options.enumerated().map { i, list in
            let p = i < picks.count ? picks[i] : 0
            return list.indices.contains(p) ? list[p] : ""
        }
    }

    private var canSave: Bool {
        !chars.isEmpty && syllables.count == chars.count && !syllables.contains("")
    }

    /// 有字在詞庫裡查不到讀音
    private var hasMissing: Bool {
        syllables.contains("")
    }

    private var footer: String {
        if let missing = syllables.firstIndex(of: ""), missing < chars.count {
            return "「\(chars[missing])」在詞庫裡查不到讀音，不能加。"
        }
        return "以後打 \(syllables.joined(separator: " "))，候選第一個就是「\(word)」。"
            + "多音字點一下可以換讀音。"
    }

    private var wordField: some View {
        VStack(alignment: .leading, spacing: Gap.s2) {
            Text("詞")
                .font(Typo.subheadline.font.weight(.semibold))
                .foregroundStyle(Ink.textPrimary)
            TextField("例如：茄記", text: $text)
                .font(Typo.title3.font.weight(.regular))
                .foregroundStyle(Ink.textPrimary)
                .focused($typing)
                .accessibilityLabel("詞")
                .padding(.horizontal, Gap.s4)
                .frame(minHeight: Metric.button)
                .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.md))
                .overlay {
                    RoundedRectangle(cornerRadius: Corner.md)
                        .stroke(
                            typing ? Brand.theme.accent : Ink.fieldBorder,
                            lineWidth: typing ? Metric.hairline * 1.5 : Metric.hairline
                        )
                }
            Text("打完詞，注音會從詞庫自動帶出來。")
                .font(Typo.footnote.font)
                .foregroundStyle(Ink.textSecondary)
        }
    }

    private var readingSection: some View {
        VStack(alignment: .leading, spacing: Gap.s2) {
            Text("注音")
                .font(Typo.subheadline.font.weight(.semibold))
                .foregroundStyle(Ink.textPrimary)
            chips
            hint
                .padding(.top, Gap.s2)
        }
    }

    /// 查不到讀音：紅字說哪個字不能加；查得到：說以後怎麼打
    @ViewBuilder private var hint: some View {
        if hasMissing {
            Label(footer, systemImage: "exclamationmark.circle")
                .font(Typo.footnote.font)
                .foregroundStyle(Ink.destructive)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: Gap.s2) {
                Image(systemName: "sparkle")
                    .foregroundStyle(Brand.theme.accent)
                    .accessibilityHidden(true)
                Text(footer)
                    .foregroundStyle(Brand.theme.strong)
            }
            .font(Typo.subheadline.font)
            .padding(.horizontal, Gap.s4)
            .padding(.vertical, Gap.s3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Brand.theme.tint, in: RoundedRectangle(cornerRadius: Corner.lg))
            .overlay {
                RoundedRectangle(cornerRadius: Corner.lg)
                    .stroke(Brand.theme.soft, lineWidth: Metric.hairline)
            }
        }
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Gap.s2 + Gap.s1 / 2) {
                ForEach(Array(chars.enumerated()), id: \.offset) { i, c in
                    chip(at: i, char: c)
                }
            }
            .padding(.vertical, Gap.s1)
        }
    }

    /// 一個字的讀音按鈕：點開選讀音（多音字才有箭頭）
    private func chip(at i: Int, char c: String) -> some View {
        let list = i < lookup.options.count ? lookup.options[i] : []
        let current = i < syllables.count ? syllables[i] : ""
        return Menu {
            ForEach(Array(list.enumerated()), id: \.offset) { j, option in
                Button {
                    if i < picks.count {
                        picks[i] = j
                    }
                } label: {
                    if option == current {
                        Label(option, systemImage: "checkmark")
                    } else {
                        Text(option)
                    }
                }
            }
        } label: {
            chipLabel(char: c, reading: current, choices: list.count)
        }
    }

    /// 讀音按鈕的長相：上面是字，下面是讀音。多音字的讀音放在產品色膠囊裡加箭頭，查不到的整顆紅框
    private func chipLabel(char c: String, reading: String, choices: Int) -> some View {
        let missing = reading.isEmpty
        let multi = choices > 1
        let readingColor = if missing {
            Ink.destructive
        } else if multi {
            Brand.theme.strong
        } else {
            Ink.textPrimary
        }
        return VStack(spacing: Gap.s1) {
            Text(c)
                .font(Typo.title1.font.weight(.regular))
                .foregroundStyle(Ink.textPrimary)
            HStack(spacing: Gap.s1 / 2) {
                Text(missing ? "查不到" : reading)
                if multi {
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                }
            }
            .font(Typo.subheadline.font.weight(multi || missing ? .semibold : .regular))
            .foregroundStyle(readingColor)
            .padding(.horizontal, multi ? Gap.s2 : 0)
            .padding(.vertical, Gap.s1 / 2)
            .background(multi ? Brand.theme.soft : Color.clear, in: Capsule())
        }
        .frame(width: Gap.s12 * 2, height: Gap.s12 * 2)
        .background(Ink.surface, in: RoundedRectangle(cornerRadius: Corner.lg))
        .overlay {
            RoundedRectangle(cornerRadius: Corner.lg)
                .stroke(
                    missing ? Ink.destructive : Ink.separator,
                    lineWidth: missing ? Metric.hairline * 1.5 : Metric.hairline
                )
        }
    }
}
