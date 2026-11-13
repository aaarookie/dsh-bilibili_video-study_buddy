# 04 · Installation, Configuration and Pitfalls

> Written against the current state of this machine: Windows, DSH `0.2.2-rc.1`, profile `web`, no Python, no ffmpeg.
> Every step is annotated with "why" and "what to do if it fails".

---

## 1. Get Three Things Straight First

### 1.1 Where your `dsh` command is

On this machine `dsh` is **not on PATH**; it runs straight from a source checkout:

```powershell
# the full invocation equivalent to dsh
node E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js --version
# → 0.2.2-rc.1
```

So every `dsh plugin ...` command in this document has to be written like this on this machine:

```powershell
$dsh = "E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js"
node $dsh plugin --profile web add dsh-bili-watch
```

(To save trouble, set `$dsh` as an environment variable, or use the wrapper in [install.ps1](install.ps1).)

### 1.2 Your profile is `web`

```powershell
node $dsh plugin --profile web add <package-name>
```

Getting `--profile` wrong is the most common cause of "installed but nothing happens". Desktop users usually have one called `desktop`;
this machine is the Web build, so use **`web`**.

### 1.3 A restart is required after installing

DSH assembles plugins at the bundle layer, and **they are not loaded without a restart**. It also caches plugin modules, so
`remove` + reinstall does not hot-reload either. How to restart:

- Close the current DSH Web process (the `bin.js web --no-open` one in Task Manager) and start it again;
- Or reopen it with the shortcut you normally use to start DSH.

> ⚠️ A restart interrupts the current session (the transcript is not lost, but running tasks are cut off). Do it when you are idle.

---

## 2. Install Dependencies (only as needed, not all of them)

### 2.1 ffmpeg — only needed to "look at the picture"

**Route 1 (recommended): let the plugin install it itself**

After installing `dsh-bili-watch`, open "Plugins → dsh-bili-watch → Dependency status",
click the download button at the end of the ffmpeg row, and it uses its built-in `fetch-deps` (China mirrors supported).
The settings page of `dsh-bili-eyes` also has a "Download ffmpeg" button.

- ✅ Pros: correct version, paths configured automatically, no need to worry about PATH
- ⚠️ Note: **DSH must not be closed during the download** — when the host exits it kills the download process too; if interrupted, go back into the panel and click again, and already-finished parts are skipped

**Route 2: install with winget (winget is available on this machine, v1.29.380)**

```powershell
winget install --id Gyan.FFmpeg -e --accept-source-agreements
```

After installing, **open a new terminal** to verify (PATH has to be refreshed):

```powershell
ffmpeg -version | Select-Object -First 1
```

**Route 3: portable build (if you do not want to touch the system)**

Download `ffmpeg-release-essentials.zip` from gyan.dev, unzip it to e.g. `D:\tools\ffmpeg`,
then add `D:\tools\ffmpeg\bin` to the user PATH; or simply set the `BILI_WATCH_FFMPEG`
environment variable in the plugin panel to point at `ffmpeg.exe`.

> The test: **both** `ffmpeg -version` and `ffprobe -version` have to work (some packages ship only ffmpeg).

### 2.2 Python — only needed for local ASR / OCR

**⚠️ The biggest trap on this machine: the `python` command exists, but it is fake.**

```
> python --version
Python was not found; run without arguments to install from the Microsoft Store...
```

That is the Windows "app execution alias" placeholder. If, after installing the plugins, it detects "Python available" but crashes the moment it runs,
this is almost certainly the reason.

**The correct way to install it:**

```powershell
winget install --id Python.Python.3.12 -e
```

Then you **must** do this step: open "Settings → Apps → Advanced app settings → App execution aliases",
turn **off** both the `python.exe` and `python3.exe` switches, then open a new terminal to verify:

```powershell
python --version    # expected: Python 3.12.x
py --version        # the py launcher works too
```

**Alternative: install `uv` (less hassle)**

```powershell
winget install --id astral-sh.uv -e
uv --version
```

`uv` can fetch Python itself, create venvs and install wheels, and many plugins prefer it.
`dsh-bili-subagent` and `dsh-bili-video` try to download their own copy of uv when no Python is detected.

> Python version range: `dsh-bili-watch` requires 3.10~3.14; `dsh-bili-vision` requires 3.10+. **3.12 is the most stable**.

### 2.3 yt-dlp — only affects "non-Bilibili links"

```powershell
winget install --id yt-dlp.yt-dlp -e
```

For pure Bilibili use you can skip it.

### 2.4 VC++ Runtime — the hidden dependency of ASR/OCR

`faster-whisper` / `onnxruntime` are C++-compiled wheels and need `vcruntime140.dll` at runtime.
Win10/11 normally ships it, but stripped-down images may lack it; the symptom is **pip installs fine, then `DLL load failed` on import**.

Fix (independent of the Python version, no need to recreate the venv):
<https://aka.ms/vs/17/release/vc_redist.x64.exe>

---

## 3. Install Plugins by Option

> The two routes below are equivalent, pick either: **GUI** (Settings → Plugins → Add plugin, enter the package name) or **CLI**.
> GUI is better for daily use; CLI is better for batches and copy-paste.

### Option A: zero-dependency start

```powershell
$dsh = "E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js"
node $dsh plugin --profile web add dsh-bili-study
```

- Package: `dsh-bili-study` (npm v1.0.0, 404 monthly downloads)
- Declared requirement: `dsh >=0.2.1-rc.5 <0.3.0` → this machine has 0.2.2-rc.1 ✅
- Restart after installing and "Bilibili Study Hub" appears in the sidebar

### Option B: the main combination (recommended)

```powershell
node $dsh plugin --profile web add dsh-bili-watch
node $dsh plugin --profile web add dsh-bili-study
```

- `dsh-bili-watch` v0.4.10, requires Node ≥ 22 (this machine has v24 ✅)
- The two do not overlap in functionality and can coexist
- Restart after installing → a "bili-watch" panel appears in settings

> If you only want the minimal "link in, summary out" loop, you can add `dsh-bili-summary` as well
> (pure Node, not on npm, so it can only be installed with `add github:YZz-S/dsh-bili-summary`),
> but it does not implement WBI signing, so it breaks as soon as the Bilibili API tightens up; **it is less stable than dsh-bili-watch**.

### Option C: full functionality (install Python + ffmpeg first)

```powershell
# vision/interaction oriented (pick one, do not install both, functions overlap)
node $dsh plugin --profile web add dsh-bili-eyes
# or
node $dsh plugin --profile web add github:13520rygvv/dsh-bili-video

# review oriented (complements the above)
node $dsh plugin --profile web add "@ericwang1358/dsh-daily-flashcard"
# i.e. the npm package name of dsh-web-studyhub
```

- `dsh-bili-eyes`: npm 0.8.3, Node ≥ 20, ffmpeg installable with one click in the panel
- `dsh-bili-video`: GitHub only, **hard dependency on Python + ffmpeg**, QR-code login required after installing
- `dsh-bili-vision`: GitHub only, Python + ffmpeg + ffprobe, and `inspect` requires the current model to be able to see images
  ```
  node $dsh plugin --profile web add "git+https://github.com/icyaaaww/dsh-bili-vision.git#v0.2.0"
  ```

### Things not to install

| Package | Reason |
|---|---|
| `dsh-bili-scroll` / `dsh-bili-whale` / `dsh-bili-pond` / `dsh-fish` | Automatically browses the site + posts comments on your account; useless for studying and carries account risk |
| `dsh-bili-live` / `dsh-bili-danmaku-lite` | Live streaming |
| `dsh-video-coursemap` | Depends on subtitle coverage; most videos have no subtitles → empty handbook |
| `dsh-video-understand` | Needs ffmpeg + a MiMo API key, and the semantic layer is 2 GB; poor value for this machine |

---

## 4. Bilibili Login (only needed if you want AI subtitles)

### Way 1: QR code (recommended)

After installing `dsh-bili-watch`, click "Scan QR code to log in" in the panel; the QR code appears right in the panel and refreshes automatically once you scan it with the Bilibili mobile app.
The credential lands in `~/.dsh/bili-watch/credential.json`.

> On the confirmation page after scanning, choose "**Remember me / long-term**"; with the 24-hour option you have to scan again the next day.

### Way 2: fill in SESSDATA manually

Take `SESSDATA` and `bili_jct` from browser cookies, and assemble them into:

```json
{"sessdata":"...","bili_jct":"...","buvid3":"...","buvid4":"..."}
```

### Security notes (must read)

- **Use a secondary account.** The credential is equivalent to your account password; whoever has it can act as you.
- Do **not** commit the credential file to git, do not screenshot it to other people, do not sync it to cloud drives.
- Write operations in these plugins (likes/comments/one-click triple) are all off by default; **do not turn them on for studying**.
- Bilibili returns `-412` risk control for abnormal requests, and may also ask for a captcha; if that happens, stop for a while.

---

## 5. How to Verify After Installing

### 5.1 Are the tools mounted

**Open a new session** (important: an old session does not refresh its tool list) and ask:

```
Which tools do you currently have related to bilibili or video? List the tool names with a one-line description of each.
```

You should see `bili_watch` (or the tool names of whatever other plugins you installed).

### 5.2 Smoke test

```
Use the view command of bili_watch to look at BV1GJ411x7h7 and tell me the title, creator and view count.
```

`view` is pure HTTP — **no ffmpeg, no login needed** — so it is the best way to verify whether the chain works.

### 5.3 Panel check

Under "Settings → Plugins → dsh-bili-watch", the dependency status should list item by item:
ffmpeg / yt-dlp / ASR environment / OCR environment / transcription model / login credential — for each, whether it is ready, its path and its size.

> The panel also has a "Diagnostic prompt" button: it copies a diagnostic instruction in one click; paste it to DSH and it will investigate read-only and produce a report.

---

## 6. Error Quick Reference

| Symptom | Cause | Fix |
|---|---|---|
| Nothing appears after install and restart | plugins live at the bundle layer and need a restart; or `--profile` is wrong | confirm `--profile web`; fully kill the process and restart |
| The plugin page says "enabled" but the tools are unavailable | leftover `disabled: true` from an old version (known bug in `dsh-bili-watch` 0.3.1 and earlier) | upgrade to 0.3.2+ and run `add` once more |
| Installed but behaves as if not installed, and no error either | DSH version requirement not met; the kernel **silently skips** it | compare the plugin's `engines.dsh`; this machine's 0.2.2-rc.1 already satisfies mainstream plugins |
| Startup crash with `import failed` | `load({id})` in `client.js` does not match `name` in `package.json` | contact the plugin author; or disable that plugin first |
| Startup crash with `Unexpected token ''` / `is not valid JSON` | the profile's `package.json` was saved as **UTF-8 with BOM** | rewrite it with `UTF8Encoding($false)`; see below |
| `python` passes detection but crashes when run | Windows app execution alias stub | turn the alias off, or point the plugin at the real interpreter path |
| ASR reports `DLL load failed` | missing VC++ runtime | install vc_redist.x64 |
| Fetching subtitles returns "no subtitle track" | not logged in, or the video really has no subtitles | log in by QR code; otherwise use ASR |
| Returns `-412` | risk control triggered | lower the frequency, wait a while, switch accounts |
| Frame extraction / grid image reports ffmpeg not found | not installed, or not on PATH | one-click install in the panel, or set `BILI_WATCH_FFMPEG` |
| Dependency download fails halfway through | the host exited and killed the download process | go back into the panel and click again; finished items are skipped |
| sharp install wants to compile | node-gyp lacks build tools on Windows | only encountered when installing `dsh-bili-summary`; without build permission it degrades to "cover only" |

**BOM fix** (the kind that crashes in `readProfileManifest`):

```powershell
$p = "$env:USERPROFILE\.dsh\profiles\web\package.json"
$txt = [System.IO.File]::ReadAllText($p)
[System.IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($false)))
```

> ⚠️ Files you edit by hand inside the profile must always be **UTF-8 without BOM**. Do not use `Set-Content -Encoding UTF8`
> or `Out-File -Encoding utf8` (both of these default to a BOM in Windows PowerShell).

---

## 7. Uninstall and Rollback

```powershell
# uninstall a single plugin
node $dsh plugin --profile web remove dsh-bili-watch

# see what is installed (pnpm list may print nothing when not a TTY; in that case reading package.json is more reliable)
Get-Content "$env:USERPROFILE\.dsh\profiles\web\package.json" -Raw |
  ConvertFrom-Json | Select-Object -ExpandProperty dependencies
```

- Uninstalling does **not** delete data: `~/.dsh/bili-watch/` (cache, credential, config) and
  `~/.dsh/bili-study/state.json` are all still there. They are picked up automatically after reinstalling.
- If a plugin stops DSH from starting: the DSH crash dialog offers
  **"Disable third-party plugins, back up profile patch, and restart"** — get it running first, then diagnose.
- In extreme cases you can manually edit `~/.dsh/profiles/web/cordis.patch.yml` and add that `disabled: true` line.

---

## 8. One-Click Script

[install.ps1](install.ps1) in this directory wraps the steps above:

```powershell
# only show what would be done, without doing it
.\install.ps1 -Plan B -WhatIf

# install option B (checks the environment → installs plugins → prompts for restart, in order)
.\install.ps1 -Plan B

# install ffmpeg with winget as well
.\install.ps1 -Plan B -WithFFmpeg

# check the environment, install nothing
.\install.ps1 -Check
```

The script does only four things: **probe the environment → print the plan → execute the steps you selected → give the restart hint**.
It does not touch your Bilibili account, does not enable write operations, and does not modify existing plugin entries in the profile.

---

## 9. Recommended Finishing Configuration After Installing

1. **Turn off all write operations**: likes/comments/one-click triple/direct messages — all off for studying (they are off by default; do not go and turn them on).
2. **Limit auto-browsing**: if you installed a plugin with auto-browsing (not recommended), set "rounds per day" to 0.
3. **Cache limit**: `dsh-bili-watch` keeps 7 days / 2048 MB by default; adjust it to your disk situation.
4. **Add a standing instruction for the model** (write it into `~/.dsh/AGENTS.md` or the project's AGENTS.md):

```markdown
## Bilibili study conventions
- When handling Bilibili videos, prefer the bili_watch tool; do not guess the content from the title.
- Before quoting the course verbatim, if ASR flagged it as "suspected hallucination", state the uncertainty first.
- Subtitles longer than 800 characters are written to disk; read them in chunks with read, do not ask for the full text at once.
- Summaries must carry [mm:ss] time codes so I can rewatch.
```

This line is more effective than any plugin setting — it tells the model every time which tool to call and how to format its output.
