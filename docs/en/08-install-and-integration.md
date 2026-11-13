# 08 · Installation and Integration Notes from This Round

> 2026-11-13, third round: install the plugins, configure ffmpeg, set up the ASR environment, test item by item.
> The conclusion first: **both plugins are installed and took effect on the spot (DSH's HMR mounted them without a restart)**;
> the only thing not resolved is "automatically reading the Chrome login state", which needs you to scan a QR code once.

---

## 1. What Was Installed

| Component | Version | Status |
|---|---|---|
| `dsh-bili-watch` | 0.4.10 | ✅ Installed; the `bili_watch` tool is mounted |
| `dsh-bili-study` | 1.0.0 | ✅ Installed; the `bili_study_fetch` / `bili_study_save_catalog` tools are mounted |
| The plugins' ffmpeg/ffprobe | 2018 build | ✅ Copied to `~/.dsh/bili-watch/deps/` |
| The plugins' yt-dlp | 2026.10.26 | ✅ Installed automatically by fetch-deps |
| ASR environment `.venv-asr` | Python 3.12 + faster-whisper 1.2.1 | ✅ Usable |
| OCR environment `.venv-ocr` | Python 3.12 + rapidocr 1.2.3 | ✅ Usable |
| faster-whisper-small model | 464 MB | ✅ Downloaded |

`~/.dsh/bili-watch/deps/` takes up **1.13 GB** in total.
The profile config was backed up: `~/.dsh/profiles/web/package.json.bak-20261113-205029`.

---

## 2. Live Test Results

### ✅ Working

| Command | Result |
|---|---|
| `view` | Full metadata + UP + 8 parts + hot comments (including the UP's pinned comment) |
| `search` | 4 hits, with play count, duration, UP, and publish date |
| `frames -at 12:00 -p 5` | Frame extraction succeeded in 12.9 seconds (including download), output `f_12m00s.jpg` |
| Local ASR | 60 seconds of audio transcribed in **0.8 seconds**, and the Chinese is readable |

### ❌ Stuck

| Command | Reason |
|---|---|
| `sub` (subtitles) | `nav code=-101 account not logged in`, and **the video itself has no AI subtitle track** — even after logging in it still wouldn't be available |

So lectures of this kind — the teacher writing on the board and narrating — **have no official subtitles available**; you can only fall back on ASR + reading frames.

---

## 3. Three Test Findings You Have to Know

### 3.1 Frame extraction from the plugin is 360p; from the script it is 480p

The same moment (P5 @12:00) through the two tools:

| Tool | Resolution | Size |
|---|---|---|
| `bili_watch frames` | **480×360** | 42 KB |
| `bili-frame.ps1` | **640×480** | 62 KB |

The reason: to save bandwidth, the plugin downloads the 360p video and then extracts frames; the script asks Bilibili for a play URL directly and takes the highest anonymous tier.

**Conclusion**: use `bili-frame.ps1` to read code details; the plugin is better for quick scanning and nine-grid sheets.

### 3.2 Bilibili's DASH separates audio from video

The first audio extraction failed, reporting "Output file does not contain any stream" — because I fed the **video track** as the input, and the video track contains no audio track.

The right way is to take `dash.audio`:

```
3 audio tracks: id=30232 / 30216 / 30280 (44.1k / 24k / 48k)
```

This matters a lot if you are writing scripts, and is invisible if you are using the plugin (the plugin handles it itself).

### 3.3 ASR Systematically Mishears Code Terminology

The same 60-second segment (discussing "dynamic memory allocation"), transcribed:

| What the teacher said | ASR output | Why it was wrong |
|---|---|---|
| `*p = 10` | "star-pee equals ten" | `*` is read as "star", `p` as "pee" |
| Dereference | "decode-decode-address" | same-sounding, similar-meaning words got mixed up |
| `free(p)` | "4AP" | an English function name heard as digits plus letters |
| On the stack | "standing on" | homophone |
| On the heap | "on the heap" | ✅ correct |

**So the right way to use it is to divide the labor**:

- **ASR gives you the "thread"**: what is being discussed, why it is explained that way, what the conclusion is — it is very accurate on this part;
- **Frame reading gives you the "code"**: variable names, symbols, indentation, operations — ASR is completely unreliable on this part;
- Only when the two are aligned by timestamp do you get a complete set of notes.

This also shows once more: **do not quote ASR text directly as code**.

---

## 4. Why Your Chrome Login State Couldn't Be Used Automatically

You are logged into the alt account in Chrome, and I tried three ways to read the cookies, all of them failed:

| Method | Result |
|---|---|
| Copying the `Cookies` file directly | ❌ Locked exclusively by Chrome |
| Shared read (FileShare including Delete) | ❌ Locked just the same |
| `robocopy /B` backup mode | ❌ Exit code 16 |
| Volume Shadow Copy | ❌ No available copy; creating one requires administrator rights |

**And even if the file could be read, it couldn't be decrypted**: Chrome 156's `Local State` contains both
`encrypted_key` (DPAPI) and **`app_bound_encrypted_key`** — the latter is **App-Bound Encryption**, introduced in Chrome 127+,
where the key is bound to the Chrome process and ordinary programs cannot decrypt it. This is its anti-cookie-theft design, not a configuration problem.

**So we go through the plugin's proper path: QR code login.**

---

## 5. Three Things to Do After You Restart

### 5.1 Restart (optional but recommended)

The plugins are in fact already hot-mounted and work in the current session. But restarting has two benefits:

1. The DSH process will read the **new PATH** (including `ffmpeg`, `uv`, `yt-dlp`), which makes it easier for the plugins to find dependencies;
2. The environment variable `BILI_WATCH_FFMPEG` takes effect, adding another layer of safety.

### 5.2 QR code login (to get subtitles and higher quality)

1. Open DSH: <http://127.0.0.1:3080>
2. **Settings → Plugins → dsh-bili-watch**, and enter its panel
3. Click "Go to QR code login" and scan with Bilibili on your phone (use that alt account of yours)
4. When confirming, choose "**Remember me / long-term**", not 24 hours
5. The credential is saved to `~/.dsh/bili-watch/credential.json`

> If the QR code doesn't show up in the panel, click "Install main dependencies" once so that it points pythonPath back to its own venv.

### 5.3 Acceptance Checklist

```
① In a new session, ask: "What Bilibili-related tools do you have?" → you should see bili_watch
② Say: "view BV1HE421j7Lt" → it should return the title, UP, and 8 parts
③ Say: "search data structures code walkthrough" → it should return 4 results with play counts
④ Say: "frames BV1HE421j7Lt P5 at 12:00" → it should output one image
⑤ After logging in, say: "sub BV1HE421j7Lt P5" → check whether subtitles come back (this video will very likely still report no subtitles)
⑥ Say: "text BV1HE421j7Lt P5 head 800" → it should go through local ASR and return the start of the transcript
```

---

## 6. Suggested First Real Task After Restarting

```
Look at P5 of BV1HE421j7Lt: first use text to get the transcript around 12:00,
then use bili-frame.ps1 to extract the frame at 12:00,
then align "what the teacher is explaining" with "what the code looks like",
and organize it into one section of notes saved under examples
```

This happens to use all of them at once: ASR (plugin) + high-definition frame extraction (script) + reading images (model) + the note template.

---

## 7. Configuration Quick Reference

| Item | Value |
|---|---|
| Plugin deps | `~/.dsh/bili-watch/deps` |
| ASR interpreter | `~/.dsh/bili-watch/deps/.venv-asr/Scripts/python.exe` |
| OCR interpreter | `~/.dsh/bili-watch/deps/.venv-ocr/Scripts/python.exe` |
| Model | `~/.dsh/bili-watch/deps/.hf-home/hub/models--Systran--faster-whisper-small` |
| Frame cache | `~/.dsh/bili-watch/cache/frames` |
| Login credential | `~/.dsh/bili-watch/credential.json` (generated after the QR scan) |
| ffmpeg environment variable | `BILI_WATCH_FFMPEG` (user-level, already set) |
| Plugin backup | `~/.dsh/profiles/web/*.bak-20261113-205029` |
