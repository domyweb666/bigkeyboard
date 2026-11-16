"""把下載來的 CC0 鍵盤錄音轉成鍵盤擴充用的按鍵聲。

用法（在專案根目錄）：
    python docs/make_keysounds.py <StavSounds 的 zip 或資料夾> <jim-ph 的 zip 或資料夾>

來源與授權見 .vibe/機械鍵盤聲音-音檔來源.md。要先裝 ffmpeg。

每個檔做的事：單聲道、44.1 kHz、16 bit wav；峰值拉齊到 -3 dB；切掉頭尾的空白；
尾巴淡出幾毫秒免得有爆音。輸出到 KeyboardExtension/Resources/KeySounds/，檔名
keysound-<套>-<兩位數>.wav。另外每套挑前三個降四個半音，當空白、刪除、換行這些
大鍵的聲音（檔名多一個 -fn-）：真的鍵盤上大鍵的聲音本來就比較低。
"""

import re
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

OUT = Path("KeyboardExtension/Resources/KeySounds")
AUDIO = {".wav", ".ogg", ".mp3", ".flac", ".aiff", ".aif"}
RATE = 44100
PEAK_DB = -3.0
# 比這小聲的算空白（音量拉齊之後量的）
SILENCE_DB = -50
# 大鍵降多少：2 ** (-4 / 12)
LOW_RATIO = 0.7937
LOW_COUNT = 3

# 套名 → 原檔檔名裡要有的字（不分大小寫）
PACKS = {
    "clicky": "clicky",
    "tactile": "tactile",
    "vintage": "keyboard",
}


def natural(path):
    """Keyboard_Clicky_2 排在 Keyboard_Clicky_10 前面"""
    return [int(s) if s.isdigit() else s.lower() for s in re.split(r"(\d+)", path.name)]


def collect(source, workdir):
    """zip 先解開；回傳裡面所有的音檔"""
    source = Path(source)
    if source.is_file() and source.suffix.lower() == ".zip":
        target = Path(workdir) / source.stem
        with zipfile.ZipFile(source) as z:
            z.extractall(target)
        source = target
    return sorted((p for p in source.rglob("*") if p.suffix.lower() in AUDIO), key=natural)


def peak_db(path, filters):
    """套完濾鏡之後的峰值（dB）"""
    result = subprocess.run(
        ["ffmpeg", "-hide_banner", "-i", str(path), "-af", filters + ",volumedetect", "-f", "null", "-"],
        capture_output=True,
        text=True,
        encoding="utf-8",
        errors="replace",
        check=True,
    )
    found = re.search(r"max_volume: (-?[\d.]+) dB", result.stderr)
    if not found:
        raise RuntimeError(f"量不到音量：{path}")
    return float(found.group(1))


def convert(src, dst, low=False):
    # 先轉單聲道再量音量：留到最後才轉的話，立體聲合成單聲道會變大聲，量到的峰值就不準
    mono = "aformat=sample_fmts=s16:channel_layouts=mono"
    gain = PEAK_DB - peak_db(src, mono)
    # 音量先拉齊再切空白：門檻是照拉齊後的音量算的，原檔錄得小聲的才不會連尾音一起被切掉
    trim = f"silenceremove=start_periods=1:start_threshold={SILENCE_DB}dB"
    filters = f"{mono},volume={gain:.2f}dB,{trim},areverse,{trim},areverse"
    if low:
        filters += f",asetrate={RATE}*{LOW_RATIO}"
    # 尾巴淡出幾毫秒，免得切斷的地方有爆音
    filters += f",aresample={RATE},areverse,afade=t=in:d=0.008,areverse"
    subprocess.run(
        ["ffmpeg", "-hide_banner", "-loglevel", "error", "-y", "-i", str(src),
         "-af", filters, "-ac", "1", "-ar", str(RATE), "-c:a", "pcm_s16le", str(dst)],
        check=True,
    )


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("keysound-*.wav"):
        old.unlink()
    with tempfile.TemporaryDirectory() as workdir:
        files = [f for source in sys.argv[1:] for f in collect(source, workdir)]
        used = set()
        for pack, word in PACKS.items():
            # 「keyboard」會撞到 Keyboard_Clicky 這種檔名：前面的套拿走的不再算
            mine = [f for f in files if word in f.name.lower() and f not in used]
            used.update(mine)
            if not mine:
                print(f"{pack}：找不到檔名裡有「{word}」的音檔，這套先不放")
                continue
            for i, src in enumerate(mine, start=1):
                convert(src, OUT / f"keysound-{pack}-{i:02d}.wav")
            for i, src in enumerate(mine[:LOW_COUNT], start=1):
                convert(src, OUT / f"keysound-{pack}-fn-{i:02d}.wav", low=True)
            print(f"{pack}：{len(mine)} 個鍵聲、{min(len(mine), LOW_COUNT)} 個大鍵聲")
            for src in mine:
                print(f"    {src.name}")
    total = sum(p.stat().st_size for p in OUT.glob("keysound-*.wav"))
    print(f"共 {len(list(OUT.glob('keysound-*.wav')))} 個檔，{total / 1024:.0f} KB，在 {OUT}")


if __name__ == "__main__":
    main()
