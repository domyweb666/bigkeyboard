"""照 Shared/KeyboardTheme.swift 的色碼畫 README 用的鍵盤示意圖（SVG）。
用法：在 repo 根目錄跑 python docs/make_images.py .
"""
import re
import sys
from pathlib import Path

root = Path(sys.argv[1])
src = (root / "Shared" / "KeyboardTheme.swift").read_text(encoding="utf-8")
out = root / "docs" / "images"
out.mkdir(parents=True, exist_ok=True)

FIELDS = ["key", "medial", "finals", "tone", "function", "text", "hint", "pressed"]


def section(name):
    body = src.split(f"var {name}: Colors {{", 1)[1].split("\n    }\n", 1)[0]
    pal = {}
    for case, hexes in re.findall(r'case \.(\w+): Colors\("([0-9A-F ]+)"\)', body):
        pal[case] = dict(zip(FIELDS, ["#" + h for h in hexes.split()]))
    return pal


def simple(name):
    body = src.split(f"var {name}:", 1)[1].split("\n    }\n", 1)[0]
    vals = {}
    for cases, val in re.findall(r"case ([.\w, ]+): (.+)", body):
        for c in cases.split(","):
            vals[c.strip().lstrip(".")] = val.strip().strip('"')
    return vals


LIGHT, DARK = section("light"), section("dark")
NAMES = simple("name")
RADIUS = {k: float(v) for k, v in simple("cornerRadius").items()}
ORDER = ["gray", "edamame", "soymilk", "redBean", "blackBean", "coffee", "butterfly", "jellyBean"]
SANS = "PingFang TC, Noto Sans TC, Microsoft JhengHei, sans-serif"
FONT = {
    "soymilk": "Noto Serif TC, Songti TC, PMingLiU, serif",
    "redBean": "LXGW WenKai TC, Kaiti TC, BiauKai, DFKai-SB, serif",
}
WEIGHT = {"gray": 400, "soymilk": 500, "redBean": 400, "jellyBean": 700}
SYS = {"light": ("#E2E3E7", "#3C3C43"), "dark": ("#2C2C2E", "#EBEBF5")}
CANDS = {
    "gray": ["豆鍵", "豆", "鬥", "逗", "痘"], "edamame": ["毛豆", "毛", "貓", "帽", "茂"],
    "soymilk": ["豆漿", "豆", "逗", "痘", "鬥"], "redBean": ["紅豆", "紅", "洪", "宏", "虹"],
    "blackBean": ["黑豆", "黑", "嘿", "黑色", "黑夜"], "coffee": ["咖啡豆", "咖啡", "咖", "卡", "喀"],
    "butterfly": ["蝶豆花", "蝶", "碟", "疊", "跌"], "jellyBean": ["糖豆", "糖", "堂", "唐", "躺"],
}

TONES, MED, FIN = "ˇˋˊ˙", "ㄧㄨㄩ", "ㄚㄛㄜㄝㄞㄟㄠㄡㄢㄣㄤㄥㄦ"


def zone(s):
    return "tone" if s in TONES else "medial" if s in MED else "finals" if s in FIN else "key"


def rows():
    k = lambda s: {"label": s, "w": 1, "zone": zone(s)}
    gap = {"spacer": True, "w": 0.5}
    return [
        [k(s) for s in "ㄅㄉˇˋㄓˊ˙ㄚㄞㄢㄦ"],
        [gap] + [k(s) for s in "ㄆㄊㄍㄐㄔㄗㄧㄛㄟㄣ"] + [gap],
        [gap] + [k(s) for s in "ㄇㄋㄎㄑㄕㄘㄨㄜㄠㄤ"] + [gap],
        [k(s) for s in "ㄈㄌㄏㄒㄖㄙㄩㄝㄡㄥ"] + [{"icon": "del", "w": 1, "zone": "function"}],
        [
            {"label": "符", "w": 1.3, "zone": "function", "hint": "123"},
            {"label": "ABC", "w": 1.3, "zone": "function"},
            {"label": "，", "w": 1, "zone": "key"},
            {"label": "", "w": 4.3, "zone": "key", "foot": "注音"},
            {"label": "。", "w": 1, "zone": "key"},
            {"icon": "ret", "w": 1.6, "zone": "function"},
        ],
    ]


ICONS = {
    "del": '<path d="M9 5h10a2 2 0 0 1 2 2v10a2 2 0 0 1-2 2H9l-6-7z"/><path d="M12.5 9.5l5 5M17.5 9.5l-5 5"/>',
    "ret": '<path d="M20 5v7a2 2 0 0 1-2 2H5"/><path d="M9 10l-4 4 4 4"/>',
    "chev": '<path d="M6 9l6 6 6-6"/>',
    "kbd": '<rect x="3" y="3" width="18" height="11" rx="2"/><path d="M7 7h1M11 7h2M16 7h1M8 10.5h8"/>'
           '<path d="M9 18l3 3 3-3"/>',
    "globe": '<circle cx="12" cy="12" r="9"/><path d="M3 12h18M12 3c2.5 2.6 3.8 5.6 3.8 9s-1.3 6.4-3.8 9'
             'c-2.5-2.6-3.8-5.6-3.8-9S9.5 5.6 12 3z"/>',
    "mic": '<rect x="9" y="3" width="6" height="11" rx="3"/><path d="M5.5 11a6.5 6.5 0 0 0 13 0M12 17.5V21"/>',
}


def icon(name, x, y, size, color, sw=1.8):
    s = size / 24
    return (f'<g transform="translate({x:.1f},{y:.1f}) scale({s:.3f})" fill="none" stroke="{color}" '
            f'stroke-width="{sw}" stroke-linecap="round" stroke-linejoin="round">{ICONS[name]}</g>')


def keyboard(theme, mode, ox, oy, candidates=True):
    """畫一塊 390 寬的鍵盤（含系統底排），左上角在 (ox, oy)。回傳 (svg 片段, 高度)"""
    p = (LIGHT if mode == "light" else DARK)[theme]
    sys_bg, sys_icon = SYS[mode]
    r = RADIUS[theme]
    font = FONT.get(theme, SANS)
    weight = WEIGHT.get(theme, 500)
    shadow = "rgba(0,0,0,0.35)" if mode == "dark" else "rgba(0,0,0,0.14)"
    bar_h = 46 if candidates else 0
    h = bar_h + 6 + 5 * 44 + 4 * 7 + 12 + 50
    g = [f'<rect x="{ox}" y="{oy}" width="390" height="{h}" rx="22" fill="{sys_bg}"/>']
    if candidates:
        cx = ox + 8
        for i, c in enumerate(CANDS[theme]):
            w = 27 * len(c) + 18
            if i == 0:
                g.append(f'<rect x="{cx}" y="{oy + 6}" width="{w}" height="36" rx="{r}" fill="{p["key"]}"/>')
            g.append(f'<text x="{cx + w / 2:.1f}" y="{oy + 33}" text-anchor="middle" font-size="25" '
                     f'font-family="{font}" fill="{p["text"]}">{c}</text>')
            cx += w + 2
        g.append(icon("chev", ox + 390 - 96, oy + 10, 26, p["text"], 2))
        g.append(f'<rect x="{ox + 390 - 56}" y="{oy + 12}" width="1" height="22" fill="{p["hint"]}" opacity="0.4"/>')
        g.append(icon("kbd", ox + 390 - 40, oy + 10, 26, p["hint"], 1.6))
    y = oy + bar_h + 6
    for row in rows():
        total = sum(k["w"] for k in row)
        unit = (382 - 5 * (len(row) - 1)) / total
        x = ox + 4
        for k in row:
            w = unit * k["w"]
            if not k.get("spacer"):
                fill = p[k["zone"]]
                g.append(f'<rect x="{x:.1f}" y="{y + 1}" width="{w:.1f}" height="44" rx="{r}" fill="{shadow}"/>')
                g.append(f'<rect x="{x:.1f}" y="{y}" width="{w:.1f}" height="44" rx="{r}" fill="{fill}"/>')
                cx = x + w / 2
                if "icon" in k:
                    g.append(icon(k["icon"], cx - 12, y + 10, 24, p["text"]))
                elif k["label"]:
                    tone = k["zone"] == "tone"
                    size = 34 if tone else 17 if k["label"] == "ABC" else 19 if k["zone"] == "function" else 26
                    fw = 700 if tone else weight
                    ty = y + 22 + size * 0.36 + (6 if tone else 0)
                    g.append(f'<text x="{cx:.1f}" y="{ty:.1f}" text-anchor="middle" font-size="{size}" '
                             f'font-weight="{fw}" font-family="{font}" fill="{p["text"]}">{k["label"]}</text>')
                if "foot" in k:
                    g.append(f'<text x="{cx:.1f}" y="{y + 39}" text-anchor="middle" font-size="11" '
                             f'font-family="{SANS}" fill="{p["hint"]}">{k["foot"]}</text>')
                if "hint" in k:
                    g.append(f'<text x="{x + w - 5:.1f}" y="{y + 13}" text-anchor="end" font-size="10" '
                             f'font-family="{SANS}" fill="{p["text"]}">{k["hint"]}</text>')
            x += w + 5
        y += 44 + 7
    y += 5
    g.append(icon("globe", ox + 24, y + 4, 26, sys_icon, 1.6))
    g.append(icon("mic", ox + 390 - 50, y + 4, 26, sys_icon, 1.6))
    return "\n".join(g), h


def svg(w, h, body, title):
    return (f'<svg xmlns="http://www.w3.org/2000/svg" width="{w}" height="{h}" viewBox="0 0 {w} {h}" '
            f'role="img" aria-label="{title}">\n<title>{title}</title>\n'
            f'<rect width="{w}" height="{h}" rx="16" fill="#F3F3F5"/>\n{body}\n</svg>\n')


def caption(x, y, text, size=15, color="#3A3A3F", weight=500, anchor="start"):
    return (f'<text x="{x}" y="{y}" font-size="{size}" font-weight="{weight}" font-family="{SANS}" '
            f'fill="{color}" text-anchor="{anchor}">{text}</text>')


# 1. 冷灰（預設）淺色＋深色
parts = []
for i, mode in enumerate(["light", "dark"]):
    ox = 24 + i * 430
    parts.append(caption(ox, 40, "淺色模式" if mode == "light" else "深色模式"))
    body, kh = keyboard("gray", mode, ox, 56)
    parts.append(body)
(out / "keyboard.svg").write_text(svg(868, 56 + kh + 24, "\n".join(parts), "豆鍵注音鍵盤（冷灰主題）"), encoding="utf-8")

# 2、3. 8 款主題總覽（淺色、深色各一張），每塊縮成一半
for mode in ["light", "dark"]:
    parts = []
    scale, cols = 0.5, 4
    cell_w, cell_h = 390 * scale, None
    for i, t in enumerate(ORDER):
        col, row = i % cols, i // cols
        body, kh = keyboard(t, mode, 0, 0)
        cell_h = kh * scale
        x = 24 + col * (cell_w + 24)
        y = 24 + row * (cell_h + 60)
        label = NAMES[t] + ("（預設・免費）" if t == "gray" else "")
        parts.append(caption(x, y + 18, label, 15, "#1C1C1E", 600))
        parts.append(f'<g transform="translate({x},{y + 30}) scale({scale})">{body}</g>')
    w = int(24 + cols * (cell_w + 24))
    h = int(24 + 2 * (cell_h + 60))
    title = f"豆鍵 8 款主題（{'淺色' if mode == 'light' else '深色'}模式）"
    (out / f"themes-{mode}.svg").write_text(svg(w, h, "\n".join(parts), title), encoding="utf-8")

print("\n".join(str(p) for p in sorted(out.glob("*.svg"))))
