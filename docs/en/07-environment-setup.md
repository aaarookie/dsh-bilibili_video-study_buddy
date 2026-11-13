# 07 · Environment Setup Notes (What Was Actually Changed This Time)

> Records **every change** made in this configuration on 2026-11-13, **why it was chosen this way**, **how it affects you**, and **how to undo it**.
> Principle: only touch user-level settings; do not touch system directories, do not modify the system PATH, do not overwrite your existing Python.

---

## 1. What Was Installed

| Component | Version | Location | Size | Purpose |
|---|---|---|---|---|
| **ffmpeg** | `N-92722` (2018 build) | `E:\tools\ffmpeg\bin\ffmpeg.exe` | 61.5 MB | Frame extraction, transcoding, audio extraction |
| **ffprobe** | `2023-02-13 essentials` | `E:\tools\ffmpeg\bin\ffprobe.exe` | 77.2 MB | Read duration/encoding/stream info |
| **yt-dlp** | `2026.10.26` | `E:\tools\bin\yt-dlp.exe` | 22.5 MB | General-purpose video download (non-Bilibili links) |
| **uv** | `0.13.8` | `E:\tools\uv\uv.exe` | 46.4 MB | Manage Python versions, install dependencies |
| **Python 3.12** | `3.12.16` (managed by uv) | `%APPDATA%\uv\python\cpython-3.12.16-...` | 62.1 MB | Dedicated interpreter for ASR/OCR |
| **bili-env venv** | 3.12.16 | `E:\tools\pydeps\bili-env` | 404.1 MB | Working environment with faster-whisper / rapidocr installed |

**About 813 MB in total** (`E:\tools` 750.9 MB + 62.1 MB for Python 3.12 under the user directory).

**What was not installed and not touched**: your Python 3.14, the system PATH, the registry (except the user PATH), any system directory, the Bilibili account.

---

## 2. Three Key Decisions, and Why

### 2.1 Python: you already had 3.14, but I installed 3.12 separately

**Your actual situation** (what I found):

```
py -0p
  -V:3.14[-64] *   %USERPROFILE%\AppData\Local\Python\pythoncore-3.14-64\python.exe
```

You really did install Python — **3.14.7**, through the newer Python Manager (the `pythoncore` layout);
the `py` launcher recognizes it, and `pip 26.2.1` is there too.

**So why does `python --version` report "not found"?**

Because there are two pythons in PATH:

```
%USERPROFILE%\AppData\Local\Microsoft\WindowsApps   ← position 2, holding the "Microsoft Store stub"
%USERPROFILE%\AppData\Local\Python\bin              ← position 5, the real 3.14
```

The stub comes first, so `python` hits the stub (a fake exe that only pops up the Store page).
This is Windows' "app execution aliases" mechanism — **it is not that you didn't install it**.

**Why does ASR still use 3.12 instead of 3.14?**

Python 3.14 is too new; `ctranslate2`, which `faster-whisper` depends on, is a C++ extension,
and there has to be a prebuilt `cp314` wheel on PyPI before it can be installed. In practice, 3.12 installed in one go:

```
faster-whisper 1.2.1
ctranslate2 4.9.0
onnxruntime 1.32.0
opencv 5.0.0
```

So the strategy is: **leave your 3.14 as it is** (other projects may be using it), and **run ASR/OCR in a separate 3.12 venv**, so the two do not interfere.

### 2.2 ffmpeg: why the version is from 2018

The normal channel is the zip from gyan.dev, but I measured the download speed at only **43 KB/s** (45 minutes for 109 MB), so I gave up on it.

I switched to npm's `@ffmpeg-installer/win32-x64`, which **finished downloading in 20 seconds**. The trade-off is that it ships an older build:

```
ffmpeg version N-92722-gf22fcd4483 Copyright (c) 2000-2018
```

**Is it enough? Measured: yes**:

- ✅ H.264 decoding (Bilibili's main codec)
- ✅ HEVC/H.265 decoding (Bilibili's other track)
- ✅ JPEG output, precise `-ss` seeking, `libx264` encoding
- ❌ Does not support newer codecs such as AV1 / VVC (Bilibili is not using them at the moment)

If you run into a video it cannot decode later, just swap in a newer build (overwrite the new `ffmpeg.exe` into `E:\tools\ffmpeg\bin`; PATH does not need to change).

### 2.3 uv / yt-dlp: single files, nothing written to the system

Both are portable single files: unzip and run, no installation, no registration, no administrator rights needed.
This is also why `uv python install 3.12` installs into `%APPDATA%\uv` instead of `Program Files`.

---

## 3. What Changed in PATH

Only the **user-level PATH** was changed (registry `HKCU\Environment`); the system level was left alone.

At the **end** of the original 11 entries, 3 more were **appended**:

```
E:\tools\bin          → yt-dlp
E:\tools\uv           → uv, uvx
E:\tools\ffmpeg\bin   → ffmpeg, ffprobe
```

**The original value was backed up before the change**:

```
E:\tools\PATH-backup-20261113-203510.txt
```

> Appending **at the end** is intentional: it has the lowest priority, so it will not override tools of the same name that you already have.

---

## 4. How These Changes Affect You (read this section closely)

### ✅ Positive effects

1. **Any newly opened terminal** can use `ffmpeg` / `ffprobe` / `yt-dlp` / `uv` directly.
2. **DSH plugins can discover them automatically**: `dsh-bili-watch` looks for ffmpeg in the order "`--ffmpeg` argument → `BILI_WATCH_FFMPEG` → config → `deps/ffmpeg.exe` → PATH", and now that it is in PATH, it works out of the box. Its search order for Python is "uv-managed 3.12/3.13 → `py` launcher → system Python", and now uv and 3.12 are both in place.
3. The `py` launcher is unaffected; your existing 3.14 workflow stays exactly the same.

### ⚠️ Four Things to Be Aware Of

**① The `python` command is still broken (I did not fix it, and that is deliberate)**

```powershell
python --version     # → "Python was not found..." (still the stub)
py --version         # → Python 3.14.7 (normal)
```

I left it alone because fixing it would mean either changing system settings (turning off app execution aliases) or reordering PATH, and either could affect your other projects.
**Current usage**: use `py`, or the absolute path to 3.12, `E:\tools\pydeps\bili-env\Scripts\python.exe`.

> To fix it completely: Settings → Apps → Advanced app settings → App execution aliases → turn off `python.exe` / `python3.exe`.
> After turning them off, `python` will fall through to `%USERPROFILE%\AppData\Local\Python\bin`, which is position 5 in PATH — the real 3.14.

**② Programs that are already running cannot see the new PATH**

DSH, VSCode, and terminals **must be restarted to read the new PATH**. I refreshed it manually in the current process, but that only applies to this one process.

**③ The ffmpeg version is on the old side**

See 2.2. Day-to-day frame extraction is fine; with newer codecs it will report "Unknown decoder".

**④ Disk usage is about 813 MB**

Mostly in `E:\tools\pydeps\bili-env` (404 MB, the dependencies of two venvs). Drive E still has 375 GB, so it is not tight.

### 🔒 What Is Unaffected

- Your Python 3.14 and its installed packages (numpy 2.5.4 / onnxruntime 1.31.1 / python-docx) — not a single one touched
- Those venvs under `E:\dswechat`, `E:\minimax_music3`, `E:\WiFilocation` — not a single one touched
- The system PATH, the system Python, other registry keys
- The Bilibili account (**no account was logged in**; frame extraction was anonymous throughout)

---

## 5. How to Verify

```powershell
# 1. Are the tools in place (open a new terminal)
ffmpeg -version
ffprobe -version
yt-dlp --version
uv --version

# 2. Is the ASR environment usable
E:\tools\pydeps\bili-env\Scripts\python.exe -c "import faster_whisper, cv2; print('ASR/OCR OK')"

# 3. End-to-end frame extraction
cd <repo>
.\bili-frame.ps1 -Video BV1HE421j7Lt -At 12:00 -Page 5
```

Item 3 should output a jpg of about 60 KB and a review link with `?p=5&t=720`.

---

## 6. How to Undo It (if you don't want it someday)

In order:

```powershell
# 1. Restore the user PATH (using the original value in the backup file)
$orig = Get-Content "E:\tools\PATH-backup-20261113-203510.txt" -Raw
[Environment]::SetEnvironmentVariable('Path', $orig.Trim(), 'User')

# 2. Delete the tools directory (including the venvs)
Remove-Item "E:\tools" -Recurse -Force

# 3. Delete the Python 3.12 installed by uv (optional, does not affect your 3.14)
& "$env:APPDATA\uv\python\..\..\uv.exe" python uninstall 3.12 2>$null
Remove-Item "$env:APPDATA\uv" -Recurse -Force -ErrorAction SilentlyContinue
```

Restart the terminal after deleting. Your 3.14 and other projects are completely unaffected.

---

## 7. Pitfalls Already Hit and Fixed (for reference)

| Pitfall | Symptom | How it was fixed |
|---|---|---|
| gyan.dev too slow | 43 KB/s, estimated 45 minutes | Switched to npm's `@ffmpeg-installer`, done in 20 seconds |
| `-File` argument passing doesn't split commas | `-At 1:30,5:00` was treated as a single string | Split manually with `-split ','` inside the script |
| `$bvid?p=` was treated as a variable name | The review link became `.../video/=5&t=600` | Switched to `${bvid}?p=` |
| PowerShell treats ffmpeg's stderr as a fatal error | A TLS blip threw an exception and aborted the run | `ErrorActionPreference='Continue'` + explicit `throw` |
| Occasional TLS failures on Bilibili's CDN | `Error in the pull function` | Rotate the URL list (primary address + backupUrl) + retry |
| Multi-P timestamp out of range | Frame extraction produced an empty file | Validate against `pages[].duration` first; warn directly when out of range |
| Count came out empty | "Succeeded  items" | `@(...).Count` to force an array |

All of these are already built into `bili-frame.ps1`.
