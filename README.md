# dsh-bilibili_video-study_buddy

[![npm](https://img.shields.io/npm/v/dsh-bilibili_video-study_buddy.svg)](https://www.npmjs.com/package/dsh-bilibili_video-study_buddy) [![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)


> Let the model look at **the right frame at the right timestamp**, then turn a lecture into checkable notes.

A [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) plugin, plus the methodology and real note artifacts behind it.

**Repo**: <https://github.com/aaarookie/dsh-bilibili_video-study_buddy> ｜ **Plugin**: `plugin/` (npm: `dsh-bilibili_video-study_buddy`) ｜ **中文说明**: [README.zh.md](README.zh.md)

---

## What this is

| Path | Contents |
|---|---|
| [`plugin/`](plugin/) | The DSH bundle. Four tools: `study_frame` / `study_scan` / `study_subs` / `study_asr` |
| [`docs/`](docs/) | Methodology: ecosystem survey, plugin comparison, workflow, environment, verification log |
| [`examples/`](examples/) | Real artifacts: Karpathy GPT lecture notes (md + docx), ASR transcripts, frame grids |
| `scripts/` | Standalone PowerShell tools (optional, Windows) |

## Three counter-intuitive findings

### 1. Do not feed the whole video — feed the right frames

A 30-minute lecture carries its signal in roughly 20 frames. Grab one frame at a timestamp,
crop away the browser chrome, and let the model read it. That is one to two orders of magnitude
cheaper than "video understanding".

### 2. A grid is for locating, not reading

| Approach | Size | Est. tokens |
|---|---|---|
| 6 full frames at 1080p | — | ~5,850 |
| 6-cell grid (400 px/cell) | 1224×450 | **~585 (−90%)** |

At 400 px per cell you cannot read code. The grid only answers "which stretch is worth a close look".

### 3. Bilibili AI subtitles lie — verify before trusting

On a lecture about GPT, the subtitle endpoint returned:

```
[0.0s] 核能一种很硬核的能源        (nuclear energy is a hardcore energy source)
[2.4s] 比如说一克浓缩铀             (say, one gram of enriched uranium)
```

and on another attempt, English song lyrics. Both had nothing to do with the video.
`study_subs` therefore scores three independent signals — coverage, title-term hits, speech rate —
and refuses to emit the body when the verdict is FAIL.

## Install

```bash
dsh plugin --profile web add dsh-bilibili_video-study_buddy
```

Or in DSH: **Settings → Plugins → Add plugin** and enter the package name. Restart DSH once.

Requirements: Node ≥ 20, `ffmpeg` (required); a Bilibili session (optional, unlocks 1080p and AI subtitles);
`faster-whisper` (only for `study_asr`).

## Usage

```
You: explain the RL Training part at P8 of BV1mqrTBvEaf
```

The model will, on its own:

1. `study_subs` to probe subtitles → verdict: contaminated (this video really is)
2. `study_scan -from 14:00 -to 18:00` → a grid that locates the slide at 16:20
3. `study_frame -at 16:20 -crop "0,0,0,190"` → one high-res frame
4. `study_asr -at 16:20` → the lecturer's own words with surrounding context
5. read the frame against the transcript → explain, then write timestamped notes → Word

## Measured numbers

| Item | Result |
|---|---|
| Cropped 1080p frame | 1234×800, ~975 tokens (−45% vs full frame) |
| 6-cell grid | 1224×450, ~585 tokens (−93% vs reading each) |
| 90-second ASR window | 8.8 s (faster-whisper small, CPU) |
| Full 42-minute transcript | 229 s |
| Frame cache hit | < 1 s (first fetch 13 s) |
| Understanding one 30-minute lecture | **≈ ¥0.03** (DeepSeek off-peak) |

Cost model: [`examples/karpathy-gpt/p8-cache/cost-analysis.md`](examples/karpathy-gpt/p8-cache/cost-analysis.md) (Chinese).

## Limitations (all from real failures)

- **A timestamp belongs to one part**, not to the whole video. Multi-part courses need the right `page`.
- **Anonymous caps at 640×480**; 1080p requires a Bilibili session.
- **ASR systematically mishears code terms** (`free(p)` → "4AP", 栈上 → 站上). Code always comes from the frame.
- **The grid cannot be used to read code** — locating only.
- **Read-only**: never likes, comments, or coins.

## Docs

English: [`docs/en/`](docs/en/) ｜ 中文: [`docs/zh/`](docs/zh/)

| # | Topic | EN | 中文 |
|---|---|---|---|
| 01 | Survey of 102 Bilibili-related DSH plugins | [en](docs/en/01-ecosystem-survey.md) | [zh](docs/zh/01-ecosystem-survey.md) |
| 02 | Nine candidates compared, three technical routes | [en](docs/en/02-plugin-comparison.md) | [zh](docs/zh/02-plugin-comparison.md) |
| 03 | The five-step study loop and prompt templates | [en](docs/en/03-study-workflow.md) | [zh](docs/zh/03-study-workflow.md) |
| 04 | Install, login, and error lookup | [en](docs/en/04-install-and-pitfalls.md) | [zh](docs/zh/04-install-and-pitfalls.md) |
| 05 | Every measurement, including what was *not* tested | [en](docs/en/05-verification-log.md) | [zh](docs/zh/05-verification-log.md) |
| 06 | The timestamp → frame → notes pipeline | [en](docs/en/06-timestamp-code-and-notes.md) | [zh](docs/zh/06-timestamp-code-and-notes.md) |
| 07 | What was installed and how to undo it | [en](docs/en/07-environment-setup.md) | [zh](docs/zh/07-environment-setup.md) |
| 08 | Plugin install and integration record | [en](docs/en/08-install-and-integration.md) | [zh](docs/zh/08-install-and-integration.md) |

## License

MIT
