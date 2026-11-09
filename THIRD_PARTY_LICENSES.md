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
