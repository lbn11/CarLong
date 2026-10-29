#!/usr/bin/env python3
"""生成休闲游戏背景音乐（纯标准库，无需 numpy / 第三方音源）。

为什么自己合成而不是下载：
  * 零版权风险（全部是程序生成的原创音频）。
  * 体积可控，风格统一（同一套合成参数，听感像同一位作曲家的作品）。
  * 想换曲子只改 TRACKS 参数重跑即可。

产出一版 16 小节的循环曲子（~30-40 秒），导出 mono WAV 到
build/music/，再由调用方用 ffmpeg 转成 iOS/Android 都原生支持的
AAC（.m4a）。iOS 的 AVAudioPlayer 不支持 ogg，这一点必须记住。

用法：
  python3 tool/gen_music.py            # 生成全部
  python3 tool/gen_music.py boss home  # 只生成指定几首
"""

import math
import os
import random
import struct
import sys
import wave

SR = 44100

# 音名 -> MIDI（以 C3=48 为基准）
ROOTS = {
    'C': 48, 'C#': 49, 'D': 50, 'Eb': 51, 'E': 52, 'F': 53, 'F#': 54,
    'G': 55, 'Ab': 56, 'A': 57, 'Bb': 58, 'B': 59,
}

CHORDS = {
    'maj': [0, 4, 7],
    'min': [0, 3, 7],
    'dom7': [0, 4, 7, 10],
    'min7': [0, 3, 7, 10],
    'sus4': [0, 5, 7],
}

# 每首曲子：bpm / 和弦走向 / 风格 / 小节数
# 走向用 I-V-vi-IV 之类的「万能流行进行」，听感稳定、不会刺耳。
TRACKS = [
    dict(name='home', bpm=100, bars=16, style='warm',
         prog=[('C', 'maj'), ('G', 'maj'), ('A', 'min'), ('F', 'maj')]),
    dict(name='merge_1', bpm=116, bars=16, style='bright',
         prog=[('G', 'maj'), ('D', 'maj'), ('E', 'min'), ('C', 'maj')]),
    dict(name='merge_2', bpm=122, bars=16, style='bouncy',
         prog=[('D', 'maj'), ('A', 'maj'), ('B', 'min'), ('G', 'maj')]),
    dict(name='merge_3', bpm=96, bars=16, style='mellow',
         prog=[('F', 'maj'), ('C', 'maj'), ('D', 'min'), ('Bb', 'maj')]),
    dict(name='parking_1', bpm=92, bars=16, style='chill',
         prog=[('A', 'min'), ('F', 'maj'), ('C', 'maj'), ('G', 'maj')]),
    dict(name='parking_2', bpm=88, bars=16, style='soft',
         prog=[('E', 'min'), ('A', 'min'), ('C', 'maj'), ('B', 'maj')]),
    dict(name='boss', bpm=138, bars=16, style='boss',
         prog=[('A', 'min'), ('F', 'maj'), ('G', 'maj'), ('E', 'maj')]),
]

# 风格参数：包络、配器密度、鼓组开关
STYLES = {
    'warm':   dict(arp_div=2, pad_amp=0.16, arp_amp=0.10, bass_amp=0.22,
                   kick=False, snare=False, hat=False, arp_decay=5.0),
    'bright': dict(arp_div=4, pad_amp=0.13, arp_amp=0.095, bass_amp=0.22,
                   kick=True, snare=False, hat=True, arp_decay=7.0),
    'bouncy': dict(arp_div=4, pad_amp=0.11, arp_amp=0.10, bass_amp=0.24,
                   kick=True, snare=True, hat=True, arp_decay=8.0),
    'mellow': dict(arp_div=2, pad_amp=0.18, arp_amp=0.09, bass_amp=0.20,
                   kick=False, snare=False, hat=False, arp_decay=4.0),
    'chill':  dict(arp_div=2, pad_amp=0.17, arp_amp=0.085, bass_amp=0.19,
                   kick=True, snare=False, hat=True, arp_decay=3.5),
    'soft':   dict(arp_div=2, pad_amp=0.16, arp_amp=0.08, bass_amp=0.18,
                   kick=False, snare=False, hat=True, arp_decay=3.5),
    'boss':   dict(arp_div=4, pad_amp=0.10, arp_amp=0.11, bass_amp=0.28,
                   kick=True, snare=True, hat=True, arp_decay=9.0),
}


def hz(midi):
    return 440.0 * (2.0 ** ((midi - 69) / 12.0))


def make_buffer(seconds):
    return [0.0] * int(seconds * SR)


def add_tone(buf, start, dur, midi, amp, kind='pluck', decay=5.0,
             harmonics=(1.0, 0.5, 0.25), attack=0.006, detune=0.0):
    """往缓冲区叠加一个音。kind: pluck / pad。"""
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    if n0 >= len(buf) or n1 <= n0:
        return
    f = hz(midi + detune)
    two_pi_f = 2.0 * math.pi * f
    for n in range(n0, n1):
        t = (n - n0) / SR
        if kind == 'pluck':
            env = math.exp(-decay * t) * (1.0 - math.exp(-t / attack))
        else:  # pad：慢起、平台、慢收
            a = 0.28
            rel = 0.22
            if t < a:
                env = t / a
            elif t > dur - rel:
                env = max(0.0, (dur - t) / rel)
            else:
                env = 1.0
        ph = two_pi_f * t
        s = 0.0
        for h, ha in enumerate(harmonics, start=1):
            s += ha * math.sin(ph * h)
        buf[n] += amp * env * s


def add_kick(buf, start, amp=0.5):
    dur = 0.16
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    for n in range(n0, n1):
        t = (n - n0) / SR
        f = 120.0 * math.exp(-t * 16.0) + 42.0
        env = math.exp(-t * 11.0)
        buf[n] += amp * env * math.sin(2.0 * math.pi * f * t)


def add_snare(buf, start, amp=0.22):
    dur = 0.13
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    rng = random.Random(int(start * 1000) + 7)
    for n in range(n0, n1):
        t = (n - n0) / SR
        env = math.exp(-t * 26.0)
        noise = rng.uniform(-1.0, 1.0)
        body = 0.5 * math.sin(2.0 * math.pi * 185.0 * t)
        buf[n] += amp * env * (0.7 * noise + body)


def add_hat(buf, start, amp=0.10):
    dur = 0.05
    n0 = int(start * SR)
    n1 = min(len(buf), int((start + dur) * SR))
    rng = random.Random(int(start * 1000) + 31)
    prev = 0.0
    for n in range(n0, n1):
        t = (n - n0) / SR
        env = math.exp(-t * 70.0)
        noise = rng.uniform(-1.0, 1.0)
        hp = noise - prev  # 简易高通，压掉低频
        prev = noise
        buf[n] += amp * env * hp


def build_track(spec):
    style = STYLES[spec['style']]
    bpm = spec['bpm']
    bars = spec['bars']
    beat = 60.0 / bpm
    bar_len = beat * 4
    total = bars * bar_len
    buf = make_buffer(total + 0.5)

    prog = spec['prog']

    for b in range(bars):
        t0 = b * bar_len
        root_name, chord_type = prog[b % len(prog)]
        root = ROOTS[root_name]
        tones = [root + iv for iv in CHORDS[chord_type]]

        # ---- Pad：整小节铺和弦（高八度，柔）----
        for m in tones:
            add_tone(buf, t0, bar_len * 0.98, m + 12, style['pad_amp'],
                     kind='pad', harmonics=(1.0, 0.35, 0.12))
            add_tone(buf, t0, bar_len * 0.98, m + 12, style['pad_amp'] * 0.6,
                     kind='pad', harmonics=(1.0, 0.3), detune=0.12)

        # ---- Bass：1、3 拍根音 ----
        for beat_i in (0, 2):
            add_tone(buf, t0 + beat_i * beat, beat * 1.6, root - 12,
                     style['bass_amp'], kind='pluck', decay=3.2,
                     harmonics=(1.0, 0.5, 0.2), attack=0.004)

        # ---- Arp：按 arp_div 均匀排布，循环和弦音 ----
        div = style['arp_div']
        step = bar_len / (div * 4)  # 每小节 div*4 个音
        pattern = []
        for i in range(div * 4):
            pattern.append(tones[i % len(tones)] + 24 - (12 if i % 8 >= 4 else 0))
        for i, m in enumerate(pattern):
            add_tone(buf, t0 + i * step, step * 1.4, m, style['arp_amp'],
                     kind='pluck', decay=style['arp_decay'],
                     harmonics=(1.0, 0.4, 0.18))

        # ---- 鼓 ----
        if style['kick']:
            add_kick(buf, t0, 0.42)
            add_kick(buf, t0 + beat * 2, 0.42)
            if spec['style'] in ('bouncy', 'boss'):
                add_kick(buf, t0 + beat * 3.5, 0.30)
        if style['snare']:
            add_snare(buf, t0 + beat * 1, 0.20)
            add_snare(buf, t0 + beat * 3, 0.20)
        if style['hat']:
            for k in range(2, 9):  # 反拍 8 分
                add_hat(buf, t0 + k * beat * 0.5, 0.085)

    # ---- 母带：轻低通 + tanh 软限幅 + 归一 ----
    out = []
    y = 0.0
    a = 0.55  # 一阶低通系数（约 8kHz）
    for x in buf:
        y += a * (x - y)
        out.append(math.tanh(y * 1.1))

    peak = max(1e-9, max(abs(v) for v in out))
    norm = 0.89 / peak
    n = len(out)
    fade = int(0.012 * SR)
    for i in range(n):
        v = out[i] * norm
        if i < fade:
            v *= i / fade
        elif i > n - fade:
            v *= (n - i) / fade
        out[i] = v
    return out


def write_wav(path, samples):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with wave.open(path, 'wb') as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = bytearray()
        for v in samples:
            iv = int(max(-1.0, min(1.0, v)) * 32767)
            frames += struct.pack('<h', iv)
        w.writeframes(bytes(frames))


def main(argv):
    here = os.path.dirname(os.path.abspath(__file__))
    out_dir = os.path.join(here, '..', 'build', 'music')
    wanted = set(argv[1:]) if len(argv) > 1 else None
    for spec in TRACKS:
        if wanted and spec['name'] not in wanted:
            continue
        print(f'generating {spec["name"]} ...', flush=True)
        samples = build_track(spec)
        path = os.path.join(out_dir, spec['name'] + '.wav')
        write_wav(path, samples)
        print(f'  -> {os.path.normpath(path)} ({len(samples)/SR:.1f}s)', flush=True)


if __name__ == '__main__':
    main(sys.argv)
