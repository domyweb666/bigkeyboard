# Handoff: 豆鍵鍵盤排版改版、真機回饋修正、Typeless 式字典與拖曳收鍵盤（build 39–41）

> 產出時間：2026-11-02 04:36
> 前一會話的最後狀態，給下一個會話接續用

## ✅ 這次完成了什麼

- 排版改版（build 39）：注音分區底色（介音 ㄧㄨㄩ 淡藍、韻母淡暖、聲調淡灰且字放大加粗）、長按小字加深、底排拿掉 123 改長按「符」／「!#1」、空白 4.3 換行 1.6、候選列右端淡出；英文鍵面同步（數字列淡灰、底排同款）
- 真機回饋修正（build 40）：鍵盤底改透明＋冷灰鍵帽（iOS 26 系統在鍵盤上方與底部系統排畫自己的底色 #E2E3E7，擴充畫不到）；鍵盤區 hitTest 找最近的鍵（排與排之間的縫不再沒反應）；快打 rollover（下一顆按下時上一顆先送出）；候選列最多 30 個；關掉視窗手勢的觸控延後；PrimaryLanguage 改 mul（切換選單去掉「中文」）
- 字典（build 41）：App Group `group.org.domyweb.bigkeyboard` 共用 `dictionary.json`；RequestsOpenAccess 改 true；引擎併入使用者詞（分數 0，同讀音排最前）、選字記下帶聲調的讀音；鍵盤自動學詞；App 改成兩個分頁「字典」「使用說明」，字典頁有篩選、搜尋、左滑刪除、＋加詞（注音從鍵盤擴充裡的詞庫自動帶出）
- 鍵盤頂端中間拖曳條（build 41）：從候選列或最上緣往下滑收起鍵盤，不佔空間
- 多米在 Apple 開發者網站登記了 App Group 並掛到兩個 App ID（build 41 簽章因此才過）
- Design 畫布：https://claude.ai/artifact/Js9H8aEaZpADnto4CgwPMe（「鍵盤」頁：現況、A、B、B 深色、英文；「字典」頁：列表、第一次打開、加詞）
- 文件：產品定稿（配色例外、開完全取用、字典、拖曳條）、總測試清單 I／J／K 段、審查紀錄、lessons、切片帳本 D1–D5

## 🚧 還沒做完 / 待決定

- build 39、40、41 全部還沒真機驗：總測試清單 I、J、K 段都等多米回報
- 深色配色是估的（系統深色底的實際顏色不知道）— 要多米深色模式截圖再調 `SamsungTheme`
- `PrimaryLanguage: mul` 會不會讓選單只剩「豆鍵」、系統麥克風聽寫還是不是中文 — Apple 文件沒寫，待真機
- 邊緣觸控延後的修法（window 手勢 delaysTouchesBegan/Ended = false）是論壇做法 — 待真機確認最左最右的鍵有沒有變跟手
- 單字選擇的自動學沒做 — 要看前一個字才判斷（類似小麥的 UserOverrideModel），等詞的部分穩了再加
- 完全取用沒開時鍵盤讀不讀得到 App Group（論壇說可讀不可寫）— 未驗
- App 加完詞，鍵盤要收起再叫出來才讀到（只在 viewWillAppear 讀字典）— 多米覺得不順再改

## 📌 關鍵決策（這次定下來的，下次別再爭論）

- 鍵盤上方灰框拿不掉 → 鍵盤底透明、共用系統底色，鍵帽改冷灰系（多米同意換配色）
- 字典走 A：開「允許完全取用」；鍵盤仍然一行連網程式都沒有
- 自動學只學兩種：全部單字逐字選出、至少一次選了非第一個、中間沒再打注音的 2–6 字詞；選了非第一個的多字詞。單字不學；在 App 刪掉的自動詞記進 ignored，不再學回來
- 123 數字鍵盤收進「符」／「!#1」長按；符號頁的 123 鍵保留
- 注音分區底色保留（偏離三星原稿，產品定稿已記例外）
- App 底部兩個分頁：字典、使用說明
- 拖曳條疊在頂端不佔空間；只接從頂端開始、往下的滑動，不影響候選列左右滑和打字
- 寫字典檔不用 NSFileCoordinator（避免鍵盤被鎖住），一律讀出→改→原子寫回；鍵盤寫入放背景 queue

## 📂 下個會話最重要的檔案

- `.vibe/總測試清單.md`  ← I／J／K 段是等多米回報的測試項
- `.vibe/產品定稿.md`、`.vibe/切片帳本.md`、`.vibe/規矩檔.md`
- `.uiux/審查紀錄.md`、`.uiux/lessons.md`
- `Shared/UserDictionary.swift`  ← App 與鍵盤共用的字典讀寫
- `KeyboardExtension/Engine/Bridge/BopomofoEngine.mm`  ← FuzzyToneLM 併使用者詞、CachedCandidate、setUserPhrases
- `KeyboardExtension/KeyboardViewController+Dictionary.swift`  ← 自動學詞
- `KeyboardExtension/KeyboardViewController+Dismiss.swift`  ← 拖曳條
- `KeyboardExtension/Views/KeyboardView.swift`（hitTest、rollover）、`KeyButton.swift`（fireNow）、`CandidateBar.swift`（遮罩淡出、上限 30）
- `KeyboardExtension/Layout/SamsungTheme.swift`  ← 透明底、冷灰配色、深色值
- `App/DictionaryView.swift`、`App/AddWordView.swift`、`App/ReadingLookup.swift`、`App/GuideView.swift`、`App/FullAccessCard.swift`
- `project.yml`  ← App Group entitlements、Shared 資料夾、RequestsOpenAccess、PrimaryLanguage

## ⏭️ 下一步從哪繼續

1. 先讀 `.vibe/HANDOFF.md`（就是這份）和 `.vibe/規矩檔.md`
2. 等多米回報 build 41 的真機結果（總測試清單 I、J、K 段）。回報前不要自己加功能
3. 多米回報問題 → 看截圖，對照上面的檔案修；修完照下面「CI 地雷」推上去編 build
4. 多米給深色截圖 → 調 `SamsungTheme.swift` 的深色值
5. 測過的項目：總測試清單打勾、切片帳本 D1–D5 標成已驗

### CI 地雷（這次踩過，推之前先避開）

- CI 先跑 `swiftformat --lint` 和 `swiftlint lint --strict`，警告也算失敗
- 單行 `if` 主體會被擋（要換行）；`//` 註解緊貼在 `///` 文件註解上面會被擋（中間空一行）
- 一行最多 120 欄，中文字算 2 欄
- 函式 cyclomatic complexity 超過 10 會被擋（拆成小函式）
- 簡單取屬性用 key path：`map(\.text)`；多行 `forEach` 改 for 迴圈
- 最後一個 commit 帶 `[skip ci]` 會讓整次 push 都不編：文件 commit 放前面、程式 commit 放最後，或用 `gh workflow run testflight.yml --repo domyweb666/bigkeyboard --ref main` 手動觸發
- 改完 Apple 開發者網站的設定後，第一次 build 可能出現「The data couldn’t be read」，重跑就好

## 🗑️ 這次會話的雜訊（下次別重新討論）

- 灰框能不能畫過去 — Apple 論壇已確認擴充畫不到，別再試
- `mul` 的顯示方式查不到文件 — 已改，等真機看結果就好
- NSFileCoordinator 要不要用 — 已決定不用
- 小麥 UserOverrideModel 整套搬進來 — 這次沒搬，單字記憶要做時再評估
