import SwiftUI
import UIKit

/// 加詞：輸入詞，注音照詞庫自動帶出，多音字點一下換讀音
struct AddWordView: View {
    /// 按「加入」時呼叫：(詞, 讀音)，讀音用小麥詞庫的格式（音節以 - 連接）
    let onSave: (String, String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var text = ""
    @State private var lookup = ReadingLookup.Result()
    @State private var picks: [Int] = []

    init(onSave: @escaping (String, String) -> Void) {
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("詞") {
                    TextField("例如：茄記", text: $text)
                        .font(.title3)
                }
                if !chars.isEmpty {
                    Section {
                        chips
                    } header: {
                        Text("注音")
                    } footer: {
                        Text(footer)
                    }
                }
            }
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

    private var footer: String {
        if let missing = syllables.firstIndex(of: ""), missing < chars.count {
            return "「\(chars[missing])」在詞庫裡查不到讀音，不能加。"
        }
        return "以後打 \(syllables.joined(separator: " "))，候選第一個就是「\(word)」。"
            + "多音字點一下可以換讀音。"
    }

    private var chips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(Array(chars.enumerated()), id: \.offset) { i, c in
                    chip(at: i, char: c)
                }
            }
            .padding(.vertical, 6)
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
            VStack(spacing: 4) {
                Text(c)
                    .font(.title2)
                    .foregroundStyle(Color.primary)
                HStack(spacing: 2) {
                    Text(current.isEmpty ? "查不到" : current)
                    if list.count > 1 {
                        Image(systemName: "chevron.down")
                            .font(.caption2)
                    }
                }
                .font(.subheadline)
                .foregroundStyle(current.isEmpty ? Palette.danger : Color.primary)
            }
            .frame(width: 84, height: 72)
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color(.systemGray3))
            }
        }
    }
}
