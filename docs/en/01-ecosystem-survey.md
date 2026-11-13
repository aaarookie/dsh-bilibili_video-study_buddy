# 01 · Community Ecosystem Survey: The Bilibili Plugin Map for DSH

> Data scraped on 2026-11-13. The raw index is archived at [_sources/awesome-dsh-plugins.json](_sources/awesome-dsh-plugins.json) (13.5 MB).
> Star / download counts are snapshot values from the index and change over time; download counts reflect real usage better than stars.

---

## 1. Survey Methodology and Counting Scope

Three data sources:

| Source | Purpose | Limitation |
|---|---|---|
| `awesome-dsh-plugin.com/plugins.json` | Full plugin listing (**10,778 entries**), with stars / monthly downloads / version / declared capabilities | The index refreshes once a day at 10:23, so inclusion lags; some GitHub projects are missing |
| GitHub Search API | Discover repositories outside the index (`dsh-bili-*` and 204 other results) | Stars can be gamed and cannot be the sole basis for quality |
| npm registry + downloads API | Verify whether a package is really published, plus version, engines and real monthly downloads | Only covers projects published to npm |

**Three counting scopes — do not mix them up:**

| Scope | Count | Meaning |
|---|---|---|
| Name contains `bili` | **48** | Unambiguous Bilibili plugins |
| Name or description mentions Bilibili / bilibili | **102** | Includes general plugins that "also support Bilibili in passing" |
| All plugins | 10,778 | The entire DSH ecosystem |

> ⚠️ Some sources online put "Bilibili-related" at 500+, but that counts every general plugin whose description happens to contain the words "video/Bilibili".
> This report adopts the stricter scope of **102**.

---

## 2. Grouped by Play Style: Bilibili Plugins Actually Fall into Seven Camps

| Camp | Count | Representative projects | Relation to learning |
|---|---|---|---|
| **Subtitles / transcription** | 26 | `dsh-bili-watch`, `dsh-bili-summary` | ⭐⭐⭐ Core: turns a course into text |
| **Interaction / social** | 21 | `dsh-bili-subagent`, `dsh-bili-eyes` | ⭐ Essentially useless for study (likes/comments/DMs) |
| **Pets / personas** | 20 | `dsh-bili-whale`, `dsh-bili-pond`, `dsh-fish` | ✗ Entertainment-oriented, a product of the "fish farming" culture |
| **Video understanding / looking at frames** | 17 | `dsh-bili-eyes`, `dsh-bili-vision`, `dsh-video-storyboard` | ⭐⭐ Useful for whiteboard/PPT scenes, but depends on a vision model |
| **Auto-scroll / recommendation** | 15 | `dsh-bili-scroll`, `dsh-bili-jar` | ✗ Helps you "discover content", not "learn content" |
| **Study management** | 14 | `dsh-bili-study`, `dsh-video-coursemap`, `dsh-web-studyhub` | ⭐⭐⭐ Core: notes, outlines, review |
| **Live streaming** | 6 | `dsh-bili-live`, `dsh-bili-danmaku-lite` | ✗ Unrelated to online courses |

> A single plugin can hit several camps at once (for example `dsh-bili-eyes` counts as both "looking at frames" and "interaction"), so the seven counts add up to 119, more than the total of 102.

**Key observation**: the camp with the largest download numbers (auto-scrolling, with `dsh-bili-scroll` at 73k monthly downloads) is precisely the one that is **unrelated to learning** —
it "lets the AI scroll Bilibili for you and then write a daily report." Plugins that genuinely serve learning generally see downloads in the thousands down to the hundreds: **niche but precise**.

---

## 3. Real Popularity Ranking (by npm monthly downloads, 2026-11-13)

| Plugin | Stars | Monthly downloads | Positioning | Relevant to learning? |
|---|---:|---:|---|---|
| `dsh-bili-scroll` | 1,381 | **73,647** | Scrolls Bilibili itself, reads subtitles to pick content, writes a daily report @ you | ✗ |
| `dsh-video-storyboard` | 530 | 33,475 | Video → grid contact sheet + timecodes + spoken lines (**underlying capability**) | ⭐⭐ Reused by several plugins |
| `dsh-bili-watch` | 16 | **16,154** | Structured content: metadata/comments/danmaku/subtitles/ASR/frame-extraction OCR | ⭐⭐⭐ |
| `dsh-bili-subagent` | 109 | 9,683 | Dispatches a sub-agent to scroll the site, brings notes and a card wall | ⭐⭐ Comes with item-by-item notes |
| `dsh-bili-pond` | 29 | 6,216 | A fat fish scrolls for you and DMs you | ✗ |
| `dsh-video-understand` | 15 | 5,125 | Low-cost information layer (ASR + scenes + trajectories) → summary Q&A | ⭐⭐ |
| `dsh-bilibili-video-summary` | 2 | 4,037 | yt-dlp download + frame extraction + transcription | ⭐⭐ |
| `dsh-bili-jar` | 11 | 3,620 | A jar in the bottom-right corner that searches videos by interest | ✗ |
| `dsh-bili-eyes` | 6 | 3,742 | Storyboard images + spoken lines + top comments + site browsing + interaction | ⭐⭐ |
| `dsh-bili-study` | 0 | 404 | **Bilibili study desk**: subject → chapter → topic, notes, knowledge graph | ⭐⭐⭐ |
| `dsh-video-coursemap` | 21 | — | Auto-detects the foreground video → subject classification → Word knowledge map | ⭐⭐⭐ |
| `dsh-web-studyhub` | 186 | 1,946 | Materials/recordings → flashcards + quizzes + FSRS-6 review | ⭐⭐⭐ |

> Note: **stars and download counts diverge sharply**. `dsh-bili-watch` has only 16 stars yet 16k monthly downloads,
> while `dsh-bili-scroll` has 1,381 stars. The former is a "tool", the latter a "toy + social currency". When choosing, look at downloads and README quality, not just stars.

---

## 4. The Upstream Dependency Chain: the Whole Map Is Really the Branches of Three Trees

This is the single most important thing to understand about this ecosystem — **most plugins are not written from scratch; they are wrappers around the same few foundations**.

```
adoresever/bilibili-mcp (Python MCP: search / subtitles / comments / posting comments)
        │
        ├── c1overzz/dsh-bili-scroll ──┬── Yuuyuko-uu/dsh-bili-subagent
        │                              ├── 13520rygvv/dsh-bili-video (+ storyboard)
        │                              ├── QiuYeDx/dsh-bili-eyes (+ storyboard)
        │                              └── Alterssss/dsh-bili-whale / dsh-bili-pond / dsh-fish …
        │
SAOS-3624/dsh-video-storyboard (grid storyboard, timecodes, audio envelope)
        │
        ├── QiuYeDx/dsh-bili-eyes
        ├── 13520rygvv/dsh-bili-video
        └── icyaaaww/dsh-bili-vision (bundles its own Python engine)

Independent implementations (not on either chain above):
  Sacredbluedragon/dsh-bili-watch (in-house CLI + local ASR/OCR, MIT)
  YZz-S/dsh-bili-summary (pure Node + sharp)
  ilps2/dsh-video-understand (in-house Python engine AVIS)
  linner1224/dsh-video-coursemap (pure Node, no video stream)
  ijerrywong/bili-study-plugin (pure JS, does not download video)
```

**Practical implications:**
1. Installing `dsh-bili-eyes` means indirectly installing the whole `bilibili-mcp` + `storyboard` stack; adding `dsh-bili-subagent` on top creates feature overlap.
2. Bugs from upstream authors propagate to every downstream package; conversely, even when upstream fixes something, you still have to wait for downstream updates.
3. Choosing an "independent implementation" usually means less legacy baggage, but it also means one author carries all the maintenance.

---

## 5. Study Plugin Deep Dive (directly related to "watching an online course")

### 5.1 `dsh-bili-study` — Bilibili study desk (npm, v1.0.0)
- **Positioning**: study **management**, not video understanding. It does not download videos, does not log in, does not touch the video stream; playback uses Bilibili's official embedded player.
- **Capabilities**: UP creator homepage / favorites / single link → a "Subject → Chapter → Topic" outline; Markdown + KaTeX notes; concept lookup; knowledge graph; AI prerequisite linking (prerequisite relations between topics); smart classification.
- **Data**: all local, in `~/.dsh/bili-study/state.json`.
- **Weakness**: the AI cannot see the video content, so it can only classify and explain concepts based on **titles**. It will not tell you "what was covered at minute 12".
- Repository: <https://github.com/ijerrywong/bili-study-plugin>

### 5.2 `dsh-video-coursemap` — Video course knowledge map 2.0
- **Positioning**: fully automatic. Every 15 s it reads the **Windows foreground window title** → decides whether it is a course video → automatically scrapes Bilibili subtitles/danmaku/top comments → distills knowledge points + a Mermaid mind map → outputs a Word "study handbook".
- **Highlight**: **zero runtime dependencies** (pure Node), auto-folders by subject, existing subjects get appended updates.
- **Hard flaw**: the README itself admits that "most Bilibili videos have no machine subtitles"; with no subtitles it can only degrade to a "title-only summary" — which is worth little. Word output requires Python.
- Repository: <https://github.com/linner1224/dsh-video-coursemap>

### 5.3 `dsh-web-studyhub` — Study workbench (v4.5.1)
- **Positioning**: **review**, not watching video. Import PDF/DOCX/PPTX/Markdown and classroom recordings → flashcards with source citations, quizzes, open questions → **FSRS-6 spaced repetition**.
- **Value**: it is **complementary** to Bilibili plugins — the Bilibili plugin turns a course into notes, this one turns notes into retention.
- npm: `@ericwang1358/dsh-daily-flashcard`

### 5.4 Other study-related plugins worth knowing
| Plugin | Stars | In one sentence |
|---|---:|---|
| `Study-Mate` | 1,437 | AI study partner: makes plans, explains knowledge, builds projects. **Does not touch Bilibili**, pure study methodology |
| `dsh-knowledge-studio` (EduWork) | 351 | Builds reports/PPT/mind maps/quizzes/flashcards from workspace materials; needs Python 3.12 + Chromium |
| `deep-read-summarize` | 45 | Books/papers/**videos**/web pages → structured Obsidian notes, MapReduce parallel close reading |
| `dsh-bili-subagent` | 109 | Though positioned as site scrolling, its report carries **notes and a card wall for every video**, usable for "batch preview" |

---

## 6. Comparison with Non-DSH Ecosystems (in case you want to know "how others do it")

| Project | Form | Features | Why it suits you less than a DSH plugin |
|---|---|---|---|
| `bilibili-video-mcp` (yzfly) | Python MCP server | you-get download + danmaku subtitles + ASR + SiliconFlow | You have to configure Claude Desktop/client yourself; no DSH tool mounting or settings page |
| `@xzxzzx/bilibili-mcp` | npm MCP | Full-featured (search/subtitles/comments/login) | Same as above, and it must be configured repeatedly in every client |
| `BiliNote` (multiple implementations) | Chrome extension / CLI / Go | Subtitle summaries, ask as you watch, Notion sync, screenshots into notes | Tied to the browser; notes live inside the extension, DSH cannot read them |
| `Bilibili Subtitle to AI` | Chrome extension | Sends subtitles/audio to ChatGPT or AI Studio | Data leaves the local machine, and it only works in the browser |
| `BibiGPT` skill | Agent Skill | YouTube/Bilibili/podcast summaries, chapters, note export | Depends on its cloud service and account |
| `OpenBiliClaw` | Cross-platform agent (3,750★) | Content discovery, supports a DSH plugin form | Positioned as "discovering content", not "learning content" |

**Conclusion**: the irreplaceable value of DSH plugins is that **tools go straight into the conversation context** — the model can decide on its own to "read the subtitles first, then skim the comments, then pull three frames to look at the whiteboard", and the data stays on the local machine.

---

## 7. Ecosystem Observations and Risk Notes

**Maturity**: this ecosystem has clearly moved past the "experimental phase".
- It has a unified marketplace index and a daily build pipeline;
- plugins commonly ship a settings page, QR-code login, dependency self-check, cache management and error fallback;
- documentation quality exceeds that of typical open-source projects (`dsh-bili-watch`'s README runs to 400 lines and even spells out which cache subdirectories are safe to delete).

**But do not be blindly optimistic either:**

| Risk | Concrete manifestation | Suggestion |
|---|---|---|
| **Homogeneity** | 20 "scroll Bilibili" plugins with heavily overlapping features | Install only one, do not stack them |
| **Personal projects** | Most are "I use it myself and put it up casually", with no roadmap and no update commitment | Prefer ones published to npm, with a version number and recent commits |
| **In-process Host code** | Plugin code runs inside the DSH main process, with permissions equal to yours | Only install what you can trace the origin of; if write operations are off by default, leave them off |
| **Credential risk** | SESSDATA / bili_jct are equivalent to the account and password | Use a throwaway account; never commit or share credential files |
| **Unofficial APIs** | Depends on unpublished Bilibili endpoints that can break at any time (-412 risk control) | Accept that "one day it may just stop working" |
| **Compliance** | Scraping subtitles/comments is for personal study use | Do not use commercially, do not crawl in bulk, do not send high-frequency requests |

**Licenses**: mainstream projects are all **MIT**, so they are safe to read and modify; a few plugins merge several upstreams (such as `dsh-bili-video`),
in which case mind the copyright statements for each project in their `NOTICE`.
