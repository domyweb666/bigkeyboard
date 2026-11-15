# 豆鍵商店展示圖：真機截圖（1206×2622）＋大標＋描述句 → 6.3 吋與 6.9 吋兩種尺寸。
# 版型照茄記（E:\茄記\qieji-1.1\.aso\tools\store_shots.py，多米 2026-11-15 定）：
#   整組同一個漸層底；每張兩行大標（第二行強調色）＋一句描述；手機放大到 1000 寬、從底部出血；
#   重點那一塊放大跳出手機框；第一張是主視覺大字。顏色換成豆鍵 icon 的深綠、米白、珊瑚紅。
# 用法：python -I .aso/截圖/make_screenshots.py
# 要換圖或換字，改下面 SHOTS。原圖放 .aso/截圖/raw/（檔名照格號）。
import shutil
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

sys.stdout.reconfigure(encoding="utf-8")
HERE = Path(__file__).parent
ROOT = HERE.parent.parent
RAW = HERE / "raw"
OUT = HERE / "out"
ICON = ROOT / "App/Assets.xcassets/AppIcon.appiconset/icon-1024.png"
FONT = r"C:\Windows\Fonts\NotoSansTC-VF.ttf"
SIZES = {"6.3": (1206, 2622), "6.9": (1320, 2868)}

# 豆鍵 icon 的深綠：上深下淺
BG_TOP, BG_BOTTOM = (5, 34, 27), (28, 102, 74)
CREAM = (248, 234, 210)   # 大標（icon 的豆子）
ACCENT = (242, 212, 118)  # 第二行強調：毛豆黃（2026-11-15 多米嫌珊瑚紅怪，換掉）
SAGE = (196, 222, 204)    # 描述句
BEZEL = (6, 18, 14)       # 手機邊框
SHADOW = (0, 14, 8)

# name 檔名｜raw 原圖｜title 兩行大標｜sub 描述句｜top 手機上緣（1206 寬時的 y）
# pops 把原圖裡的一塊稍微放大、跳出手機外。多米 2026-11-15：太刻意，只留真的要指給人看的那一兩張：[(x0, y0, x1, y1, 倍率, 圓角)]，座標是原圖像素
SHOTS = [
    dict(name="01-字大", raw="1.PNG", hero=True, title=["字大鍵緊"], sub="少按錯的注音鍵盤",
         pills=["排法不用重學", "鍵盤不連網", "冷灰主題免費"]),
    # 第 2 張：多米補拍 2.PNG（打「ㄐㄧㄚ」不選字、沒有泡泡）之前，先用 1.PNG
    dict(name="02-分色", raw="2.PNG" if (RAW / "2.PNG").exists() else "1.PNG",
         title=["介音藍", "韻母橘"], sub="聲母在左、韻母在右，一眼分得出來"),
    # 2026-11-15 多米：空白鍵也要放大
    dict(name="03-一聲", raw="5.PNG", title=["沒打聲調？", "按空白當一聲"], sub="空白鍵上的小字，寫著這一下是一聲還是選字",
         pops=[(0, 1438, 1206, 1546, 1.08, 30), (436, 2228, 892, 2380, 1.5, 36)]),
    dict(name="04-隱私", raw="4.PNG", title=["打的字", "只留在手機上"], sub="鍵盤不連網，iCloud 同步預設是關的",
         pops=[(62, 1338, 1146, 1488, 1.08, 50)]),
    # 2026-11-15 多米：深色畫面配「排法不用重新學」很怪。大標換回 1.0 多米原本的「手機切深色／鍵盤跟著切」，
    # 「排法不用重學」留在第 1 張的小標。描述句照 README「深色模式跟著系統，也跟著輸入框」
    dict(name="05-深色", raw="3.PNG", title=["手機切深色", "鍵盤跟著切"], sub="深色模式跟著系統，也跟著輸入框"),
    dict(name="06-字典", raw="6.PNG", title=["改選過的詞", "下次排前面"], sub="鍵盤學到的詞，打開 App 就看得到"),
    dict(name="07-剪貼簿", raw="7.PNG", title=["複製過的字", "點一下就貼"], sub="常用的可以固定、加標籤"),
    dict(name="08-主題", raw="8.PNG", title=["8 款豆子主題", "冷灰免費"], sub="換顏色、字體和圓角，鍵位不變"),
    dict(name="09-紅豆", raw="9.PNG", title=["紅豆主題", "楷書鍵帽字"], sub="每款都有淺色、深色兩套"),
]


def font(size, weight=900):
    f = ImageFont.truetype(FONT, int(size))
    f.set_variation_by_axes([weight])
    return f


def fit(d, text, size, max_w, weight=900):
    """字太長就縮到放得下。"""
    f = font(size, weight)
    while d.textlength(text, font=f) > max_w:
        size -= 2
        f = font(size, weight)
    return f


def center(d, w, y, text, f, fill):
    d.text(((w - d.textlength(text, font=f)) / 2, y), text, font=f, fill=fill)


def gradient(size):
    w, h = size
    col = Image.new("RGB", (1, h))
    for y in range(h):
        t = y / (h - 1)
        col.putpixel((0, y), tuple(int(a + (b - a) * t) for a, b in zip(BG_TOP, BG_BOTTOM)))
    return col.resize(size)


def mask(size, radius):
    ss = 3
    m = Image.new("L", (size[0] * ss, size[1] * ss), 0)
    ImageDraw.Draw(m).rounded_rectangle([0, 0, size[0] * ss - 1, size[1] * ss - 1], radius * ss, fill=255)
    return m.resize(size, Image.LANCZOS)


def pill_row(d, w, y, texts, f, k, gap=22):
    widths = [d.textlength(t, font=f) + 56 * k for t in texts]
    x = (w - sum(widths) - gap * k * (len(texts) - 1)) / 2
    ph = f.size * 1.9
    for t, pw in zip(texts, widths):
        d.rounded_rectangle([x, y, x + pw, y + ph], ph / 2, outline=SAGE, width=max(2, int(3 * k)))
        d.text((x + 28 * k, y + (ph - f.size * 1.45) / 2), t, font=f, fill=CREAM)
        x += pw + gap * k


def shadow(im, box, radius, blur, alpha=130, dy=18):
    sh = Image.new("RGBA", im.size, (0, 0, 0, 0))
    x0, y0, x1, y1 = box
    ImageDraw.Draw(sh).rounded_rectangle([x0, y0 + dy, x1, y1 + dy], radius, fill=(*SHADOW, alpha))
    return Image.alpha_composite(im.convert("RGBA"), sh.filter(ImageFilter.GaussianBlur(blur))).convert("RGB")


def compose(size, raw, title, sub, top=None, pops=None, hero=False, pills=None, name=None):
    w, h = size
    k = w / 1206
    im = gradient(size)
    d = ImageDraw.Draw(im)
    phone_w = 1000
    if hero:
        # 主視覺：圖示＋名字、特大字、描述句、三顆小標；手機小一點，鍵盤才露得完整
        icon = Image.open(ICON).convert("RGB").resize((int(104 * k),) * 2, Image.LANCZOS)
        fn = font(62 * k, 800)
        tw = d.textlength("豆鍵", font=fn)
        x0 = (w - (icon.width + 24 * k + tw)) / 2
        y0 = int(96 * k)
        im.paste(icon, (int(x0), y0), mask(icon.size, int(24 * k)))
        d.text((x0 + icon.width + 24 * k, y0 + (icon.height - fn.size * 1.45) / 2), "豆鍵", font=fn, fill=CREAM)
        center(d, w, 214 * k, title[0], fit(d, title[0], 250 * k, w * 0.9), CREAM)
        center(d, w, 580 * k, sub, font(80 * k, 800), ACCENT)
        pill_row(d, w, 728 * k, pills, font(42 * k, 700), k)
        top = top or 880
        phone_w = 900
    else:
        size_t = min(fit(d, t, 138 * k, w * 0.9).size for t in title)
        ft = font(size_t)
        y = 96 * k
        for i, t in enumerate(title):
            center(d, w, y, t, ft, ACCENT if i == len(title) - 1 and len(title) > 1 else CREAM)
            y += size_t * 1.2
        y += 44 * k
        center(d, w, y, sub, fit(d, sub, 56 * k, w * 0.9, 500), SAGE)
        y += 110 * k
        top = top or (y / k + 40)
    shot = Image.open(RAW / raw).convert("RGB")
    sc = phone_w * k / shot.width          # 手機畫面放大，底部出血
    pw, ph = int(shot.width * sc), int(shot.height * sc)
    x, y = (w - pw) // 2, int(top * k)
    r, b = int(92 * k * phone_w / 1000), int(18 * k)
    im = shadow(im, (x - b, y - b, x + pw + b, y + ph + b), r + b, int(w * 0.025))
    ImageDraw.Draw(im).rounded_rectangle([x - b, y - b, x + pw + b, y + ph + b], r + b, fill=BEZEL)
    im.paste(shot.resize((pw, ph), Image.LANCZOS), (x, y), mask((pw, ph), r))
    for x0, y0, x1, y1, zoom, rad in pops or []:
        # 重點那一塊放大，疊在原位置上，超出手機邊框
        piece = shot.crop((x0, y0, x1, y1))
        qw, qh = int(piece.width * sc * zoom), int(piece.height * sc * zoom)
        cx, cy = x + (x0 + x1) / 2 * sc, y + (y0 + y1) / 2 * sc
        qx = int(min(max(cx - qw / 2, 14 * k), w - qw - 14 * k))
        qy = int(min(cy - qh / 2, h - qh - 40 * k))
        qr = int(rad * sc * zoom)
        im = shadow(im, (qx, qy, qx + qw, qy + qh), qr, int(w * 0.022), alpha=120, dy=16)
        im.paste(piece.resize((qw, qh), Image.LANCZOS), (qx, qy), mask((qw, qh), qr))
    return im


def main():
    for label, size in SIZES.items():
        out_dir = OUT / label
        shutil.rmtree(out_dir, ignore_errors=True)
        out_dir.mkdir(parents=True)
        for s in SHOTS:
            compose(size, **s).save(out_dir / f"{s['name']}.jpg", quality=94)
    # 總覽給人看；搜尋結果預覽給 5 秒測試用（前三張縮到約 200 寬）
    W = 400
    H = int(W * 2622 / 1206)
    names = [s["name"] for s in SHOTS]
    sheet = Image.new("RGB", (W * 5 + 12 * 4, H * 2 + 12), (245, 245, 245))
    for i, n in enumerate(names):
        im = Image.open(OUT / "6.3" / f"{n}.jpg").resize((W, H), Image.LANCZOS)
        sheet.paste(im, ((i % 5) * (W + 12), (i // 5) * (H + 12)))
    sheet.save(OUT / "總覽（不用上傳）.jpg", quality=88)
    tw, th, gap = 200, int(200 * 2622 / 1206), 12
    pre = Image.new("RGB", (tw * 3 + gap * 4, th + gap * 2), "#FFFFFF")
    for i, n in enumerate(names[:3]):
        pre.paste(Image.open(OUT / "6.3" / f"{n}.jpg").resize((tw, th), Image.LANCZOS), (gap + i * (tw + gap), gap))
    pre.save(OUT / "搜尋結果預覽（不用上傳）.jpg", quality=90)
    print("完成", len(SHOTS), "張 ×", len(SIZES), "種尺寸")


if __name__ == "__main__":
    main()
