# 第三方授權

## McBopomofo（小麥注音）— MIT License
- 來源：https://github.com/openvanilla/McBopomofo
- 使用範圍：`KeyboardExtension/Engine/Vendor/McBopomofo/`（Mandarin 組字器、gramambular2、ParselessLM、ParselessPhraseDB、MemoryMappedFile、AssociatedPhrasesV2、UTF8Helper，原樣搬入未修改）與 `KeyboardExtension/Resources/mcbopomofo-data.txt`、`mcbopomofo-associated.txt`（由其 Source/Data 以原 Makefile 編譯）
- 完整授權文字：`KeyboardExtension/Engine/Vendor/McBopomofo/LICENSE.txt`

## AOSP LatinIME 英文詞頻表 — Apache License 2.0
- 來源：https://android.googlesource.com/platform/packages/inputmethods/LatinIME/（dictionaries/en_US_wordlist.combined.gz，Android 原生鍵盤的英文詞庫；含 Lexiteria LLC 授權給 AOSP 的字典資料）
- 使用範圍：`KeyboardExtension/Resources/english-words.txt`（英文預測字）。有修改：濾掉冒犯字與非單字、只留英文字母／撇號／連字號、加入不打撇號的查法，轉成一行一字的格式
- 完整授權文字：`KeyboardExtension/Resources/LICENSE-AOSP-LatinIME.txt`

## Noto Serif TC — SIL Open Font License 1.1
- 來源：https://github.com/notofonts/noto-cjk（Serif2.003，Serif/SubsetOTF/TC/NotoSerifTC-Medium.otf）
- 使用範圍：`KeyboardExtension/Resources/Fonts/NotoSerifTC-Medium.otf`（豆漿主題的鍵帽字，原檔未修改）
- 完整授權文字：`KeyboardExtension/Resources/Fonts/OFL-NotoSerifTC.txt`

## 霞鶩文楷 TC（LXGW WenKai TC）— SIL Open Font License 1.1
- 來源：https://github.com/lxgw/LxgwWenkaiTC（v1.530，LXGWWenKaiTC-Regular.ttf）
- 使用範圍：`KeyboardExtension/Resources/Fonts/LXGWWenKaiTC-Regular.ttf`（紅豆主題的鍵帽字，原檔未修改）
- 完整授權文字：`KeyboardExtension/Resources/Fonts/OFL-LXGWWenKaiTC.txt`

## 機械鍵盤聲音包 — CC0 1.0（公眾領域貢獻宣告）
- 來源：Freesound。StavSounds「Mechanical Keyboards」pack（https://freesound.org/people/StavSounds/packs/42151/，Keyboard_Clicky_1～19、Keyboard_Tactile_1～15）；jim-ph「vintage keyboard」pack（https://freesound.org/people/jim-ph/packs/12363/，keyboard5、Vintage Keyboard 1～4）。2026-11-16 下載，pack 裡的 _readme_and_license.txt 逐檔標示 Creative Commons 0
- 使用範圍：`KeyboardExtension/Resources/KeySounds/keysound-{clicky,tactile,vintage}-*.wav`（按鍵聲選單的「機械鍵盤・清脆／厚實／復古」）。有修改：用 `docs/make_keysounds.py` 轉成單聲道 44.1 kHz 16 bit wav、音量拉齊、切掉頭尾空白、尾巴淡出，每個錄音再切成「按下」「彈回」兩段分開播；每套另取三個降四個半音給空白、刪除、換行鍵用
- CC0 不要求標示；來源說明放在 `KeyboardExtension/Resources/KeySounds/CREDITS-KeySounds.txt`，App「開源授權」頁顯示這一份
- 查過但沒有用的來源、以及為什麼不能用，記在 `.vibe/機械鍵盤聲音-音檔來源.md`

## AI 生成的按鍵聲 — ElevenLabs Sound Effects（付費方案商用）
- 不是第三方作品：2026-11-19 用多米自己的 ElevenLabs 帳號（Starter 付費方案，含商用授權）在音效頁生成，v3 模型。生成時已關掉「分享到 Explore」
- 使用範圍：`KeyboardExtension/Resources/KeySounds/keysound-{beans,woodblock,typewriter,laptop}-*.wav`（按鍵聲選單的「豆子落碗／木魚／打字機／筆電鍵盤」）。用 `docs/make_ai_keysounds.py` 切成單聲、篩掉重疊與沒收乾淨的、不足 12 聲的用變調補齊、大鍵降四個半音
- 提示詞、設定、為什麼挑這四種，記在 `.vibe/機械鍵盤聲音-音檔來源.md` 的「AI 生成」那一段
