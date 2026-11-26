# 引擎測試（Windows，用真詞庫）

測的是 `KeyboardExtension/Engine/Bridge/*.h` 那份程式本身。需要 VS 2022 BuildTools。

1. 把這個資料夾複製到 repo 外面（會產生 30 MB 左右的檔案）
2. `git show 85119bd:KeyboardExtension/Engine/Bridge/BopomofoEngine.mm > orig.mm`（改之前的引擎，當對照）
3. `git show HEAD:KeyboardExtension/Resources/mcbopomofo-data.txt > data.txt`（一定要 LF；工作目錄那份是 CRLF，會查不到字）
4. `python prep.py`（抽句子、常用詞、人名當語料）
5. `bash build.sh`，再跑 `test.exe regress|abbr|last|tol|speed|random|span`（`span`：一個音的表情、符號選了只吃一個音，「ate too many」要是 0）。`regress` 要跑兩次：空字典，和 `regress users 300`（帶學過的詞）

每組測什麼、要到多少：`.vibe/容錯四項-規格.md` 的「測試」。
