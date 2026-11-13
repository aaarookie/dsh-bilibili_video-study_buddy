# 06 · Looking at Code by Timestamp + Structured Notes

> This document corresponds to the second requirement you raised:
> **① While watching a lecture, give a timestamp at the code/algorithm so the model can explain it in detail; ② notes must contain text, images, code, and timestamps.**
> The environment is already set up on this machine (see [07-environment-setup.md](07-environment-setup.md)); everything below is ready to use.

---

## 1. First, split the requirement into three actions

| Action | What you want | How it is done technically | Measured |
|---|---|---|---|
| **Locate** | The code segment at 12:30 | `ffmpeg -ss 750` grabs that frame directly from the Bilibili stream, **without downloading the whole video** | ✅ verified at multiple points: 30s/60s/90s/440s/600s |
| **Understand** | Explain this code clearly | Hand the frame to the model to view (the current model supports image input), together with the subtitle text | ✅ can read blackboard code and color annotations |
| **Capture** | Image + code + text + timestamp | Markdown: local image reference + code block + `?t=` jump link | ✅ [sample](examples/c-pointer-and-malloc/笔记.md) already produced |

---

## 2. Solution overview

```
Your instruction: look at the code at 12:30 in P5 of BV1HE421j7Lt
   ↓
① bili-frame.ps1  ── grab that frame from the Bilibili stream (seconds, no video download)
   ↓
② Model views the image ── reads out the code, annotations, and blackboard structure
   ↓
③ Explanation + note generation ── text / image / code / timestamp, all four present
   ↓
④ Review link ── click it and jump straight to that second
```

**This chain depends on no DSH plugin** and works right now.
Plugins (`dsh-bili-watch` and others) are **enhancements**: subtitles, search, nine-grid, local ASR — see section 7 at the end.

---

## 3. The tool: `bili-frame.ps1`

### 3.1 Basic usage

```powershell
cd <repo>
.\bili-frame.ps1 -Video BV1HE421j7Lt -At 12:30 -Page 5
```

Output:

```
视频: 考研数据结构代码C语言基础
P5/8  指针和malloc  时长 20:11
画质: 640x480  编码 avc1.64001F
[OK]      12:30  ->  .\frames\BV1HE421j7Lt_P5_720s.jpg  (62 KB)
       回看: https://www.bilibili.com/video/BV1HE421j7Lt?p=5&t=720
```

### 3.2 Parameters

| Parameter | Description |
|---|---|
| `-Video` | BV number or full link (required) |
| `-At` | Timestamp(s); may be multiple: `12:30` / `750` / `1:02:30`, comma-separated (required) |
| `-Page` | Which part; **must be specified for multi-part courses**; defaults to 1 |
| `-Quality` | `16`=360p `32`=480p `64`=720p `80`=1080p. **Anonymous usually only gets 480p** |
| `-OutDir` | Output directory; defaults to `.\frames` |
| `-Sessdata` | Bilibili SESSDATA, used to raise quality / avoid risk control (optional) |
| `-Json` | Output JSON, easy for programs to consume |

### 3.3 Grabbing several timestamps at once

```powershell
.\bili-frame.ps1 -Video BV1HE421j7Lt -At "1:00,6:30,12:00,18:00" -Page 5 -OutDir ".\examples\c-pointer-and-malloc\frames"
```

### 3.4 How to make me use it in a conversation

You don't have to memorize commands — just say it in plain language:

```
Look at P5 of BV1HE421j7Lt, the malloc code at 12:30 — explain it to me in detail
```

I will call the script, view the image, and explain. If you want a note saved along the way, just say:

```
Also organize it into a note; put the images under frames/
```

---

## 4. Four pitfalls you must watch out for (all hit in real measurement)

### 4.1 Multi-part videos: a timestamp belongs to "a certain part", not the whole video

This is the easiest thing to get wrong. The course I measured:

```
Total duration 5943s (99 minutes)  ← this is the sum of the 8 parts
P1  626s   data types and input/output
P2  886s   if statements and logical operators
...
P5 1211s   pointers and malloc      ← 20:11
```

If you pass "1:30:00", the script reports "exceeds the P duration". **You must first confirm which part it is.**

> How to tell: the lower right of the Bilibili player has a part list; or look at `?p=5` in the link.
> The script does not auto-guess across parts — a wrong guess grabs a frame from the wrong place; failing outright is better than that.

### 4.2 Quality: anonymous is only 480p, and small code text gets blurry

Measured: anonymous caps at **640×480**; 720p/1080p is only available after login.

The impact on your scenario (reading code) is direct:
- Large-font blackboard writing, code enlarged in the IDE: 480p is enough;
- Full-screen small text, thin fonts on a dark theme: 480p loses strokes, and `1`/`l`, `+`/`t` cannot be told apart.

**Recommendation**: if you watch often, log in once (with a secondary account); with `-Quality 80` the difference is large.
To log in, take `SESSDATA` from the browser and pass it to `-Sessdata`, or use the QR-code panel of `dsh-bili-watch`.

### 4.3 Handwriting recognition has errors; you must annotate

I measured two recognition results on the same frame:

| Actual content | Model viewing the image | OCR (rapidocr) |
|---|---|---|
| `a = a + 10;` | ✅ read correctly | ❌ `a=a+lo;` |
| `a += 5;` | ✅ read correctly | ❌ `a=ats` |
| `a++;` | ✅ read correctly | ❌ `att;` |
| `printf("%d", a);` | ✅ | ✅ |
| `else if (a>=5){` | ✅ | ⚠️ parentheses turned full-width |

**Conclusion: in code scenes, don't rely on OCR, rely on viewing the image.** But viewing is not 100% either, so in notes I will:
- mark uncertain spots with "⚠️ recognition uncertain";
- give a review link so you can check in one second;
- restore the code into compilable form per C syntax, instead of copying garbled characters.

### 4.4 Frame accuracy: `-ss` is "nearest keyframe + decode to the target"

Putting `-ss` before `-i` in ffmpeg is fast seeking; the error is usually within 1 second.
It makes no difference to "what this code is about"; if you need the **exact instant** a line of code appears, pass a timestamp 2–3 seconds earlier and grab.

---

## 5. What a note looks like

Full sample: [examples/c-pointer-and-malloc/笔记.md](examples/c-pointer-and-malloc/笔记.md) (with 4 grabbed frames)

Its structure is exactly the four-piece set you wanted:

```markdown
## 3. Pointers on the stack vs memory on the heap [12:00]

![stack and heap](examples/c-pointer-and-malloc/frames/BV1HE421j7Lt_P5_720s.jpg)   ← image

**Exact words on screen** (subtitle): "that dynamic memory allocation"        ← text

**Code on screen**:
```c
int a = 10;
int *p;
p = &a;
```                                            ← code

| Timestamp | What to look at | Why it is worth rewatching |
|---|---|---|
| [12:00](https://...?p=5&t=720) | compare the two figures side by side | tell "where the pointer is" apart from "where the pointed-to memory is" |  ← timestamp
```

### Note template (copy-paste to the model)

```
Please organize this section into a note, strictly following this structure:

## {section title} [{timestamp}]
Image: {caption} → examples/xxx/frames/xxx.jpg (reference it by relative path)

**Exact words on screen** (subtitle): {subtitle text; write "none" if there is none}

**Code on screen**:
```{language}
{readable code; do not copy garbled recognition output}
```

**Explanation**:
- What problem this piece solves
- What the key concepts are (analogize with what I already know)
- Why it is written this way, and what happens otherwise

**Easy-to-miss points**:
- {1–3 items}

**Review**: {link with ?t=}

Requirements:
1. Mark uncertain recognition with "⚠️ recognition uncertain"; do not guess
2. Restore code per syntax; do not keep OCR typos
3. End with a "review checklist" table
```

---

## 5a. Output to Word (default)

After a note is written, **convert it to Word by default**:

```powershell
py <repo>\md2docx.py "笔记.md"
# outputs a .docx with the same name in the same directory
```

Verified results (the Karpathy note):

| Metric | Result |
|---|---|
| Paragraphs | 149 |
| Tables | 4 (header row bolded) |
| Images | 1 (auto width-limited to 15 cm, centered, with caption) |
| Hyperlinks | 8 (2 in body + 6 in tables, clickable) |
| Code blocks | monospace Consolas + light gray background + indentation preserved |
| File | 108.7 KB |

`md2docx.py` supports: headings H1–H4, paragraphs, bold, inline code, code blocks, tables, images, hyperlinks,
blockquotes, ordered/unordered lists, checkboxes, horizontal rules.

> Note: the output is **.docx** (Word 2007+ format), not the old .doc.
> No software uses .doc these days; .docx is the common format; if you really need .doc, use Word's Save As.

**Why keep Markdown**: Markdown is easy for you to hand-edit, and easy for me to keep editing next time;
Word is the format for external delivery and printing. Keep both, with docx as the primary.

---

## 5b. Resolution and local cropping (measured)

### Logged in vs anonymous

`bili-frame.ps1` automatically reads `~/.dsh/bili-watch/credential.json`; if credentials exist, it fetches the stream in logged-in state:

| Item | Anonymous | Logged in |
|---|---|---|
| Available tracks | 4 (max 480p) | 8 (max **1080P**) |
| Max resolution | 734×480 | **1654×1080** |
| AI subtitles | 0 | **available** (ai-zh) |
| `-Quality 16/32/64/80` | all downgraded to 480p | takes effect |

> Measured: same video, same part; anonymous `accept_quality` lists 80, but DASH only returns 16/32;
> after login it returns all tiers 16/32/64/80.

### Resolution vs tokens

| Tier | Size | Pixels | File | Estimated tokens |
|---|---|---:|---:|---:|
| 360p | 640×360 | 230k | 50 KB | ~240 |
| 480p (anonymous) | 734×480 | 352k | 70 KB | ~345 |
| 720p | 1102×720 | 793k | — | ~800 |
| 1080p (logged in) | 1654×1080 | 1.79M | 259 KB | ~1768 |

### Local cropping: clearer for the same tokens

```powershell
# crop off the top 150 (browser + Colab toolbar), bottom 130 (subtitle bar), right 420 (face thumbnail)
.\bili-frame.ps1 -Video BV1mqrTBvEaf -At 30:00 -Page 7 -Crop "0,150,420,130"
```

Measured five options on the same frame:

| Option | Command | Size | Estimated tokens | Conclusion |
|---|---|---|---:|---|
| Full frame | default | 1654×1080 | 1768 | includes UI/face/subtitles, wasteful |
| **Crop** | `-Crop "0,150,420,130"` | **1234×800** | **975** | ✅ **recommended**, code complete, saves 45% |
| Crop top/bottom only | `-Crop "0,120,0,80"` | 1654×880 | 1456 | fine, but the face window on the right is still there |
| Crop + zoom 1.5 | `-Crop "0,150,380,130" -Zoom 1.5` | ~1910×1200 | ~2200 | larger text, tokens doubled |
| Crop + zoom 2 | `-Crop "0,150,420,130" -Zoom 2` | 2468×1760 | 4290 | unnecessary |

**Two principles**:

1. **Crop first, don't rush to zoom**. Zooming generates no new information, it just spreads the existing pixels out;
2. Only use `-Zoom` as a remedy when the source resolution is low (anonymous 480p) and the text is too small.

**How to set the parameters**: grab one full frame first and measure the UI height, then fill in `left,top,right,bottom`.

- Top (browser tabs + address bar + IDE toolbar): 130–160
- Bottom (subtitle bar + player controls): 100–140
- Right (face thumbnail): 380–450
- Left (file tree, usually can be kept): 0–60

---

## 6. Efficiency tips

### 6.1 Scan coarsely first, then look closely

When you don't know which minute the code is in, don't try frame by frame. First grab one frame every 2 minutes for a rough look:

```powershell
.\bili-frame.ps1 -Video BV1HE421j7Lt -At "0:30,2:30,4:30,6:30,8:30" -Page 3 -OutDir .\scan
```

After I look, I'll tell you "the code is concentrated around 4:30 and 6:30", and then grab 3–4 frames precisely within that minute.

### 6.2 Don't exceed 6 images at a time

Images eat a lot of context. Grabbing 4–6 at a time is just right; if you need to see more, do it in batches, so the model doesn't start "guessing blindly when it can't see clearly".

### 6.3 Let subtitles and the picture complement each other

- **The picture** tells you "what the code looks like"
- **The subtitle/spoken words** tell you "why the teacher wrote it this way"

Only together do they form a complete understanding. Subtitles require login (or the plugin's ASR); see `dsh-bili-watch` in [02](02-plugin-comparison.md).

### 6.4 Jot down "to check" as you go

Leaving three lines of "what I didn't understand" at the end of every note is far more effective than recalling later. The sample note has them.

---

## 7. Relationship to plugins: when you actually need to install one

| What you want | Is the current setup enough | Do you need a plugin |
|---|---|---|
| Look at code by timestamp | ✅ enough | No |
| Generate four-piece notes with text, image, code, timestamp | ✅ enough | No |
| Get the **full subtitle text** with time codes | ⚠️ requires login; the script doesn't do it | Yes (`dsh-bili-watch`) |
| **Search for courses** in Bilibili | ❌ you have to find the BV number yourself | Yes (`dsh-bili-watch`'s search) |
| One-click **nine-grid** / whole-video storyboard | ❌ manual multi-point frame grabbing | Yes (`dsh-bili-watch`'s sheet) |
| **Local transcription** for courses without subtitles | ❌ not wired in | Yes (`dsh-bili-watch`'s asr; the environment is ready) |
| Course catalog / note management / knowledge graph | ❌ | Yes (`dsh-bili-study`) |

**Suggested order**:
1. **Use the current setup first** two or three times, to confirm the workflow feels right;
2. If you genuinely lack subtitles/search/transcription, then install `dsh-bili-watch` (the environment already has ffmpeg + Python 3.12 + uv ready for it);
3. If you need to manage multiple courses long-term, then add `dsh-bili-study`.

---

## 8. Three instructions you can try right now

```
① Look at P2 of BV1HE421j7Lt at 7:20; explain that if/else clearly, and contrast the difference between else if and nested if

② Look at P5 of BV1HE421j7Lt at 12:00 and 18:00; compare the memory diagrams of "pointing to a stack variable" and "malloc onto the heap",
   then organize it into a note section and save it under examples

③ Pull the self-test questions out of examples\c-pointer-and-malloc\笔记.md and quiz me with them; judge my answers when I'm done
```
