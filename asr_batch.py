#!/usr/bin/env python
# -*- coding: utf-8 -*-
"""
asr_batch.py —— 一次加载模型，批量转写多个音频片段。

被 bili-find.ps1 用于"抽样扫描整片、定位关键词"。

输入 JSON:
{
  "model": "<模型目录>",
  "lang": "auto",            // auto / zh / en / ja
  "items": [
     {"wav": "...", "offset": 300.0, "label": "05:00"},
     ...
  ]
}

输出 JSON:
{
  "lang": "en", "elapsed": 12.3,
  "items": [ {"video_time": 305.2, "label": "05:00", "text": "..."} ]
}
"""
import json
import sys
import time


def main():
    if len(sys.argv) < 3:
        sys.exit("用法: asr_batch.py jobs.json out.json")

    with open(sys.argv[1], "r", encoding="utf-8") as f:
        jobs = json.load(f)

    from faster_whisper import WhisperModel

    t0 = time.time()
    model = WhisperModel(jobs["model"], device="cpu", compute_type="int8")
    lang = jobs.get("lang", "auto")
    lang = None if lang == "auto" else lang

    out_items = []
    detected = None

    for job in jobs["items"]:
        try:
            segments, info = model.transcribe(
                job["wav"], language=lang, vad_filter=True,
                beam_size=1, condition_on_previous_text=False,
            )
            if detected is None:
                detected = info.language
            for s in segments:
                out_items.append({
                    "video_time": round(job["offset"] + s.start, 2),
                    "label": job["label"],
                    "text": s.text.strip(),
                })
        except Exception as e:  # 单个片段失败不影响整体
            out_items.append({
                "video_time": job["offset"],
                "label": job["label"],
                "text": f"[转写失败: {e}]",
            })

    payload = {
        "lang": detected,
        "elapsed": round(time.time() - t0, 2),
        "count": len(out_items),
        "items": out_items,
    }
    with open(sys.argv[2], "w", encoding="utf-8") as f:
        json.dump(payload, f, ensure_ascii=False, indent=1)
    print(f"ok {len(out_items)} lines in {payload['elapsed']}s")


if __name__ == "__main__":
    main()
