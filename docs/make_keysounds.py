"""把下載來的 CC0 鍵盤錄音轉成鍵盤擴充用的按鍵聲。

用法（在專案根目錄）：
    python docs/make_keysounds.py <StavSounds 的 zip 或資料夾> <jim-ph 的 zip 或資料夾>

來源與授權見 .vibe/機械鍵盤聲音-音檔來源.md。要先裝 ffmpeg 和 numpy。

每個檔做兩步：
1. 轉檔：單聲道、44.1 kHz、16 bit wav；峰值拉齊；切掉頭尾的空白；尾巴淡出幾毫秒免得有爆音。
2. 切開：一個錄音是「按下去」「彈回來」兩聲連在一起，中間隔多久是錄音的人按多久。
   整個播的話彈回聲永遠隔一樣久，跟手指對不上，所以切成兩個檔：鍵盤在手指碰到鍵時播按下那聲，
   手指離開時播彈回那聲。每一聲的開頭切到撞擊聲前 1 毫秒（原本有的檔要等幾十毫秒才出聲，聽起來慢半拍）。
   按下聲峰值拉到 -3 dB，彈回聲 -9 dB（真的鍵盤彈回來本來就比較小聲）。

輸出到 KeyboardExtension/Resources/KeySounds/：
    keysound-<套>-<兩位數>.wav       一般鍵按下
    keysound-<套>-up-<兩位數>.wav    一般鍵彈回
    keysound-<套>-fn-<兩位數>.wav    大鍵按下（空白、刪除、換行）
    keysound-<套>-fn-up-<兩位數>.wav 大鍵彈回
大鍵是每套挑前三個錄音降四個半音：真的鍵盤上大鍵的聲音本來就比較低。
"""

import re
import subprocess
import sys
import tempfile
import wave
import zipfile
from pathlib import Path

import numpy as np

OUT = Path("KeyboardExtension/Resources/KeySounds")
AUDIO = {".wav", ".ogg", ".mp3", ".flac", ".aiff", ".aif"}
RATE = 44100
PEAK_DB = -3.0
# 比這小聲的算空白（音量拉齊之後量的）
SILENCE_DB = -50
# 大鍵降多少：2 ** (-4 / 12)
LOW_RATIO = 0.7937
LOW_COUNT = 3

# 切開「按下」「彈回」用的參數
# 音量包絡：每 1 毫秒量一次前後共 5 毫秒的均方根
ENVELOPE_MS = 5
# 比整個檔最大聲的地方的這個比例還大聲的峰才算一下撞擊
HIT_RATIO = 0.25
# 相隔不到這麼久的峰算同一下（按到底的那一聲常有兩個峰）
MERGE_MS = 50
# 音量從峰的這個比例以下升上來的地方，算這一下撞擊的起點
RISE_RATIO = 0.25
# 每一聲的開頭留多久在撞擊聲前面、淡入多久
LEAD_MS = 1.0
# 切出來比這還短的不要（多半是錄音尾巴被切到的半聲）
MIN_PART_MS = 25
# 按下聲的尾巴（被切在彈回聲前面）淡出多久
TAIL_FADE_MS = 8
DOWN_PEAK_DB = -3.0
UP_PEAK_DB = -9.0

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


def read_wav(path):
    with wave.open(str(path)) as w:
        return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float64) / 32768


def write_wav(path, samples):
    data = np.clip(np.round(samples * 32767), -32768, 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def envelope(x):
    """每 1 毫秒一格的音量（前後共 ENVELOPE_MS 毫秒的均方根）"""
    step = RATE // 1000
    half = RATE * ENVELOPE_MS // 2000
    power = np.concatenate(([0.0], np.cumsum(x * x)))
    centers = np.arange(0, len(x), step)
    lo = np.clip(centers - half, 0, len(x))
    hi = np.clip(centers + half, 0, len(x))
    return np.sqrt((power[hi] - power[lo]) / np.maximum(hi - lo, 1))


def hits(env):
    """錄音裡每一下撞擊的位置（毫秒）：第一下是按下去，第二下是彈回來，再有就是又按了一次"""
    loud = env.max() * HIT_RATIO
    found = []
    for i, level in enumerate(env):
        if level < loud or level < env[max(0, i - 12):i + 13].max():
            continue
        if found and i - found[-1] < MERGE_MS:
            continue
        found.append(i)
    return found


def onset(x, env, hit, earliest):
    """這一下撞擊從哪個取樣點開始。
    先從峰往前退到音量掉到峰的 RISE_RATIO 以下（上一聲的尾音還在響，不能只找最小聲的地方），
    再從那附近找第一個夠大聲的取樣點，往前留 LEAD_MS"""
    step = RATE // 1000
    search_from = max(earliest, hit - MERGE_MS)
    quiet = [i for i in range(search_from, hit) if env[i] < env[hit] * RISE_RATIO]
    rise = quiet[-1] if quiet else search_from + int(np.argmin(env[search_from:hit + 1]))
    begin = max(search_from, rise - ENVELOPE_MS) * step
    region = np.abs(x[begin:(hit + ENVELOPE_MS) * step])
    first = begin + int(np.argmax(region > region.max() * RISE_RATIO))
    return max(begin, first - int(RATE * LEAD_MS / 1000))


def split(x):
    """把一個錄音切成一段一段，回傳 [("down" 或 "up", 取樣)]"""
    env = envelope(x)
    found = hits(env)
    starts = [onset(x, env, hit, found[i - 1] if i else 0) for i, hit in enumerate(found)]
    lead = int(RATE * LEAD_MS / 1000)
    parts = []
    for i, start in enumerate(starts):
        end = starts[i + 1] if i + 1 < len(starts) else len(x)
        part = x[start:end].copy()
        part[:lead] *= np.linspace(0, 1, lead)
        if end < len(x):
            fade = min(len(part), int(RATE * TAIL_FADE_MS / 1000))
            part[-fade:] *= np.linspace(1, 0, fade)
        if len(part) < RATE * MIN_PART_MS // 1000:
            continue
        kind = "down" if i % 2 == 0 else "up"
        target = DOWN_PEAK_DB if kind == "down" else UP_PEAK_DB
        part *= 10 ** (target / 20) / np.abs(part).max()
        parts.append((kind, part))
    return parts


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(1)
    OUT.mkdir(parents=True, exist_ok=True)
    for old in OUT.glob("keysound-*.wav"):
        old.unlink()
    with tempfile.TemporaryDirectory() as workdir:
        files = [f for source in sys.argv[1:] for f in collect(source, workdir)]
        whole = Path(workdir) / "whole.wav"
        used = set()
        for pack, word in PACKS.items():
            # 「keyboard」會撞到 Keyboard_Clicky 這種檔名：前面的套拿走的不再算
            mine = [f for f in files if word in f.name.lower() and f not in used]
            used.update(mine)
            if not mine:
                print(f"{pack}：找不到檔名裡有「{word}」的音檔，這套先不放")
                continue
            # 檔名中間的字 → 這一類已經出了幾個
            counts = {"": 0, "up-": 0, "fn-": 0, "fn-up-": 0}
            for low, sources in ((False, mine), (True, mine[:LOW_COUNT])):
                for src in sources:
                    convert(src, whole, low=low)
                    parts = split(read_wav(whole))
                    for kind, part in parts:
                        tag = ("fn-" if low else "") + ("up-" if kind == "up" else "")
                        counts[tag] += 1
                        write_wav(OUT / f"keysound-{pack}-{tag}{counts[tag]:02d}.wav", part)
                    if not low:
                        lengths = "、".join(f"{kind} {len(part) * 1000 // RATE} 毫秒" for kind, part in parts)
                        print(f"    {src.name}：{lengths}")
            print(f"{pack}：按下 {counts['']} 個、彈回 {counts['up-']} 個；"
                  f"大鍵按下 {counts['fn-']} 個、彈回 {counts['fn-up-']} 個")
    total = sum(p.stat().st_size for p in OUT.glob("keysound-*.wav"))
    print(f"共 {len(list(OUT.glob('keysound-*.wav')))} 個檔，{total / 1024:.0f} KB，在 {OUT}")


if __name__ == "__main__":
    main()
