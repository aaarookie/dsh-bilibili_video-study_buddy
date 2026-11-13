# 03 · Practical Workflow for Online Course Learning

> Prerequisite: `dsh-bili-watch` and `dsh-bili-study` are already installed following [04](04-install-and-pitfalls.md).
> Every prompt in this document can be copied straight into the DSH chat box; `{}` marks the part you need to replace.

---

## 0. Set the Right Expectations First

**AI does not watch the course for you. It does three things on your behalf:**

| What it is good at | What it is not good at |
|---|---|
| Compressing 60 minutes of talking into 10 key points | Judging which point is **important to you** (it does not know your background) |
| Turning scattered timestamps into a structure | Building intuition for you (math derivations, a feel for algorithms) |
| Answering "what did that term just mean" at any time | Spotting that the teacher got it **wrong** (it tends to go along) |
| Generating questions, grading, tracking mistakes | Doing the exercises for you |

So the right posture is: **you watch and think; it records, retrieves, probes and quizzes.** Do not dump the course on it and go do something else.

---

## 1. The Five-Step Loop

```
① Locate    ── search for / pin down the course, confirm this section is worth watching
② Extract   ── get the subtitles or the transcript in hand (with time codes!)
③ Segment   ── cut into 10~15 minute chunks, one knowledge-point block per chunk
④ Write     ── generate notes with time codes, and save them into the study hub
⑤ Self-test ── generate questions → answer wrong → jump back to the time code and rewatch → log the mistake
```

Step ③ is the crux of the whole flow. **Do not ask AI to summarize the entire lesson in one pass** — it will flatten the details into correct-sounding filler.
Work segment by segment, keep "verbatim key points + time codes" for each one, and merge them only at the end.

---

## 2. Scenario A: Courses With Subtitles (most common, least effort)

### A1. Get the Subtitles

Just say this in DSH:

```
Use bili_watch to export the subtitles of {BV number or link} in md format, with time codes, and save them to the current directory.
```

The model calls the `sub` command of `bili_watch`, producing output like:

```markdown
[00:00] Today we talk about process scheduling
[00:08] First, a quick recap of process states
[01:23] The core problem the scheduler has to solve is...
```

> 💡 `sub` needs a Bilibili login state. Without it you get "no subtitle track" — in that case go to Scenario B.
> 💡 For multi-part videos, remember to say "part 3"; in the command that is `--p 3`.

### A2. Segment-by-Segment Deep Dive (core prompt)

```
Below are the subtitles of one section of a course, with [mm:ss] time codes.
Split them into natural segments by content (8~15 minutes each; do not cut by a fixed character count).
For each segment output:

### Segment N｜{one-sentence summary}｜[{start time}-{end time}]
- **What it covers**: 2~3 sentences in plain language; do not copy the original text
- **Key conclusions**: 1~3 items, the kind that can be quoted on their own
- **Prerequisites**: what this segment assumes you already know (list them, do not explain)
- **Left unclear**: places the teacher glossed over but that may be traps
- **Rewatch anchor**: if I rewatch only 30 seconds, which moment should it be, and why

Finally give a knowledge structure for the whole section (an indented list is fine; do not draw mermaid).

Subtitles:
{paste the srt/md content here, or let the model read the file on disk}
```

**Why it is designed this way**:
- "Prerequisites" exposes your knowledge gaps — this is where self-study most easily gets stuck;
- "Left unclear" leaves hooks for follow-up questions later;
- "Rewatch anchor" is 10 times more efficient than a "full rewatch".

### A3. Follow-Up Questions (this is where real learning happens)

Do not ask "what did this section say" (you already have that). Ask:

```
About the "round-robin" example at 12:30, I have a question:
if all processes have the same priority, what is the relationship between round-robin and time-slice size?
The teacher seems not to have expanded on it. Please explain with a small example, and point out the likely misconceptions in my understanding.
```

```
In this segment I cannot tell "critical section" and "mutex" apart.
Please explain them with the "two people fighting over one pen" analogy, then tell me:
in what scenarios can these two terms **not** be used interchangeably?
```

> The mindset: **a follow-up question must carry a time code and concrete terms.** Vague questions get vague answers.

---

## 3. Scenario B: Courses Without Subtitles

A large number of older courses and screen-recording courses on Bilibili have no subtitles. Two routes:

### B1. Local ASR (free, uses CPU/GPU)

```
This video has no subtitles. Use the asr command of bili_watch to transcribe it locally.
If the result is judged "suspected hallucination", tell me — do not use it as the original text directly.
```

- Requires Python 3.10~3.14 + faster-whisper (one-click install from the plugin panel).
- Default model is `small`, good enough for Chinese; for more accuracy set `BILI_ASR_MODEL=medium` (2~3 times slower).
- With an NVIDIA card you can enable the GPU, roughly 2 times faster ("use GPU when transcribing" in the panel).
- **Transcripts come with a confidence verdict**: `trusted` / `suspected hallucination`. The latter is common for pure music, segments with no speech, and very heavy accents.

### B2. Cloud ASR (works as long as you have network)

If you do not want to install Python:
- `dsh-bili-eyes` / `dsh-bili-video` support SiliconFlow SenseVoice (put the key in `~/.dsh/asr.json`);
- Billed per minute, with decent Chinese recognition quality, but only average accuracy on **anime dialogue / heavy accents**.

### B3. Validating Transcript Quality (important)

ASR mis-transcribes proper nouns (进程 "process" comes out as 京城 "capital city", 快排 "quicksort" as 快牌). So add this line to the prompt:

```
The following is an ASR transcript and may contain wrong characters. When summarizing:
1. Correct obviously implausible words according to context, and annotate them as [corrected from context: original → new]
2. Keep anything you cannot determine as-is and mark it with [?]
3. For numbers, formulas and code, if the context is unclear, list them separately for me to check
```

---

## 4. Scenario C: Whiteboard / PPT / Code Demos

Purely spoken courses do not need the visuals, but **derivations, architecture diagrams and hands-on coding** do. Three tiers:

### C1. Official Frame Grab (cheapest, no ffmpeg)

```
Use the peek command of bili_watch to look at this video, and give me the 5 frames plus the top comments.
```

`peek` uses Bilibili's official frame-grab endpoint: no video download, no ffmpeg dependency.

### C2. Frame Extraction + OCR (turn the picture into text)

```
Use the frames command of bili_watch with --step 30 --ocr
to extract all on-screen text of the whole lesson, focusing on the whiteboard and the code area.
```

- Turning "pictures" into "text" lets DeepSeek read them — this is **the only viable visual route under today's text-only models**.
- The downside is losing graphical relations (arrows in an architecture diagram, connectors in a flowchart); all you get is scattered labels.

### C3. Real Vision (requires a multimodal model)

```
Use the inspect command of bili_vision to look at {BV number}, focusing on the derivation from 15:00-18:00,
grid-size 1, max-vision 6. I want to see every transformation step clearly.
```

Prerequisite: the current conversation uses **a model that supports images**. DeepSeek does not by default;
either switch models, or use `run` with a separate vision model (MiMo etc.).

### C4. Precise Locating for Rewatch (`dsh-bili-video` only)

```
Use video_locate to find roughly which minute it is where the teacher says this algorithm will degrade.
```

The value of this tool: **you remember there was a point, but forgot where**. One query beats dragging the progress bar for ten minutes.

---

## 5. Scenario D: Managing a Series (`dsh-bili-study`)

### D1. Build the Catalog

Once installed, "Bilibili Study Hub" appears in the sidebar. The first step is not collecting videos, it is **letting AI generate the catalog**:

```
I want to learn {operating systems}, with the goal of {being able to implement a simple scheduler on my own},
over {8 weeks, 6 hours per week}.
Please give me a three-level catalog as "subject → chapter → topic",
annotating each chapter with its estimated duration and minimum completion standard.
```

It calls `bili_study_save_catalog` to write the catalog.

### D2. Collect Videos

Three kinds of input are supported:
- A creator's homepage link (fetches all uploads)
- A favorites-list link (fetches the whole favorites list)
- A single video link

Everything fetched lands in "Uncategorized". You can drag and drop, or:

```
Smart-classify this batch of uncategorized videos against the catalog. Show me the suggestions first, and write them only after I confirm.
```

> ⚠️ "Smart classification" produces a preview before writing. Do not let it write directly — courses with similar titles often get sorted wrong.

### D3. Notes

- Markdown and KaTeX supported: inline `$O(n\log n)$`, block `$$...$$`.
- Take notes on the right while watching; playback progress is saved automatically.
- Notes can be exported (to use with Obsidian/Notion).

**Note template** (paste it in each time you create a new topic):

```markdown
## {chapter name}

> Video: https://www.bilibili.com/video/{BV number}?p={part number}&t=0 ｜ duration ｜ first watched {date}

### My goal
(what I want to be able to do after this section, one sentence)

### Knowledge points
#### 1. {knowledge point} `[12:34]`
- In one sentence:
- Why it matters:
- Common pitfalls:

### Formulas / code
```
(copy verbatim, do not rewrite)
```

### Not understood
- [ ] {question} → asked AI / to look up / resolved

### One-sentence summary
(close the video and write it in your own words)
```

> The last item, "close the video and write it in your own words", is the only action in the whole note that truly tests whether you have learned it.
> Everything above it is raw material; this one is the output.

### D4. Concept Lookup and Knowledge Graph

- Select a piece of text → "Concept lookup" → ask AI directly, without leaving the panel;
- "Knowledge graph" draws the topic relations of the current subject;
- "AI prerequisite links" generates prerequisite relations between topics — **use it to discover whether you skipped something**.

---

## 6. Scenario E: Self-Testing and Review

### E1. Generate Questions (prompt)

```
Based on the notes for this section, write 5 questions, with a difficulty spread of 2 easy, 2 medium, 1 hard:
- 2 concept-discrimination questions (two easily confused terms)
- 2 applied questions (given a scenario, decide what to use)
- 1 counterfactual "what would happen if..." question

Requirements:
- Tag each question with the knowledge point it tests and the corresponding time code
- Give only the questions first; give the answers and explanations after I answer
- The explanation must point out "choosing X means you assumed..."
```

> "Give only the questions first" matters. If the answers arrive in the same message, you will not be able to resist looking.

### E2. Reviewing Wrong Answers

```
I got question 3 wrong; my answer was B.
1. Tell me exactly why B is wrong (where my reasoning broke)
2. At which minute of the original video is this knowledge point
3. Explain it again with another approach (do not repeat the teacher's)
4. Give me a variant question of the same type
```

### E3. Spaced Repetition (`dsh-web-studyhub`)

Import your notes and it will:
- generate flashcards with source citations;
- schedule reviews with the **FSRS-6** algorithm (more adaptive to your forgetting curve than a rigid Ebbinghaus schedule);
- generate quizzes and open-ended questions.

```
Import the notes for the course {course name} into studyhub, schedule reviews with FSRS-6,
and keep it under 20 cards per day.
```

### E4. Weekly Review Prompt

```
These are my watching records and note list in the Bilibili study hub for this week.
1. Give me a weekly report by "time invested / notes produced / self-test accuracy"
2. Point out which sections I watched but took no notes on (most likely wasted)
3. Which knowledge points I kept rewatching (meaning I have not really understood them); suggest relearning them with a different explanation
4. Priority ordering for next week
```

---

## 7. Scenario F: Finding Courses

```
Use bili_search to search for "{distributed systems}", sorted by favorites, only videos longer than 20 minutes.
Give me 8 candidates, each listing: creator, duration, views, favorites, whether it is a series course, and a one-line verdict on whether it is worth watching.
```

Filtering heuristics (criteria for the AI's judgment, and for you too):

| Signal | Explanation |
|---|---|
| favorites/views ratio > 5% | means it is a course "worth watching repeatedly", not an entertainment video |
| has a series/collection | systematic, more reliable than a single episode |
| duration 30~90 minutes | too short cannot explain things through, too long and attention gives out |
| creator is an institution/verified teacher | guarantees a quality floor, but may just read from the book |
| comments ask for "slides / companion code" | indicates high content density |

---

## 8. Cost Control: Do Not Let One Video Burn Half a Day's Quota

### 8.1 Do the Math

| Content | Volume | Approx. tokens |
|---|---|---|
| 1 hour of spoken subtitles | 12k~18k Chinese characters | 8k~13k |
| 3-hour series course | 40k~50k characters | 30k~40k |
| one `sheet` 3x3 grid image | 1 image | 1k~4k (and DeepSeek cannot use it) |

### 8.2 Three Hard Rules

1. **Feed one section at a time.** Do not throw a whole course collection in; the context gets diluted and the model starts making things up.
2. **Write to disk + read in chunks.** `dsh-bili-watch` automatically writes output longer than 800 characters to disk and returns only a summary — **this is a feature, not a bug**; have the model `read` it in chunks, which is more accurate than stuffing everything in at once.
3. **Turn images on only when you really need to ask "what is written in the picture".** DeepSeek is text-only; images are wasted.

### 8.3 Money-Saving Prompt

```
For the following task, please follow these rules:
- Do not restate the subtitle text; only distill it
- No knowledge point longer than 3 lines
- If a segment is pure review / pure transition, just say "skip" and give the time code
- At the end, give a list of "if time is limited, watch only these three segments"
```

---

## 9. Full Walkthrough: A 30-Minute Section on "Process Scheduling"

| Step | What you say | What happens | Time |
|---|---|---|---|
| 1 | "Use bili_watch to export the subtitles of BV1xx as md" | 40 timestamped blocks of text, written to disk | 20s |
| 2 | "Split by natural segments and do the segment-by-segment deep dive" (paste template A2) | 4 segments, each with conclusions/prerequisites/anchors | 60s |
| 3 | "I did not get the example at 12:30; explain it with the pen analogy" | follow-up, plain-language explanation | 30s |
| 4 | "Turn the above into the note template and save it into the study hub" | written via `bili_study_*`, formulas included | 20s |
| 5 | "Write 5 questions, questions only" | 5 questions + knowledge point/time code tags | 30s |
| 6 | (answer yourself, get question 3 wrong) "I chose B for question 3" | error analysis + variant question | 30s |
| 7 | "Record the wrong answer and its time code under 'Not understood' in the note" | note updated | 10s |
| 8 | (one week later) "Go through the studyhub review plan" | 12 flashcards | 8min |

**Total interaction is about 3 minutes + your own answering and watching time.** That is the right proportion for "assistance".

---

## 10. FAQ

**Q: The AI summary is vague, all "this section introduces...". What should I do?**
A: Two reasons — ① you fed too much at once; ② the prompt had no constraints. Use template A2 to force it to output "key conclusions", "left unclear" and "rewatch anchors"; it cannot produce vague text with those.

**Q: Cannot get the subtitles?**
A: First confirm the login state (`bili_watch login` QR code scan); if that still fails, the video truly has no subtitles — go with ASR.

**Q: The model says "I cannot watch videos"?**
A: It did not call the tool. Say explicitly "use the bili_watch tool", or check whether the plugin is mounted (in a new session, ask "what bilibili-related tools do you have").

**Q: I take notes but never read them?**
A: That is a process problem, not a tool problem. Outsource review to FSRS (studyhub); do not rely on willpower.

**Q: Can it watch all my courses automatically?**
A: Technically yes (things like `dsh-bili-scroll`), but **not recommended** — automated summaries lack the human "being stuck" feeling, and you end up with a pile of perfect notes you forget right after reading. Learning needs exactly that stuck process.
