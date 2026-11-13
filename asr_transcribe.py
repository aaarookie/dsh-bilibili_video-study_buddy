#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
asr_transcribe.py —— 用 faster-whisper 转写一段 wav，输出带绝对时间码的 JSON。

被 bili-asr.ps1 调用，也可以单独用：
    python asr_transcribe.py clip.wav --model <模型目录> --lang en --offset 1740
"""
import argparse
import json
import os
import sys
import time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav", help="输入 wav 路径（16k 单声道最佳）")
    ap.add_argument("--model", required=True, help="faster-whisper 模型目录")
    ap.add_argument("--lang", default="auto", help="auto / zh / en / ja ...")
    ap.add_argument("--offset", type=float, default=0.0,
                    help="音频起点在视频中的绝对秒数，用于还原时间码")
    ap.add_argument("--out", default="", help="输出 JSON 路径（留空则打印到 stdout）")
    ap.add_argument("--vad", action="store_true", default=True)
    args = ap.parse_args()

    if not os.path.isfile(args.wav):
        sys.exit(f"找不到音频文件: {args.wav}")
    if not os.path.isdir(args.model):
        sys.exit(f"找不到模型目录: {args.model}")

    from faster_whisper import WhisperModel

    t0 = time.time()
    model = WhisperModel(args.model, device="cpu", compute_type="int8")
    lang = None if args.lang == "auto" else args.lang

    segments, info = model.transcribe(
        args.wav, language=lang, vad_filter=args.vad,
        beam_size=5, condition_on_previous_text=False,
    )

    items = []
    for s in segments:
        items.append({
            "from": round(args.offset + s.start, 2),
            "to": round(args.offset + s.end, 2),
            "text": s.text.strip(),
        })

    payload = {
        "lang": info.language,
        "lang_prob": round(getattr(info, "language_probability", 0.0), 3),
        "audio_seconds": round(info.duration, 2),
        "offset": args.offset,
        "elapsed": round(time.time() - t0, 2),
        "count": len(items),
        "items": items,
    }

    text = json.dumps(payload, ensure_ascii=False, indent=1)
    if args.out:
        with open(args.out, "w", encoding="utf-8") as f:
            f.write(text)
    else:
        print(text)


if __name__ == "__main__":
    main()
