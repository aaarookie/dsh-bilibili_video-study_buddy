#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""faster-whisper 转写 helper，被 study_asr 调用。"""
import argparse
import json
import os
import sys
import time


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("wav")
    ap.add_argument("--model", required=True)
    ap.add_argument("--lang", default="auto")
    ap.add_argument("--offset", type=float, default=0.0)
    ap.add_argument("--out", default="")
    args = ap.parse_args()

    if not os.path.isfile(args.wav):
        sys.exit(f"找不到音频: {args.wav}")
    if not os.path.isdir(args.model):
        sys.exit(f"找不到模型: {args.model}")

    from faster_whisper import WhisperModel

    t0 = time.time()
    model = WhisperModel(args.model, device="cpu", compute_type="int8")
    lang = None if args.lang == "auto" else args.lang
    segments, info = model.transcribe(
        args.wav, language=lang, vad_filter=True,
        beam_size=5, condition_on_previous_text=False,
    )
    items = [{
        "from": round(args.offset + s.start, 2),
        "to": round(args.offset + s.end, 2),
        "text": s.text.strip(),
    } for s in segments]

    payload = {
        "lang": info.language,
        "audio_seconds": round(info.duration, 2),
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
