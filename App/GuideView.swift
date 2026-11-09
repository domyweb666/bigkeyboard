import SwiftUI

/// 使用說明：加入鍵盤、讓豆鍵自動學詞、收鍵盤
struct GuideView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("加入鍵盤") {
                    Text("設定 → 一般 → 鍵盤 → 鍵盤 → 新增鍵盤 → 豆鍵")
                }
                Section("不開完全取用也能用") {
                    Text("加入鍵盤後就能打注音、選候選字和聯想詞，也能切英文、符號、數字鍵盤。")
                    Text("「允許完全取用」可以不開。")
                }
                Section("讓豆鍵自動學詞（選用）") {
                    Text("打開「允許完全取用」，豆鍵才能把你選出來的詞存進字典，也才換得了主題、存得了剪貼簿。")
                    Button("前往設定") {
                        AppSettings.open()
                    }
                }
                Section("照你的寫法排候選") {
                    Text("豆鍵會看游標前面的一兩個字，把你平常接在它後面打的字詞排在候選和聯想的最前面。")
                    Text("只記「前面一兩個字 → 你打了什麼」，整段文字不會存下來。")
                }
                Section("收起鍵盤") {
                    Text("注音鍵盤：點候選列最右邊那顆鍵盤圖示。")
                    Text("英文、符號、數字鍵盤：按住換行鍵（鍵上有個小 ⌄）。")
                }
                Section("表情符號") {
                    Text("按住左下角的地球鍵，選「表情符號」，就是 iPhone 原本的表情鍵盤（可以搜尋、選膚色）。")
                    Text("選完按地球鍵就回到豆鍵。")
                }
                Section("隱私") {
                    Text("豆鍵沒有連網功能，字典只存在這支手機上。")
                }
                if let url = ReviewPrompt.writeReviewURL {
                    Section("喜歡豆鍵的話") {
                        Link(destination: url) {
                            HStack {
                                Text("到 App Store 寫評論")
                                Spacer()
                                Image(systemName: "arrow.up.right")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }
                }
            }
            .navigationTitle("使用說明")
        }
    }
}
