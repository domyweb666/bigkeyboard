# 豆鍵 ASO

照 ASO Agent（github.com/domyweb666/aso）的流程做。檔名帶「暫定」的是還沒過閘門 1（iPhone 實搜）的版本。

| 檔案 | 內容 |
|---|---|
| `01-意圖清單-暫定.md` | 台灣店面實搜 30 個詞、品牌搜尋、疑慮清單 |
| `02-關鍵字表-暫定.md` | 每個詞打不打、放哪個欄位 |
| `03-競品矩陣-暫定.md` | 9 個對手的副標、評分數、排法、必答題與空位 |
| `04-metadata.md` | 1.1 的名稱、副標、關鍵字候選（等閘門 3） |
| `05-素材文案.md` | 截圖腳本、描述、推廣文字、新功能說明、承諾對照表、隱私權政策要改的段落 |
| `05-影片.md` | 預覽影片腳本、錄影方法、規格 |
| `閘門紀錄.md` | 五道閘門的狀態 |
| `lessons.md` | 這次撞到的問題與下次規則 |

腳本：

```bash
python -I .aso/check_metadata.py
```

```bash
python -I .aso/check_copy.py
```

```bash
python -I .aso/截圖/make_screenshots.py .aso/截圖/raw .aso/截圖/out
```

```bash
python -I .aso/影片/make_preview.py .aso/影片/rec .aso/影片/out/豆鍵-預覽.mp4
```

1.0 的文案和截圖還在 `.vibe/上架文案.md`、`.vibe/上架截圖/`，1.1 定稿後以這個資料夾為準。
