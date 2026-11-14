# 檢查 App Store metadata：字數（以字元算）、三欄有沒有重複的詞。
# 用法：python -I .aso/check_metadata.py
# 改候選就改下面的 SETS，再跑一次。
import sys

sys.stdout.reconfigure(encoding="utf-8")

LIMITS = {"name": 30, "subtitle": 30, "keywords": 100}

SETS = {
    "原建議（沒選）：N1＋S1": {
        "name": "豆鍵：大字注音鍵盤",
        "name_words": ["豆鍵", "大字", "注音", "鍵盤"],
        "subtitle": "不用重學排法・少按錯的輸入法",
        "subtitle_words": ["不用", "重學", "排法", "少", "按錯", "輸入法"],
        "keywords": "打字,按鍵,繁體,中文,台灣,國語,字典,學詞,選字,聲調,一聲,剪貼簿,主題,離線,隱私,鍵位,手指,錯字,好按,深色,大千",
    },
    "定案（2026-11-14 多米選）：N1＋S2": {
        "name": "豆鍵：大字注音鍵盤",
        "name_words": ["豆鍵", "大字", "注音", "鍵盤"],
        "subtitle": "少按錯的輸入法・聲母韻母分色",
        "subtitle_words": ["少", "按錯", "輸入法", "聲母", "韻母", "分色"],
        "keywords": "打字,按鍵,繁體,中文,台灣,國語,字典,學詞,選字,聲調,一聲,剪貼簿,主題,離線,隱私,鍵位,手指,錯字,好按,深色,排法",
    },
    "備案：N2＋S1": {
        "name": "豆鍵：大字注音鍵盤・輸入法",
        "name_words": ["豆鍵", "大字", "注音", "鍵盤", "輸入法"],
        "subtitle": "不用重學排法・按錯變少",
        "subtitle_words": ["不用", "重學", "排法", "按錯", "變少"],
        "keywords": "打字,按鍵,繁體,中文,台灣,國語,字典,學詞,選字,聲調,一聲,剪貼簿,主題,離線,隱私,鍵位,手指,錯字,好按,深色,大千",
    },
    "現行 1.0（對照）": {
        "name": "豆鍵：大字注音鍵盤",
        "name_words": ["豆鍵", "大字", "注音", "鍵盤"],
        "subtitle": "字大鍵緊，少按錯的注音鍵盤",
        "subtitle_words": ["字大", "鍵緊", "少", "按錯", "注音", "鍵盤"],
        "keywords": "輸入法,注音輸入法,ㄅㄆㄇ,中文,繁體中文,打字,大字,大按鍵,字典,自動學詞,鍵盤主題,台灣,國語,選字,候選字",
    },
    "英國英文組": {
        "name": "Doujian: Big Zhuyin Keyboard",
        "name_words": ["doujian", "big", "zhuyin", "keyboard"],
        "subtitle": "Bopomofo typing, fewer typos",
        "subtitle_words": ["bopomofo", "typing", "fewer", "typos"],
        "keywords": "chinese,taiwan,traditional,large,keys,font,themes,clipboard,input,mandarin,dictionary,offline",
    },
}


def check(label, s):
    print(f"\n== {label}")
    for field in ("name", "subtitle", "keywords"):
        text = s[field]
        n = len(text)
        flag = "OK" if n <= LIMITS[field] else "超過！"
        print(f"{field:9} {n:3}/{LIMITS[field]} {flag}  {text}")
    kws = s["keywords"].split(",")
    if any(" " in k for k in kws):
        print("  關鍵字欄位有空格")
    seen = {}
    for field, words in (("名稱", s["name_words"]), ("副標", s["subtitle_words"]), ("關鍵字", kws)):
        for w in words:
            seen.setdefault(w.lower(), []).append(field)
    dups = {w: f for w, f in seen.items() if len(f) > 1}
    # 關鍵字裡包含名稱或副標的詞（例：「注音輸入法」含「注音」）
    contains = [
        (k, w) for k in kws for w in s["name_words"] + s["subtitle_words"]
        if w.lower() in k.lower() and w.lower() != k.lower()
    ]
    print("  重複的詞：", dups or "無")
    print("  關鍵字含名稱／副標的詞：", contains or "無")


for label, s in SETS.items():
    check(label, s)
