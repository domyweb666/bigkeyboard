# 把 iPhone 螢幕錄影剪成 App Store 預覽影片（886 x 1920 直式、30 fps、H.264、15～30 秒）。
# 版面跟上架截圖一樣：深綠漸層底、上面兩行字、下面是手機畫面。
# 用法：python -I make_preview.py <錄影資料夾> <輸出檔.mp4>
# 要改每段用哪支錄影、從第幾秒開始、多長、字卡寫什麼，改 SEGMENTS 再跑一次。腳本表在 .aso/05-影片.md。
# 需要 ffmpeg（winget install ffmpeg）。
import subprocess
import sys
import tempfile
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageFont

W, H = 886, 1920
FPS = 30
K = W / 1206  # 從上架截圖的尺寸等比例縮
SCREEN_W = round(950 * K) // 2 * 2
BEZEL = round(15 * K)
SCREEN_RADIUS = round(128 * K)
SCREEN_TOP = round(457 * K)
FONT_PATH = r"C:\Windows\Fonts\NotoSansTC-VF.ttf"
FONT_SIZE = round(117 * K)
LINE_GAP = round(31 * K)
TEXT_CENTER_Y = round(233 * K)
SS = 4
BG_TOP, BG_BOTTOM = "#0F4A36", "#04201A"
LINE1, LINE2 = "#F8EAD2", "#9DC2A5"

# (錄影檔, 從第幾秒開始, 用幾秒, 兩行字卡)
SEGMENTS = [
    ("1-打字.mp4", 0.0, 5.0, ["字大的注音鍵盤", "少按錯"]),
    ("2-一聲.mp4", 0.0, 7.0, ["沒打聲調？", "按空白當一聲"]),
    ("3-主題.mp4", 0.0, 6.0, ["8 款豆子主題", "冷灰免費"]),
    ("4-剪貼簿.mp4", 0.0, 6.0, ["複製過的字", "鍵盤裡點一下就貼"]),
]


def rounded_mask(size, radius):
    big = Image.new("L", (size[0] * SS, size[1] * SS), 0)
    ImageDraw.Draw(big).rounded_rectangle((0, 0, big.width - 1, big.height - 1), radius * SS, fill=255)
    return big.resize(size, Image.LANCZOS)


def gradient():
    t = Image.new("RGB", (1, 1), BG_TOP).getpixel((0, 0))
    b = Image.new("RGB", (1, 1), BG_BOTTOM).getpixel((0, 0))
    col = Image.new("RGB", (1, H))
    for y in range(H):
        k = y / (H - 1)
        col.putpixel((0, y), tuple(round(t[i] + (b[i] - t[i]) * k) for i in range(3)))
    return col.resize((W, H))


def screen_height(clip):
    """錄影的長寬，換算成畫面在影片裡的高度"""
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=width,height",
         "-of", "csv=p=0:s=x", str(clip)],
        capture_output=True, text=True, check=True,
    ).stdout.strip().split("\n")[0]
    w, h = (int(v) for v in out.split("x"))
    return round(h * SCREEN_W / w) // 2 * 2


def overlay_png(lines, screen_h, path):
    """整張版面，手機螢幕那塊挖空（透明），影片從底下透出來"""
    canvas = gradient().convert("RGBA")
    draw = ImageDraw.Draw(canvas)
    font = ImageFont.truetype(FONT_PATH, FONT_SIZE)
    font.set_variation_by_axes([900])
    ascent, descent = font.getmetrics()
    line_h = ascent + descent
    y = TEXT_CENTER_Y - (line_h * len(lines) + LINE_GAP * (len(lines) - 1)) / 2
    for i, line in enumerate(lines):
        if draw.textlength(line, font=font) > W - 90:
            raise ValueError(f"字卡太寬：{line}")
        draw.text((W / 2, y), line, font=font, fill=LINE1 if i == 0 else LINE2, anchor="ma")
        y += line_h + LINE_GAP

    outer = (SCREEN_W + BEZEL * 2, screen_h + BEZEL * 2)
    x0 = (W - outer[0]) // 2
    if SCREEN_TOP + outer[1] > H:
        raise ValueError("畫面超出底部")
    outer_mask = rounded_mask(outer, SCREEN_RADIUS + BEZEL)
    shadow = Image.new("L", (W, H), 0)
    shadow.paste(outer_mask.point(lambda v: v * 0.45), (x0, SCREEN_TOP + 13))
    shadow = shadow.filter(ImageFilter.GaussianBlur(26))
    canvas.paste(Image.new("RGBA", (W, H), (0, 0, 0, 255)), (0, 0), shadow)
    canvas.paste(Image.new("RGBA", outer, (14, 14, 16, 255)), (x0, SCREEN_TOP), outer_mask)

    hole = Image.new("L", (W, H), 0)
    hole.paste(rounded_mask((SCREEN_W, screen_h), SCREEN_RADIUS), (x0 + BEZEL, SCREEN_TOP + BEZEL))
    alpha = canvas.getchannel("A").point(lambda v: v)
    alpha.paste(0, (0, 0, W, H), hole)
    canvas.putalpha(alpha)
    canvas.save(path)
    return x0 + BEZEL, SCREEN_TOP + BEZEL


def render_segment(clip, start, dur, lines, png, out):
    sh = screen_height(clip)
    x, y = overlay_png(lines, sh, png)
    graph = (
        f"color=c=black:s={W}x{H}:r={FPS}:d={dur}[base];"
        f"[0:v]fps={FPS},scale={SCREEN_W}:{sh},setsar=1[v];"
        f"[base][v]overlay={x}:{y}:shortest=1[a];"
        f"[a][1:v]overlay=0:0,format=yuv420p[out]"
    )
    subprocess.run(
        ["ffmpeg", "-y", "-v", "error", "-ss", str(start), "-t", str(dur), "-i", str(clip),
         "-loop", "1", "-i", str(png),
         "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000",
         "-filter_complex", graph, "-map", "[out]", "-map", "2:a", "-t", str(dur),
         "-c:v", "libx264", "-profile:v", "high", "-level", "4.0", "-preset", "slow", "-crf", "18",
         "-r", str(FPS), "-c:a", "aac", "-b:a", "256k", "-ar", "48000", str(out)],
        check=True,
    )


def main():
    sys.stdout.reconfigure(encoding="utf-8")
    src_dir, out_file = Path(sys.argv[1]), Path(sys.argv[2])
    total = sum(s[2] for s in SEGMENTS)
    if not 15 <= total <= 30:
        raise ValueError(f"總長 {total} 秒，App Store 要 15～30 秒")
    with tempfile.TemporaryDirectory() as tmp:
        tmp = Path(tmp)
        parts = []
        for i, (name, start, dur, lines) in enumerate(SEGMENTS):
            clip = src_dir / name
            if not clip.exists():
                raise FileNotFoundError(f"沒有錄影：{clip}")
            part = tmp / f"part{i}.mp4"
            render_segment(clip, start, dur, lines, tmp / f"overlay{i}.png", part)
            parts.append(part)
            print(f"完成第 {i + 1} 段：{name}（{dur} 秒）")
        listing = tmp / "list.txt"
        listing.write_text("".join(f"file '{p.as_posix()}'\n" for p in parts), encoding="utf-8")
        out_file.parent.mkdir(parents=True, exist_ok=True)
        subprocess.run(
            ["ffmpeg", "-y", "-v", "error", "-f", "concat", "-safe", "0", "-i", str(listing),
             "-c", "copy", "-movflags", "+faststart", str(out_file)],
            check=True,
        )
    print(f"輸出：{out_file}（{total} 秒）")
    print("封面畫格：建議第 2 秒（第一段打字、泡泡跳出來那格），在 App Store Connect 選")


if __name__ == "__main__":
    main()
