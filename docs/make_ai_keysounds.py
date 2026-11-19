"""把 ElevenLabs 生成的鍵盤聲轉成鍵盤擴充用的按鍵聲（豆子落碗、木魚、打字機、筆電鍵盤）。

用法（在專案根目錄）：
    python docs/make_ai_keysounds.py <原檔資料夾>

原檔資料夾底下每種一個子資料夾，資料夾名就是下面 PACKS 的鍵（豆子落碗、木魚…），
裡面放 ElevenLabs 音效頁下載的 WAV（v3 模型、3 秒、提示詞影響度 70%、一次生成四個版本都下載）。
來源與授權見 .vibe/機械鍵盤聲音-音檔來源.md。要先裝 ffmpeg 和 numpy。

跟 make_keysounds.py 不一樣的地方：
- 生成的聲音沒有清楚的「彈回」聲，所以只做按下聲，不做 -up- 檔。
  KeySoundPlayer 找不到彈回聲就不播，手指離開時不出聲
- 一個 3 秒的檔裡有好幾下，先自動切成單聲，再把重疊、沒收乾淨、太小聲、開頭有雜音的丟掉
- 單聲不到 12 個的，用上下 2 個半音內的變調補到 12 個（播放時隨機挑，才不會一直聽到同一聲）；
  多的最多留 20 個
- 大鍵（空白、刪除、換行）一樣是取前三個降四個半音

輸出到 KeyboardExtension/Resources/KeySounds/：
    keysound-<套>-<兩位數>.wav     一般鍵按下
    keysound-<套>-fn-<兩位數>.wav  大鍵按下
"""

import subprocess
import sys
import wave
from pathlib import Path

import numpy as np

OUT = Path("KeyboardExtension/Resources/KeySounds")
RATE = 44100
PEAK_DB = -3.0

# 資料夾名 → 套名（檔名裡的字，也是 KeySoundStyle.pack）
PACKS = {
    "豆子落碗": "beans",
    "木魚": "woodblock",
    "打字機": "typewriter",
    "筆電剪刀腳": "laptop",
}

# 切單聲：2 毫秒一格的峰值包絡
WIN = int(RATE * 0.002)
# 比整個檔最大聲小 24 dB 以內、而且比前 30 毫秒的最低點大 12 dB 以上，算一下撞擊
HIT_BELOW_PEAK_DB = 24
HIT_RISE_DB = 12
# 兩下至少隔 80 毫秒，不然算同一下
MIN_GAP_S = 0.08
# 每一聲最長留多久、開頭留多少在撞擊前面
MAX_LEN_S = 0.35
LEAD_S = 0.001
# 篩選門檻
DECAY_DB = 15      # 切斷前要比這一聲的峰小這麼多（沒收乾淨的不要）
QUIET_DB = 18      # 比整個檔最大的那一下小超過這麼多的不要
CLEAN_START_DB = 18  # 撞擊前 10 毫秒要比峰小這麼多（前一聲還在響的不要）
# 切掉尾巴的空白：比峰小這麼多以下算空白
TAIL_SILENCE_DB = 50
# 音量第一次超過峰的這個比例的地方算撞擊起點（跟 make_keysounds.py 的 RISE_RATIO 一樣）
ATTACK_RATIO = 0.25
# 從開始響到一半音量最慢多久（機械鍵盤那三套最慢的是 25 毫秒）
SLOW_ATTACK_S = 0.025

TARGET = 12
MAX_KEEP = 20
SHIFTS = [+1, -1, +2, -2, +1.5, -1.5, +0.5, -0.5]
FN_SHIFT = -4
FN_COUNT = 3


def load(path):
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", str(path), "-f", "s16le", "-ac", "1", "-ar", str(RATE), "-"],
        capture_output=True, check=True,
    ).stdout
    return np.frombuffer(raw, np.int16).astype(np.float32) / 32768


def db(x):
    return 20 * np.log10(max(float(x), 1e-6))


def hits(a):
    """切成一聲一聲，回傳通過篩選的"""
    n = len(a) // WIN
    env = np.abs(a[:n * WIN]).reshape(n, WIN).max(axis=1)
    d = 20 * np.log10(np.maximum(env, 1e-6))
    peak = d.max()
    gap = int(MIN_GAP_S / 0.002)
    onsets = [0] if d[:5].max() > peak - HIT_BELOW_PEAK_DB else []
    for i in range(15, n):
        if d[i] > peak - HIT_BELOW_PEAK_DB and d[i] - d[i - 15:i].min() >= HIT_RISE_DB:
            if not onsets or i - onsets[-1] >= gap:
                onsets.append(i)
    out = []
    for k, i in enumerate(onsets):
        s = max(0, i * WIN - int(RATE * LEAD_S))
        nxt = onsets[k + 1] * WIN - int(RATE * 0.005) if k + 1 < len(onsets) else len(a)
        e = min(nxt, s + int(RATE * MAX_LEN_S))
        if e - s < int(RATE * MIN_GAP_S):
            continue
        seg = a[s:e]
        hp = db(np.abs(seg).max())
        if db(np.abs(seg[-int(RATE * 0.03):]).max()) > hp - DECAY_DB:
            continue
        if hp < peak - QUIET_DB:
            continue
        pre = a[max(0, s - int(RATE * 0.01)):s]
        if i > 0 and len(pre) and db(np.abs(pre).max()) > hp - CLEAN_START_DB:
            continue
        # 前面先一小下、後面才是主要那一聲的不要：從開始響到一半音量超過 25 毫秒，按下去會覺得慢
        mag = np.abs(seg)
        start = int(np.argmax(mag > mag.max() * ATTACK_RATIO))
        if np.argmax(mag > mag.max() * 0.5) - start > RATE * SLOW_ATTACK_S:
            continue
        out.append(seg.copy())
    return out


def shift(a, semis):
    """改播放速度變調（音高和長度一起變），跟 make_keysounds.py 大鍵降音的做法一樣"""
    r = 2 ** (semis / 12)
    n = int(len(a) / r)
    return np.interp(np.arange(n) * r, np.arange(len(a)), a).astype(np.float32)


def finish(a):
    """開頭切到撞擊聲前 1 毫秒、切掉尾巴的空白、淡出 8 毫秒、峰值拉到 -3 dB。
    開頭要切緊：撞擊前有幾十毫秒小聲的雜音的話，手指碰到鍵會覺得慢半拍"""
    a = a * (10 ** (PEAK_DB / 20) / max(np.abs(a).max(), 1e-6))
    attack = int(np.argmax(np.abs(a) > np.abs(a).max() * ATTACK_RATIO))
    a = a[max(0, attack - int(RATE * LEAD_S)):]
    fi = min(len(a), int(RATE * LEAD_S))
    a = a.copy()
    a[:fi] *= np.linspace(0, 1, fi)
    loud = np.where(np.abs(a) > 10 ** ((PEAK_DB - TAIL_SILENCE_DB) / 20))[0]
    end = min(len(a), (loud[-1] if len(loud) else len(a)) + int(RATE * 0.008))
    a = a[:end].copy()
    f = min(len(a), int(RATE * 0.008))
    a[-f:] *= np.linspace(1, 0, f)
    return a


def write(path, a):
    data = np.clip(np.round(a * 32767), -32768, 32767).astype(np.int16)
    with wave.open(str(path), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(data.tobytes())


def main():
    if len(sys.argv) != 2:
        sys.exit(__doc__)
    src = Path(sys.argv[1])
    for folder, pack in PACKS.items():
        origs = []
        for f in sorted((src / folder).glob("*.wav")):
            origs += hits(load(f))
        if not origs:
            sys.exit(f"{folder} 一聲都沒切出來")
        for old in OUT.glob(f"keysound-{pack}-*.wav"):
            old.unlink()
        target = max(TARGET, min(len(origs), MAX_KEEP))
        made = list(origs[:target])
        k = 0
        while len(made) < target:
            made.append(shift(origs[k % len(origs)], SHIFTS[(k // len(origs)) % len(SHIFTS)]))
            k += 1
        for i, a in enumerate(made):
            write(OUT / f"keysound-{pack}-{i + 1:02d}.wav", finish(a))
        for i, a in enumerate(origs[:FN_COUNT]):
            write(OUT / f"keysound-{pack}-fn-{i + 1:02d}.wav", finish(shift(a, FN_SHIFT)))
        print(f"{folder} → {pack}：切出 {len(origs)} 聲，一般鍵 {target} 個、大鍵 {min(FN_COUNT, len(origs))} 個")


if __name__ == "__main__":
    main()
