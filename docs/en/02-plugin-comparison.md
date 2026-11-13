# 02 · In-Depth Comparison and Selection of Core Plugins

> Only the 9 plugins genuinely related to "watching/studying courses" are covered. The auto-scroll, pet-fish and live-streaming camps were already excluded in [01](01-ecosystem-survey.md).
> All capability descriptions are taken from each project's README (originals archived under [_sources/](_sources/)); features I have not empirically verified are marked as such.

---

## 1. First Understand the Three Technical Routes

There are only three engineering routes to "letting DeepSeek watch a video"; choosing a plugin is essentially choosing which route to take:

| Route | Principle | Cost | Information loss | Suited to |
|---|---|---|---|---|
| **A. Subtitle text** | Scrape Bilibili official/AI subtitles → plain text to the model | Lowest (tens of thousands of characters ≈ a few thousand tokens) | Loses the visuals, the tone, the whiteboard | Talking-head courses (the majority of online courses) |
| **B. Speech transcription** | Download the audio track → local faster-whisper / cloud ASR → text | Medium (local burns CPU/GPU, cloud bills by the minute) | Same as above + misrecognized characters | Older courses with no subtitles, screen recordings |
| **C. Vision/OCR** | Extract frames → grid contact sheet to a vision model, or OCR into text | Highest (image tokens are 10~100× text) | Depends on the sampling rate; brief visuals get missed | PPT, whiteboard, code demos |

> ⚠️ **Correction from empirical testing on 2026-11-13**: this section originally followed `dsh-video-understand`'s README and asserted that
> "DeepSeek is text-only, so seeing the visuals can only rely on OCR". **Empirical testing overturned that premise**:
> under the current DSH configuration the model can directly consume image attachments (it can read the code and color annotations in handwritten whiteboards).
> So both outlets of route C work, and **"looking at the image" is clearly better than "OCR"** — measured OCR read
> `a=a+10` as `a=a+lo` and `a+=5` as `a=ats`, while looking at the image read all of them correctly.
>
> The conclusion becomes: **A (subtitles) as the base, C (looking at images) to fill in the key frames; OCR only as a fallback when there is no vision capability.**
> For details see [05](05-verification-log.md) section 4 and [06](06-timestamp-code-and-notes.md).

**Realistic conclusion for this machine (the environment was already set up in the second round)**: both A and C are viable.
`ffmpeg` is on PATH, and `bili-frame.ps1` has been empirically tested; installing the plugin is enough to complete subtitles and search.

---

## 2. Master Comparison of the Nine Contenders

| Plugin | Version | Monthly downloads | Route | Node | Python | ffmpeg | Bilibili login | Tools given to the model | Suited to |
|---|---|---:|---|---|---|---|---|---|---|
| **`dsh-bili-watch`** | 0.4.10 | 16,154 | A+B+C(OCR) | ≥22 | Optional | Optional | Optional (subtitles) | `bili_watch` + `/bili` command | ⭐ **Primary** |
| `dsh-bili-eyes` | 0.8.3 | 3,742 | A+B+C(vision) | ≥20 | Optional | One-click download on the settings page | Optional | multiple `bili_*` | Storyboard + social |
| `dsh-bili-video` | 0.9.0 | — | A+B+C(vision) | — | **Required** | **Required** | Required (QR code) | 16 | Full-featured tinkering |
| `dsh-bili-vision` | 0.2.0 | — | A+B+C(vision) | ≥18 | **Required** | **Required** | Optional | `bili_vision`, `bili_summary` | Multimodal close reading |
| `dsh-video-understand` | 0.5.2 | 5,125 | A+B (information layer) | ≥18 | Self-built venv | **Required** | Not needed | `video_understand` | Low-cost Q&A |
| `dsh-video-coursemap` | 2.0.0 | — | A (subtitles only) | — | Only needed for Word | **Not needed** | Not needed | `course_map_*` | Passive recording |
| `dsh-bili-study` | 1.0.0 | 404 | None (management only) | ≥22.19 | Not needed | Not needed | Not needed | `bili_study_*` | ⭐ **Study management** |
| `dsh-bili-summary` | — | — | A | ≥20.9 | Not needed | Not needed | Optional | `bili_summary` | Minimal summary |
| `dsh-bili-subagent` | 0.9.9 | 9,683 | A | ≥22 | **Required** | Not needed | **Required** | 13 | Batch preview |

---

## 3. One by One, Pitfalls Included

### 3.1 `dsh-bili-watch` — The best option under this machine's conditions ★★★★★

**What it does**: turns a Bilibili link into structured content the model can consume directly. 14 CLI commands covering the whole chain from metadata to frame OCR.

```
view      metadata + description + top comments (no download, works anonymously)
sub       official AI subtitles, exportable as srt/json/md/txt
comments  comment section (including nested replies)
danmaku   danmaku hotspots (peak statistics per time bucket)
asr       local faster-whisper transcription + confidence verdict
frames    frame extraction (--scene samples at scene changes, more accurate and cheaper)
ocr       extract frames and recognize on-screen text
text      four-level fallback chain: subtitles → transcription → frame OCR → image reading
sheet     nine-grid contact sheet (--cues appends spoken lines under each cell)
peek      metadata + top comments + 5 frames (via the official frame endpoint, no video download)
search    in-site search (filterable by number of days, sortable by view count)
hot       trending list
login     QR-code login
clean     clear cache
```

**Why it is recommended**:
1. **Core capabilities have zero dependencies** — metadata/comments/danmaku/search/subtitles all go over plain HTTP, with no need for ffmpeg or Python. That fits this machine's current state exactly.
2. **Output designed for AI**: it carries `[mm:ss]` timecodes, and text longer than 800 characters is automatically written to disk with only a summary returned, so the model reads it in segments with `read` — **the context does not blow up**.
3. **Anti-hallucination mechanisms** (extremely important for learning): ASR output comes with a "trustworthy / suspected hallucination" verdict; an abnormal subtitle speech rate (<2 or >8.5 characters/second) is flagged as suspect; `--verify` can extract 5 frames and cross-check them via OCR.
4. **MIT + 400 lines of documentation**, down to "which cache subdirectories can be deleted" — the most conscientious one I have seen.
5. It has a Web panel: dependency status, QR-code login, cache management, 18 runtime parameters.

**Pitfalls**:
- AI subtitles require login (`SESSDATA`). Anonymous access only yields a subset.
- Read-only: no likes, no comments (which is actually the right call for study scenarios).
- If the `bili_watch` tool name collides with another plugin, the later registration overrides the earlier one.
- Requires Node ≥ 22 (v24 on this machine ✅).

**Install**: `dsh plugin --profile web add dsh-bili-watch`

---

### 3.2 `dsh-bili-study` — Study management, not video understanding ★★★★☆

**What it does**: adds a "Bilibili study desk" to the sidebar. It collects UP creator homepages / favorites / single videos into "Subject → Chapter → Topic",
plays them in Bilibili's official embedded player, and on the right you write Markdown + KaTeX notes while the AI helps you look up concepts, generate a knowledge graph and fill in prerequisite knowledge.

**Pros**:
- **Pure JS, zero external dependencies, does not download videos, does not log in, does not touch the video stream** — it can be installed directly on this machine and works right away.
- All data stays local, in `~/.dsh/bili-study/state.json`.
- Notes support formulas (`$...$` / `$$...$$`) and can be exported. Crucial for STEM online courses.
- "AI prerequisite linking" can generate prerequisite relations between topics, which is good for building a learning path.

**Clear weaknesses**:
- **The AI cannot see the video content**. It only knows the titles. Ask "what does this lecture cover" and it cannot answer.
- Its `bili_study_fetch` only fetches titles/metadata, not subtitles.

**So it is not a "watch video" plugin, it is a "course management + notes" plugin**. It complements `dsh-bili-watch` rather than replacing it.

**Install**: `dsh plugin --profile web add dsh-bili-study`

---

### 3.3 `dsh-bili-eyes` — The most "human-like" video watching experience ★★★☆☆

**What it does**: storyboard images (6~16 cells each, the cell number burned into the image, with timecodes and spoken lines) + Bilibili context (AI summary/top comments/high-frequency danmaku terms/densest time window) + site browsing + interaction.

**Highlights**:
- For long videos it does not force everything into a single image; it gives 2~4 images at "about one minute per cell";
- ffmpeg can be **downloaded with one click on the settings page** (very friendly to an environment like this one without ffmpeg);
- Write operations are off by default and graded by "whom it targets" (own people / the host's comment section / outsiders) — a very restrained permission design;
- Source of spoken lines: Bilibili AI subtitles → speech recognition (SiliconFlow or a local service).

**Weaknesses**:
- Storyboard images require the **model to be able to see images**. DeepSeek by default cannot → you only get image paths + text, and the images are extracted in vain.
- Its functional focus is actually "browsing Bilibili + interaction + group-chat scenarios"; study use is incidental.
- Requires a Bilibili account to get AI subtitles and 1080P.

**Suited to**: you have a multimodal model configured as well, or you want it to keep an eye on comment sections / find related videos for you along the way.

**Install**: `dsh plugin --profile web add dsh-bili-eyes`

---

### 3.4 `dsh-bili-video` — Full-Featured Frankenstein ★★☆☆☆

**What it is**: a merged and modified version of two people's work — `dsh-bili-subagent` (reads the mouth) + `dsh-video-storyboard` (sees with eyes).
The author's own words: "This is a little tool I use myself; I put it up so friends can copy my homework. It is not a product."

**Capabilities**: 11 `bili_*` tools + 5 `video_*` tools (`video_probe` / `video_storyboard` / `video_zoom` / `video_locate` / `video_watch`).

**Why only two stars (for this machine)**:
- **Python 3.10+ is a hard dependency** (required for the Bilibili half), and this machine does not have it;
- **ffmpeg is a hard dependency** (required for the video-watching half);
- it requires QR-code login;
- the author explicitly makes no maintenance commitment.

**But it has two unique advantages**:
- `video_locate`: give it a sentence and it finds its approximate timecode in the video — **extremely useful for "I remember the teacher covered a point but I forgot where"**;
- `video_zoom`: rescans high-definition frames only within a given time window — for close reading of whiteboards.

If you are willing to tinker with the environment, its tool design is the best fit in this batch for the learning action of "repeatedly looking back".

---

### 3.5 `dsh-bili-vision` — Designed for "multimodal close reading" ★★★☆☆

**What it does**: `inspect` assembles evidence locally (images with real timestamps + official subtitles/local transcription + OCR) and hands it to the **current** vision model;
`run` analyzes with an independent vision model (for when the main model cannot see images).

**The most carefully designed one of the batch**:
- 2 fps grayscale frames for change detection; candidate frames cover the whole video by time, defaulting to at most 12 frames in a 2×2 grid;
- **deletes only exactly identical frames** (compares full RGB, not a lossy similarity threshold);
- **OCR results genuinely enter the evidence**, they are not just decoration;
- budget control: default text budget 12000 tokens, the number of omissions is annotated, and a time range can be specified for follow-up reading;
- 26 Python tests + 7 Node tests.

**Weaknesses**: it needs Python 3.10+, ffmpeg and ffprobe all at once, and it is **not published to npm**, so it can only be installed via `git+`.
`inspect` also requires the current conversation model to support images — DeepSeek does not, so you have to rely on `run` with an independent vision model.

---

### 3.6 `dsh-video-understand` — The most economical understanding approach ★★★☆☆

**Distinctive idea**: it does not do vision, it does an "**information layer**" — ASR transcription + scene structure + moving-object trajectories + YOLO semantics,
compressed into about 1k tokens before being fed to the LLM. It claims token compression of 99.95%+.

**Pros**:
- On the first call it automatically creates an isolated venv (prefers uv, falls back to the pip Tsinghua mirror), **without polluting the system Python**;
- ships `doctor --fix` for one-shot self-check and repair;
- has a cost budget gate `budgetCny` and degrades automatically when over budget;
- supports a `questions` array to ask several questions in one call.

**Weaknesses**:
- still needs **ffmpeg**;
- defaults to the Xiaomi MiMo API (`LLM_API_KEY`), not native DeepSeek;
- the semantic layer (torch/YOLO) is about 2 GB, and unless you need information like "who did what where", you will not use it.

**Suited to**: you have a batch of videos to question-answer in bulk ("which algorithms does this course cover") and you care about cost.

---

### 3.7 `dsh-video-coursemap` — Good idea, but strangled by "no subtitles" ★★☆☆☆

**What it does**: every 15 seconds it reads the Windows foreground window title → decides that you are watching a course → automatically scrapes subtitles/danmaku/top comments → distills 8~20 knowledge points + a Mermaid mind map → appends them to the Word "study handbook" for the corresponding subject.

**Pros**: fully passive, zero operation, zero runtime dependencies (pure Node, no ffmpeg, no video download), auto-filed by subject.

**Fatal weaknesses** (which the README itself admits):
- "most Bilibili videos have no machine subtitles (subtitle is empty); subtitles are scraped on a best-effort basis and downgrade silently on failure" → after the downgrade only the title is left, which is as good as no summary;
- the anonymous comments endpoint caps at 3;
- the AI summary endpoint returns -403 and requires login, so it is unusable;
- the foreground window must be a browser/video client; background playback does not trigger it.

**Conclusion**: the thinking is right (automating the study record), but **the subtitle coverage it depends on is not enough**; installing it now will most likely produce a pile of empty "title-only" handbooks. Wait until it supports local ASR.

---

### 3.8 `dsh-bili-summary` — Minimal pure Node ★★★☆☆

**What it does**: one tool, `bili_summary`; a single call brings back metadata + subtitle timeline + optional images (sharp cuts frames from the player snapshot endpoint).

**Pros**:
- **Pure Node, no shell calls, no encoding pitfalls**, specifically handling illegal filename characters on Windows;
- complete error-code mapping (-404/-412/-352/62002), exponential backoff retries, automatic retry on risk control;
- over-long subtitles are automatically written to disk + inline excerpt;
- `withImages` defaults to false, so it does not spend image tokens needlessly.

**Weaknesses**:
- subtitles go through the legacy `view`/`player/v2` endpoints, and **WBI signing is not implemented**, so it breaks the moment Bilibili tightens things up (the README says so explicitly);
- not published to npm, only installable via `github:`;
- images depend on sharp, and node-gyp may need to compile on Windows.

**Suited to**: you only want the minimal loop of "link in, notes out" without installing a pile of things.

---

### 3.9 `dsh-bili-subagent` — For batch preview ★★☆☆☆

**What it does**: dispatches a sub-agent to scroll Bilibili, read subtitles, skim comments, pick out what is worth watching, and hand back an internal report with notes and a card wall.

**Why it is included**: its report carries **notes for every video**, so it can serve as a tool for "understanding in bulk which good courses exist in a field".
Its "two hard thresholds" (minimum view count, at least a few days since publication) are genuinely useful when filtering courses.

**Weaknesses**:
- Python 3.10+ or uv is **required** (to create a venv and install `bilibili-api-python`);
- **QR-code login is mandatory**;
- it is positioned as "site scrolling + social delivery"; learning is a by-product;
- very many settings (delivery method, comment quota, auto-scroll time windows), most of which are useless for study scenarios.

---

## 4. This Machine's Fit Matrix (After the Second Round of Configuration)

The environment is complete: ffmpeg ✅, Python 3.12 ✅ (`E:\tools\pydeps\bili-env`), uv ✅, yt-dlp ✅, Node 24 ✅, DSH 0.2.2-rc.1 ✅.

| Plugin | Can it be installed now? | How far it can be used |
|---|---|---|
| `dsh-bili-watch` | ✅ | Full functionality. The only gap is the Bilibili login state (affects AI subtitles and high quality) |
| `dsh-bili-study` | ✅ | 100% |
| `dsh-bili-summary` | ✅ | Full functionality (sharp needs build permission, otherwise it degrades to cover image only) |
| `dsh-bili-eyes` | ✅ | Full functionality; **the model can see images, so storyboard images are no longer wasted** |
| `dsh-bili-video` | ✅ | Full functionality (both Python and ffmpeg are satisfied), requires QR-code login |
| `dsh-bili-vision` | ✅ | Full functionality; `inspect` depends on the current model seeing images — **empirically verified it can** |
| `dsh-video-understand` | ✅ | Requires your own MiMo/DeepSeek key; the 2 GB semantic layer is optional |
| `dsh-video-coursemap` | ⚠️ | Still not recommended: blocked by "most videos have no subtitles", which has nothing to do with dependencies |
| `dsh-bili-subagent` | ✅ | Full functionality, but requires QR-code login |

> Capabilities that need a Bilibili login state (AI subtitles, 1080P, favorites scraping) still require a QR-code scan or supplying `SESSDATA`;
> environment configuration cannot substitute for that part. What works anonymously: metadata, search, comments, danmaku, 480p frame extraction.

---

## 5. Final Selection

### Recommended Combination

```
Required: dsh-bili-watch   ← turn a course into time-stamped text (the information entry point for learning)
Required: dsh-bili-study   ← manage courses, take notes, look up concepts (the organization layer for learning)
Optional: dsh-web-studyhub ← turn notes into flashcards, review with FSRS-6 (the memory layer for learning)
```

The three have completely non-overlapping responsibilities:

```
dsh-bili-watch   →  produce: subtitle text / summary / exam points
dsh-bili-study   →  carry: outline, notes, progress, knowledge graph
dsh-web-studyhub →  consolidate: flashcards, quizzes, spaced repetition
```

### Decision Tree

```
What do you mainly want to solve?
├─ "I cannot remember a course after watching it / I cannot organize it" → dsh-bili-study + dsh-web-studyhub
├─ "I want a transcript and summary of the course"                       → dsh-bili-watch (+ add ffmpeg for whiteboard OCR)
├─ "I want the AI to do close reading of a few lectures with me"         → dsh-bili-watch for the text + follow-up questions in the conversation
├─ "I want to automatically record which courses I watched"              → not recommended for now (coursemap is blocked by subtitle coverage)
├─ "I want to discover good courses in bulk"                             → dsh-bili-watch's search + hot is enough; automate only if you really need to
└─ "I want the AI to actually understand the whiteboard visuals"         → you need a multimodal model first; then add dsh-bili-vision or dsh-bili-eyes
```

### Explicitly Not Recommended (for your current needs)

| Plugin | Reason not to recommend it |
|---|---|
| `dsh-bili-scroll` / `dsh-bili-whale` / `dsh-bili-pond` / `dsh-fish` | Entertainment-oriented "fish farming / site scrolling"; helps you discover content, not learn it; it will also post comments on your account |
| `dsh-bili-jar` / `dsh-bili-merlin` | Same as above, interest-recommendation oriented |
| `dsh-bili-live` / `dsh-bili-danmaku-lite` | Live-streaming scenarios, unrelated to online courses |
| `dsh-bili-humanism` | Persona-training oriented, rather experimental |
