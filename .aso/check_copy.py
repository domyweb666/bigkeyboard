# 算 05-素材文案.md 裡描述、推廣文字的字數，並找出會被 App Store Connect 吃掉的注音符號。
# 用法：python -I .aso/check_copy.py
import re
import sys
from pathlib import Path

sys.stdout.reconfigure(encoding="utf-8")
doc = Path(__file__).with_name("05-素材文案.md").read_text(encoding="utf-8")
blocks = [body for lang, body in re.findall(r"```(\w*)\n(.*?)```", doc, re.S) if not lang]
targets = {"描述": (blocks[0], 4000), "推廣文字": (blocks[1], 170), "新功能說明": (blocks[2], 4000)}
bopomofo = re.compile(r"[㄀-ㄯㆠ-ㆿˇˋˊ˙]")
uk = Path(__file__).with_name("04-英國英文.md").read_text(encoding="utf-8")
uk_blocks = [body for lang, body in re.findall(r"```(\w*)\n(.*?)```", uk, re.S) if not lang]
for label, idx, limit in (("英國英文 名稱", 0, 30), ("英國英文 副標", 1, 30), ("英國英文 關鍵字", 2, 100),
                          ("英國英文 描述", 3, 4000), ("英國英文 推廣文字", 4, 170), ("英國英文 新功能說明", 5, 4000)):
    targets[label] = (uk_blocks[idx], limit)
for name, (text, limit) in targets.items():
    text = text.strip()
    bad = sorted(set(bopomofo.findall(text)))
    print(f"{name}: {len(text)}/{limit} {'OK' if len(text) <= limit else '超過！'}  注音符號：{bad or '無'}")
