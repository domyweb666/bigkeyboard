# 把 iPhone 截圖合成 App Store 上架圖（1206 x 2622，放「配備動態島的 iPhone（中型顯示器）」那一格）。
# 用法：python -I make_screenshots.py <原圖資料夾> <輸出資料夾>
# 原圖檔名照格號：1.png、3.png、4.png⋯⋯（第 2 張用 1.png 裁切放大，不用另外截）。
# 要改字、順序、裁切範圍，改 SHOTS 再跑一次。腳本表在 .aso/05-素材文案.md。
import sys
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 1206, 2622
SCREEN_W = 950
BEZEL = 15
SCREEN_RADIUS = 128
SCREEN_TOP = 457
FONT_PATH = r"C:\Windows\Fonts\NotoSansTC-VF.ttf"
FONT_SIZE = 117
LINE_GAP = 31
TEXT_CENTER_Y = 233
SS = 4  # 圓角遮罩的超取樣倍數

# 顏色取自新 icon（docs/icon/douJian.svg）：深綠漸層底、米白豆子；第二行用毛豆綠亮色
BG_TOP = "#0F4A36"
BG_BOTTOM = "#04201A"
LINE1 = "#F8EAD2"
LINE2 = "#9DC2A5"

# 裁切放大：原圖上要留下的範圍（左、上、右、下，0～1 的比例），只用在第 2 張
KEYBOARD_CROP = (0.0, 0.548, 1.0, 0.930)  # 從候選列到空白鍵那排底，泡泡完整（2026-11-15 照實機原圖對過）

# 順序就是上傳順序：(原圖, 輸出檔名, 兩行說明, 裁切範圍或 None)
SHOTS = [
    ("1.png", "1-字大", ["字大的注音鍵盤", "少按錯"], None),
    ("1.png", "2-分色", ["介音藍、韻母橘", "一眼找到要按的鍵"], KEYBOARD_CROP),
    ("3.png", "3-排法", ["排法跟你習慣的一樣", "不用重學"], None),
    ("4.png", "4-隱私", ["打的字只留在手機上", "同步要你自己開"], None),
    ("5.png", "5-一聲", ["沒打聲調？", "按空白當一聲"], None),
    ("6.png", "6-字典", ["改選過的詞", "下次排前面"], None),
    ("7.png", "7-剪貼簿", ["複製過的字", "鍵盤裡點一下就貼"], None),
    ("8.png", "8-主題", ["8 款豆子主題", "冷灰免費"], None),
    ("9.png", "9-紅豆", ["紅豆主題", "楷書鍵帽字"], None),  # 選做：沒有 9.png 就跳過
]


def rounded_mask(size, radius):
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, big.width - 1, big.height - 1), radius * SS, fill=255
    )
    return big.resize(size, Image.LANCZOS)


def gradient(size, top, bottom):
    """上到下的直向漸層"""
    w, h = size
    col = Image.new("RGB", (1, h))
    t, b = Image.new("RGB", (1, 1), top).getpixel((0, 0)), Image.new("RGB", (1, 1), bottom).getpixel((0, 0))
    for y in range(h):
        k = y / (h - 1)
        col.putpixel((0, y), tuple(round(t[i] + (b[i] - t[i]) * k) for i in range(3)))
    return col.resize((w, h))


def headline_font():
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    font.set_variation_by_axes([900])
    return font


def draw_headline(canvas, lines):
    draw = ImageDraw.Draw(canvas)
    font = headline_font()
    ascent, descent = font.getmetrics()
    line_h = ascent + descent
    total = line_h * len(lines) + LINE_GAP * (len(lines) - 1)
    y = TEXT_CENTER_Y - total / 2
    for i, line in enumerate(lines):
        width = draw.textlength(line, font=font)
        if width > W - 120:
            raise ValueError(f"標題太寬：{line}（{width:.0f}px，上限 {W - 120}）")
        draw.text((W / 2, y), line, font=font, fill=LINE1 if i == 0 else LINE2, anchor="ma")
        y += line_h + LINE_GAP


def paste_framed(canvas, shot, radius, bezel, center=False):
    """把畫面加外框、陰影，水平置中貼在標題下面；center=True 時在剩下的空間垂直置中"""
    outer = (shot.width + bezel * 2, shot.height + bezel * 2)
    x = (W - outer[0]) // 2
    y = SCREEN_TOP if not center else SCREEN_TOP + max(0, (H - SCREEN_TOP - outer[1]) // 2 - 60)
    if y + outer[1] > H:
        raise ValueError(f"畫面超出底部：{y + outer[1]} > {H}")
    outer_mask = rounded_mask(outer, radius + bezel)

    shadow = Image.new("L", (W, H), 0)
    shadow.paste(outer_mask.point(lambda v: v * 0.45), (x, y + 18))
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.paste(Image.new("RGB", (W, H), "#000000"), (0, 0), shadow)

    canvas.paste(Image.new("RGB", outer, "#0E0E10"), (x, y), outer_mask)
    canvas.paste(shot, (x + bezel, y + bezel), rounded_mask(shot.size, radius))


def compose(src, lines, crop):
    canvas = gradient((W, H), BG_TOP, BG_BOTTOM)
    draw_headline(canvas, lines)
    shot = Image.open(src).convert("RGB")
    if crop:
        box = tuple(round(v * (shot.width if i % 2 == 0 else shot.height)) for i, v in enumerate(crop))
        shot = shot.crop(box)
        target_w = W - 80
        shot = shot.resize((target_w, round(shot.height * target_w / shot.width)), Image.LANCZOS)
        paste_framed(canvas, shot, radius=56, bezel=0, center=True)
    else:
        shot = shot.resize((SCREEN_W, round(shot.height * SCREEN_W / shot.width)), Image.LANCZOS)
        paste_framed(canvas, shot, radius=SCREEN_RADIUS, bezel=BEZEL)
    return canvas


def search_preview(images, path):
    """前三張縮成搜尋結果那麼小（一張約 200 像素寬），給閘門 4 的 5 秒測試用"""
    thumb_w, gap = 200, 12
    thumb_h = round(H * thumb_w / W)
    sheet = Image.new("RGB", (thumb_w * 3 + gap * 4, thumb_h + gap * 2), "#FFFFFF")
    for i, im in enumerate(images[:3]):
        sheet.paste(im.resize((thumb_w, thumb_h), Image.LANCZOS), (gap + i * (thumb_w + gap), gap))
    sheet.save(path, quality=90)


def contact_sheet(images, path):
    thumb_w, gap, cols = 400, 24, 3
    thumb_h = round(H * thumb_w / W)
    rows = (len(images) + cols - 1) // cols
    sheet = Image.new("RGB", (thumb_w * cols + gap * (cols + 1), thumb_h * rows + gap * (rows + 1)), "#FFFFFF")
    for i, im in enumerate(images):
        sheet.paste(
            im.resize((thumb_w, thumb_h), Image.LANCZOS),
            (gap + (i % cols) * (thumb_w + gap), gap + (i // cols) * (thumb_h + gap)),
        )
    sheet.save(path, quality=88)


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    src_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    images = []
    for filename, name, lines, crop in SHOTS:
        src = src_dir / filename
        if not src.exists():
            print(f"跳過 {name}：沒有 {src}")
            continue
        im = compose(src, lines, crop)
        im.save(out_dir / f"{name}.png", optimize=True)
        images.append(im)
        print(f"完成 {name}")
    if images:
        search_preview(images, out_dir / "搜尋結果預覽（不用上傳）.jpg")
        contact_sheet(images, out_dir / "總覽（不用上傳）.jpg")


if __name__ == "__main__":
    main()
