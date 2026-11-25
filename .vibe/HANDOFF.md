# Handoff: 按鍵聲加四套 AI 生成的聲音（豆子落碗、木魚、打字機、筆電鍵盤），編譯過了，等升版本號打包 TestFlight

> 產出時間：2026-11-21 21:01
> 前一會話的最後狀態，給下一個會話接續用


## 🆕 2026-11-22 追加（這份之後又做的）

- 多米回報：按鍵聲怪、快打有些鍵沒聲音、選候選字沒回饋。三件都改了，細節在 `.vibe/產品定稿.md` 第 20 項最後一條，測試項 AR12–AR16
- `KeySoundPlayer` 改用 AVAudioEngine（ambient、8 個播放器輪流、載入時同類對齊音量）；候選列、展開候選選字時 `candidateFeedback()` 響一聲＋震一下
- 雲端沒有 Xcode：只跑過 SwiftFormat 0.64.7、SwiftLint 0.65.1（全過），沒編譯、沒真機。下一步：多米開口後跑 testflight 工作流程（分支 redesign-domy-sage），編譯錯誤在那裡才會看到

- 2026-11-23：1.2.2 (90) 已提交審查（`.aso/1.2.2-送審稿.md`），下次先查審查結果，別再送。下面「還沒打包」「真機沒聽過」是 11/21 的狀態，已過時。repo 當天改成公開
- 2026-11-25：手感審查（`.uiux/審查紀錄.md` 最後一段）。做了：進觸控板的震動提前叫醒、「鍵盤有在用」的時間搬出字典檔（`Shared/KeyboardSeen.swift`）、字典檔不排版、叫出鍵盤分段計時（`Shared/OpenTiming.swift`，設定頁長按版本號複製）。模擬器驗過。接著把讀音檔、開音訊移到背景（`Shared/KeySoundPlayer.swift`），模擬器上選聲音包時擋住鍵盤的時間 118～177 → 9～10 毫秒。1.2.3 (91) 2026-11-25 上傳 TestFlight（run 45476367270），還沒送審；1.2.2 已上線。下一步：等多米做 AT1～AT12；模擬器上記憶體每叫出一次多 3～9 MB，原因沒查，看 AT1 的真機數字；#3 看 AT7
- 2026-11-25 晚：容錯四項（連刪保護、簡拼、iOS 替代文字、鄰鍵容錯）做完，在分支 `tolerance-1.3`（只在本機，沒推、沒打包、沒併回 redesign-domy-sage）。規格與數字 `.vibe/容錯四項-規格.md`，緣由 `.vibe/JTBD對照-2026-11-25.md`，真機測試 AU 段。引擎核心搬到 `KeyboardExtension/Engine/Bridge/*.h`（純 C++），本機測試程式在 `docs/engine-test/`（說明見裡面的 README）。下一步：多米決定什麼時候打包；1.2.3 (91) 的 AT 還沒回，先等那組數字

## ✅ 這次完成了什麼

- 試了 Higgsfield（Mirelo 模型）和 ElevenLabs 生成鍵盤聲，兩邊比較後放進 App 的只用 ElevenLabs 的
- 在 ElevenLabs 音效頁生成 11 種、每種 4 個版本，全部下載成 WAV（花 440 點）；帳號的「分享到 Explore」已停用
- 挑四種加進按鍵聲選單：豆子落碗 beans、木魚 woodblock、打字機 typewriter、筆電鍵盤 laptop，68 個檔 1.4 MB（commit 2c7f0dc）
- 寫 `docs/make_ai_keysounds.py`：切單聲、篩掉重疊／沒收乾淨／太小聲／開頭有雜音／起音慢的、開頭切到撞擊前 1 毫秒、不足 12 聲用變調補、大鍵降四個半音
- 這四套只有按下聲，手指離開不出聲（`KeySoundPlayer` 找不到彈回聲就不播，程式只改了兩個 switch 加新選項）
- 使用說明（`App/GuideView.swift`）加一句介紹四種新聲音
- 授權與來源寫進 `THIRD_PARTY_LICENSES.md`、`.vibe/機械鍵盤聲音-音檔來源.md` 的「AI 生成」段
- limrun 上編譯成功、swiftformat／swiftlint（App、KeyboardExtension、Shared）全過；模擬器選單看得到四個新選項，選「木魚」不會當掉。機器已刪、清單是空的
- 查到 1.2.1 已上線（App Store 公開資料，2026-11-17 發布），記進 `.aso/閘門紀錄.md`
- `試聽-AI鍵盤聲/` 加進 `.gitignore`（全部原檔、Mirelo 那批、試聽頁都在這，約 30 MB，只在這台電腦）

## 🚧 還沒做完 / 待決定

- 還沒打包 TestFlight：多米 2026-11-21 定下一版是 1.2.2，`project.yml` 已改好；小版號照慣例不加 `WhatsNew.swift` 卡片
- 四套聲音沒有人聽過真機：Claude 聽不到聲音，是照量測和定位挑的。好不好聽、跟不跟手、要不要換掉哪一套，等多米真機回報
- 四套要不要收費，跟機械鍵盤聲一樣還沒定
- ElevenLabs 帳號是 Starter 方案，訂閱頁寫「將於 12 月 11 日取消」。已生成的聲音照理可繼續商用，但條款原文沒查，取消前最好確認
- 上一份 handoff 留下的幾條還沒有回音：「跟隨 iPhone 設定」沒聲音的問題、機械鍵盤彈回聲的回饋、使用說明頁要不要拿掉

## 📌 關鍵決策（這次定下來的，下次別再爭論）

- 進 App 的只用 ElevenLabs 生成的。Mirelo 照描述做的程度差，模型目錄又標「Game pipeline only」、授權查不到
- 不挑清脆機械、厚實 thock、老式彈簧（跟現有三套真錄音重疊），也不挑玻璃杯、撲克籌碼、泡泡紙（只切出 4 聲，變調補太多會聽出重複）
- AI 生成的聲音只做按下聲，不硬切彈回聲
- 每一聲 1 毫秒內出聲、到一半音量 25 毫秒以內，起音慢的直接丟掉（第一次產出有的檔要 26 毫秒才出聲，已修）
- TestFlight 是 GitHub Actions 的 testflight 工作流程，從 `redesign-domy-sage` 手動執行（workflow_dispatch），不是 limrun；推這個分支不會觸發任何工作流程。照規矩沒有多米開口不打包

## 📂 下個會話最重要的檔案

- `.vibe/規矩檔.md` ← 動工前必讀
- `.vibe/機械鍵盤聲音-音檔來源.md` ← 最下面「AI 生成（2026-11-19）」段：兩邊比較、提示詞、挑選理由、每套幾聲
- `docs/make_ai_keysounds.py` ← 要重新生成或換掉某套時跑這支（原檔在 `試聽-AI鍵盤聲/ElevenLabs原檔/`）
- `Shared/KeySoundSetting.swift` ← 選單選項與音檔套名
- `project.yml` ← 第 12 行 `MARKETING_VERSION`，已是 1.2.2
- `.aso/閘門紀錄.md` ← 最後一條是 1.2.1 上線
- `試聽-AI鍵盤聲/試聽.html` ← 雙擊就能聽，ElevenLabs 和 Mirelo 每種並排（沒進 git）

## ⏭️ 下一步從哪繼續

1. 先讀這份，再 `git log --oneline -5` 確認 `redesign-domy-sage` 最新的 commit 是這次的 handoff
2. 版本號已經是 1.2.2（`project.yml`），不用再改；送審時 `.aso/asc_release.py` 的 `VERSION` 改 1.2.2、`DROP_NOTES_FROM` 加 "1.2.1"
3. 多米說要打包時，在 GitHub 手動執行 testflight 工作流程，分支選 `redesign-domy-sage`
4. 多米真機聽完四套後，照他的回報調（換掉某套就改 `make_ai_keysounds.py` 的 `PACKS` 重跑、改 `KeySoundSetting.swift`）
5. 要送審時，新功能說明照規矩逐項問過多米的真機結果才寫

## 🗑️ 這次會話的雜訊（下次別重新討論）

- ElevenLabs 網頁下載：主頁的結果面板座標會跑，用歷史記錄頁（/app/sound-effects/history），點下載鈕後用 find 找「WAV」再點，下載完按 Escape 關選單。不要在選單沒開時按 Enter（焦點在提示詞框會直接生成）
- ElevenLabs API 金鑰沒建，網頁版就夠用；`試聽-AI鍵盤聲/elevenlabs_sfx.py` 是寫好但沒用到的 API 腳本
- 帳號裡同時段那 5 筆紙張、寫字、翻書的生成不是這個會話做的，不用管
- Higgsfield 生成越長並不會出越多聲，不用再試
