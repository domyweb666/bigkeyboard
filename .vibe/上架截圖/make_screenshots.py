# 把手機截圖合成 App Store 上架圖（1206 x 2622，放「配備動態島的 iPhone（中型顯示器）」那一格）。
# 用法：python -I make_screenshots.py <截圖資料夾> <輸出資料夾>
# 要改文字或底色，改 SHOTS 再跑一次。
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

# 順序就是上傳順序
SHOTS = [
    ("IMG_1926.PNG", "1-字大鍵緊", ["字大鍵緊", "少按錯"], "#2D6AD6"),
    ("IMG_1927.PNG", "2-深色模式", ["手機切深色", "鍵盤跟著切"], "#C4641A"),
    ("IMG_1925.PNG", "3-主題", ["8 款主題", "冷灰免費"], "#5B8A2C"),
    ("IMG_1928.PNG", "4-紅豆", ["紅豆主題", "楷書鍵帽字"], "#A5524B"),
    ("IMG_1929.PNG", "5-蝶豆花", ["蝶豆花主題", "介音藍、韻母淡紫"], "#5B57B5"),
    ("IMG_1930.PNG", "6-字典", ["自動學你打的詞", "只存在你手機上"], "#23806F"),
]


def rounded_mask(size, radius):
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle(
        (0, 0, big.width - 1, big.height - 1), radius * SS, fill=255
    )
    return big.resize(size, Image.LANCZOS)


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
    for line in lines:
        draw.text((W / 2, y), line, font=font, fill="#FFFFFF", anchor="ma")
        width = draw.textlength(line, font=font)
        if width > W - 120:
            raise ValueError(f"標題太寬：{line}（{width:.0f}px）")
        y += line_h + LINE_GAP


def compose(src, lines, bg):
    canvas = Image.new("RGB", (W, H), bg)
    draw_headline(canvas, lines)

    shot = Image.open(src).convert("RGB")
    screen_h = round(shot.height * SCREEN_W / shot.width)
    shot = shot.resize((SCREEN_W, screen_h), Image.LANCZOS)

    outer = (SCREEN_W + BEZEL * 2, screen_h + BEZEL * 2)
    x = (W - outer[0]) // 2
    y = SCREEN_TOP
    outer_mask = rounded_mask(outer, SCREEN_RADIUS + BEZEL)

    # 陰影
    shadow = Image.new("L", (W, H), 0)
    shadow.paste(outer_mask.point(lambda v: v * 0.38), (x, y + 18))
    shadow = shadow.filter(ImageFilter.GaussianBlur(36))
    canvas.paste(Image.new("RGB", (W, H), "#000000"), (0, 0), shadow)

    # 外框與畫面
    canvas.paste(Image.new("RGB", outer, "#0E0E10"), (x, y), outer_mask)
    canvas.paste(
        shot,
        (x + BEZEL, y + BEZEL),
        rounded_mask((SCREEN_W, screen_h), SCREEN_RADIUS),
    )
    if y + outer[1] > H:
        raise ValueError(f"畫面超出底部：{y + outer[1]} > {H}")
    return canvas


def contact_sheet(images, path):
    thumb_w = 400
    thumb_h = round(H * thumb_w / W)
    gap = 24
    sheet = Image.new(
        "RGB",
        (thumb_w * 3 + gap * 4, thumb_h * 2 + gap * 3),
        "#FFFFFF",
    )
    for i, im in enumerate(images):
        sheet.paste(
            im.resize((thumb_w, thumb_h), Image.LANCZOS),
            (gap + (i % 3) * (thumb_w + gap), gap + (i // 3) * (thumb_h + gap)),
        )
    sheet.save(path, quality=88)


def main():
    src_dir, out_dir = Path(sys.argv[1]), Path(sys.argv[2])
    out_dir.mkdir(parents=True, exist_ok=True)
    images = []
    for filename, name, lines, bg in SHOTS:
        im = compose(src_dir / filename, lines, bg)
        im.save(out_dir / f"{name}.png", optimize=True)
        images.append(im)
    contact_sheet(images, out_dir / "總覽（不用上傳）.jpg")


if __name__ == "__main__":
    main()
