# 從 04、05、04-英國英文 抽出定稿，產生「上架貼上清單.md」：照 App Store Connect 的欄位順序排好，一欄一塊，直接複製。
# 用法：python -I .aso/make_paste_sheet.py
# 改文案改原本那幾個檔，再跑一次這支；不要直接改產出的清單。
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
HERE = Path(__file__).parent


def blocks(name):
    text = (HERE / name).read_text(encoding="utf-8")
    return [b.strip() for lang, b in re.findall(r"```(\w*)\n(.*?)```", text, re.S) if not lang]


meta = (HERE / "04-metadata.md").read_text(encoding="utf-8")
zh_kw = blocks("04-metadata.md")[0]
zh = blocks("05-素材文案.md")  # 0 描述 1 推廣文字 2 新功能說明 3 隱私權政策 4 支援頁一題
uk = blocks("04-英國英文.md")  # 0 名稱 1 副標 2 關鍵字 3 描述 4 推廣文字 5 新功能說明

name = re.search(r"\| 名稱 \| (豆鍵：大字注音鍵盤)", meta).group(1)
subtitle = re.search(r"\| 副標 \| (.+?)（S2）", meta).group(1)


def field(title, limit, text):
    return f"### {title}（{len(text)}／{limit}）\n\n```\n{text}\n```\n"


out = [
    "# 上架貼上清單（1.1）\n",
    "> 這份是 `make_paste_sheet.py` 從 04、05、04-英國英文 抽出來的，不要直接改。",
    "> 字數是程式算的。名稱、副標、關鍵字要跟 1.1 一起送審才生效；推廣文字隨時能改。\n",
    "## 繁體中文\n",
    field("名稱", 30, name),
    field("副標", 30, subtitle),
    field("推廣文字", 170, zh[1]),
    field("描述", 4000, zh[0]),
    field("關鍵字", 100, zh_kw),
    field("此版本的新功能", 4000, zh[2]),
    "## 英文（英國）\n",
    "App 頁面右上語言選單 →「英文（英國）」。截圖沿用繁中那組。\n",
    field("名稱", 30, uk[0]),
    field("副標", 30, uk[1]),
    field("推廣文字", 170, uk[4]),
    field("描述", 4000, uk[3]),
    field("關鍵字", 100, uk[2]),
    field("此版本的新功能", 4000, uk[5]),
]
(HERE / "上架貼上清單.md").write_text("\n".join(out), encoding="utf-8")
print("已產生 .aso/上架貼上清單.md")
