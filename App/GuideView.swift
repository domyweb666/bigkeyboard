import SwiftUI

/// 使用說明：加入鍵盤、讓豆鍵自動學詞、收鍵盤
struct GuideView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("加入鍵盤") {
                    Text("設定 → 一般 → 鍵盤 → 鍵盤 → 新增鍵盤 → 豆鍵")
                }
                Section("讓豆鍵自動學詞") {
                    Text("打開「允許完全取用」，豆鍵才能把你選出來的詞存進字典。")
                    Button("前往設定") {
                        AppSettings.open()
                    }
                }
                Section("照你的寫法排候選") {
                    Text("豆鍵會看游標前面的一兩個字，把你平常接在它後面打的字詞排在候選和聯想的最前面。")
                    Text("只記「前面一兩個字 → 你打了什麼」，整段文字不會存下來。")
                }
                Section("收起鍵盤") {
                    Text("鍵盤最上面中間有一條小橫條，從那排往下滑就收起來。")
                }
                Section("隱私") {
                    Text("豆鍵沒有連網功能，字典只存在這支手機上。")
                }
            }
            .navigationTitle("使用說明")
        }
    }
}
