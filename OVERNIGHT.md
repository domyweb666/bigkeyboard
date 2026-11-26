<!-- overnight: running -->
# Overnight 報告
## 早上摘要
（全部做完才寫）

## 任務清單
- [ ] 1. 小項性能修正（fb7e02c、fd69ca7）：Windows 引擎測試 regress（空字典、users 300）、abbr、last、tol、random 全過，結果跟改之前一樣
- [ ] 2. 小項性能修正：limrun Debug＋Release 編譯過；swiftformat、swiftlint（App、KeyboardExtension、Shared）0 個問題；模擬器看過候選列、展開候選、預覽泡泡、英文預測、剪貼簿卡片
- [ ] 3. App 端性能兩項：字典頁搜尋不再每個字重排、刪詞與回前景不在主執行緒寫檔；limrun 編譯＋格式過，模擬器字典頁搜尋、刪詞正常
- [ ] 4. 數字表情（1️⃣）組字中選它多吃後面的音：找出原因、修好、引擎測試加一條重現並通過
- [ ] 5. 查證：完全取用關著時鍵盤讀不讀得到 App 選的主題（查程式＋模擬器實測），結論寫進待確認
- [ ] 6. 收尾：limrun 自己開的機器全刪、早上摘要

不做（要多米開口或等真機）：推上去、打包 TestFlight、送審、AU14 標點問題、鄰鍵 base 調整、下一批功能。

## 待確認（需要多米決定的事）

## 卡住的項目

## 執行紀錄
- 11:04 從 perf-item4（fd69ca7）開 overnight-20261126-1104
