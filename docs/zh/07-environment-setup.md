# 07 · 环境配置说明（本次实际改了什么）

> 记录 2026-11-13 这次配置的**全部改动**、**为什么这么选**、**对你有什么影响**、**怎么撤销**。
> 原则：只动用户级，不碰系统目录、不改系统 PATH、不覆盖你已有的 Python。

---

## 一、装了什么

| 组件 | 版本 | 位置 | 体积 | 用途 |
|---|---|---|---|---|
| **ffmpeg** | `N-92722`（2018 构建） | `E:\tools\ffmpeg\bin\ffmpeg.exe` | 61.5 MB | 抽帧、转码、提音频 |
| **ffprobe** | `2023-02-13 essentials` | `E:\tools\ffmpeg\bin\ffprobe.exe` | 77.2 MB | 读时长/编码/流信息 |
| **yt-dlp** | `2026.10.26` | `E:\tools\bin\yt-dlp.exe` | 22.5 MB | 通用视频下载（非 B 站链接） |
| **uv** | `0.13.8` | `E:\tools\uv\uv.exe` | 46.4 MB | 管理 Python 版本、装依赖 |
| **Python 3.12** | `3.12.16`（uv 管理） | `%APPDATA%\uv\python\cpython-3.12.16-...` | 62.1 MB | 给 ASR/OCR 用的专用解释器 |
| **bili-env venv** | 3.12.16 | `E:\tools\pydeps\bili-env` | 404.1 MB | 装了 faster-whisper / rapidocr 的可用环境 |

**合计约 813 MB**（`E:\tools` 750.9 MB + 用户目录下 Python 3.12 的 62.1 MB）。

**没装、没动的东西**：你的 Python 3.14、系统 PATH、注册表（除了用户 PATH）、任何系统目录、B 站账号。

---

## 二、三个关键决策，以及为什么

### 2.1 Python：你本来就有 3.14，但我另外装了 3.12

**你的实际情况**（我查到的）：

```
py -0p
  -V:3.14[-64] *   %USERPROFILE%\AppData\Local\Python\pythoncore-3.14-64\python.exe
```

你真的装过 Python——**3.14.7**，走的是新版 Python Manager（`pythoncore` 布局），
`py` 启动器能识别，`pip 26.2.1` 也在。

**那为什么 `python --version` 会报"not found"？**

因为 PATH 里有两个 python：

```
%USERPROFILE%\AppData\Local\Microsoft\WindowsApps   ← 第 2 位，里面是"应用商店存根"
%USERPROFILE%\AppData\Local\Python\bin              ← 第 5 位，真的 3.14
```

存根排在前面，所以 `python` 命中的是存根（一个只会弹商店页面的假 exe）。
这是 Windows 的「应用执行别名」机制，**不是你没装**。

**为什么 ASR 还要用 3.12 而不是 3.14？**

Python 3.14 太新，`faster-whisper` 依赖的 `ctranslate2` 是 C++ 扩展，
必须等 PyPI 上有对应 `cp314` 的预编译 wheel 才能装。实测我用 3.12 一次装成：

```
faster-whisper 1.2.1
ctranslate2 4.9.0
onnxruntime 1.32.0
opencv 5.0.0
```

所以策略是：**你的 3.14 原样保留**（其他项目可能在用），**ASR/OCR 单独走 3.12 venv**，互不干扰。

### 2.2 ffmpeg：为什么版本是 2018 年的

正常渠道是 gyan.dev 的 zip，但我实测下载速度只有 **43 KB/s**（109 MB 要 45 分钟），放弃了。

改走 npm 的 `@ffmpeg-installer/win32-x64`，**20 秒下完**。代价是它自带的是较老的构建：

```
ffmpeg version N-92722-gf22fcd4483 Copyright (c) 2000-2018
```

**够不够用？实测够**：

- ✅ H.264 解码（B 站主要编码）
- ✅ HEVC/H.265 解码（B 站另一条轨）
- ✅ 输出 JPEG、`-ss` 精确定位、`libx264` 编码
- ❌ 不支持 AV1 / VVC 等新编码（B 站目前没有用这些）

如果以后遇到解不了的视频，再换新构建即可（把新 `ffmpeg.exe` 覆盖到 `E:\tools\ffmpeg\bin` 就行，PATH 不用改）。

### 2.3 uv / yt-dlp：单文件，不写系统

两个都是绿色单文件，解压即用，不安装、不注册、不需要管理员。
这也是为什么 `uv python install 3.12` 装到 `%APPDATA%\uv` 而不是 `Program Files`。

---

## 三、PATH 改了什么

只改了**用户级 PATH**（注册表 `HKCU\Environment`），没动系统级。

在原有 11 条**末尾追加**了 3 条：

```
E:\tools\bin          → yt-dlp
E:\tools\uv           → uv, uvx
E:\tools\ffmpeg\bin   → ffmpeg, ffprobe
```

**改动前已备份原值**：

```
E:\tools\PATH-backup-20261113-203510.txt
```

> 追加在**末尾**是刻意的：优先级最低，不会覆盖你已有的同名工具。

---

## 四、这些改动对你的影响（重点看这节）

### ✅ 正面影响

1. **任何新开的终端**都能直接用 `ffmpeg` / `ffprobe` / `yt-dlp` / `uv`。
2. **DSH 插件能自动发现它们**：`dsh-bili-watch` 会按「`--ffmpeg` 参数 → `BILI_WATCH_FFMPEG` → 配置 → `deps/ffmpeg.exe` → PATH」的顺序找 ffmpeg，现在 PATH 里有，开箱即用。它找 Python 的顺序是「uv 管理的 3.12/3.13 → `py` 启动器 → 系统 Python」，现在 uv 和 3.12 都就位了。
3. `py` 启动器不受影响，你原来的 3.14 用法完全不变。

### ⚠️ 需要注意的四点

**① `python` 命令仍然是坏的（我没修，这是故意的）**

```powershell
python --version     # → "Python was not found..."（还是存根）
py --version         # → Python 3.14.7（正常）
```

我没去改，因为修它要么改系统设置（关应用执行别名），要么调 PATH 顺序，两种都可能影响你其他项目。
**现在的用法**：用 `py`，或者用 3.12 的绝对路径 `E:\tools\pydeps\bili-env\Scripts\python.exe`。

> 想彻底修的话：设置 → 应用 → 高级应用设置 → 应用执行别名 → 关掉 `python.exe` / `python3.exe`。
> 关掉后 `python` 会落到 PATH 第 5 位的 `%USERPROFILE%\AppData\Local\Python\bin`，那就是真的 3.14。

**② 已经在运行的程序看不到新 PATH**

DSH、VSCode、终端，**要重启才会读到新 PATH**。当前进程里我已经手动刷新过，但那只对当前这个进程有效。

**③ ffmpeg 版本偏老**

见 2.2。日常抽帧没问题，遇到新编码会报 "Unknown decoder"。

**④ 磁盘占用约 813 MB**

主要在 `E:\tools\pydeps\bili-env`（404 MB，两个 venv 的依赖）。E 盘还有 375 GB，不紧张。

### 🔒 没有影响的

- 你的 Python 3.14 及其已装包（numpy 2.5.4 / onnxruntime 1.31.1 / python-docx）——一个没动
- `E:\dswechat`、`E:\minimax_music3`、`E:\WiFilocation` 下那几个 venv——一个没动
- 系统 PATH、系统 Python、注册表其他项
- B 站账号（**没有登录任何账号**，抽帧全程匿名）

---

## 五、怎么验证

```powershell
# 1. 工具是否就位（新开一个终端）
ffmpeg -version
ffprobe -version
yt-dlp --version
uv --version

# 2. ASR 环境是否可用
E:\tools\pydeps\bili-env\Scripts\python.exe -c "import faster_whisper, cv2; print('ASR/OCR OK')"

# 3. 抽帧端到端
cd <repo>
.\bili-frame.ps1 -Video BV1HE421j7Lt -At 12:00 -Page 5
```

第 3 条应该输出一张 60 KB 左右的 jpg 和一个 `?p=5&t=720` 的回看链接。

---

## 六、怎么撤销（如果哪天不想要了）

按顺序：

```powershell
# 1. 还原用户 PATH（用备份文件里的原始值）
$orig = Get-Content "E:\tools\PATH-backup-20261113-203510.txt" -Raw
[Environment]::SetEnvironmentVariable('Path', $orig.Trim(), 'User')

# 2. 删掉工具目录（含 venv）
Remove-Item "E:\tools" -Recurse -Force

# 3. 删掉 uv 装的 Python 3.12（可选，不影响你的 3.14）
& "$env:APPDATA\uv\python\..\..\uv.exe" python uninstall 3.12 2>$null
Remove-Item "$env:APPDATA\uv" -Recurse -Force -ErrorAction SilentlyContinue
```

删完重启终端。你的 3.14 和其他项目完全不受影响。

---

## 七、已经踩过并修掉的坑（供参考）

| 坑 | 现象 | 怎么修的 |
|---|---|---|
| gyan.dev 太慢 | 43 KB/s，预计 45 分钟 | 换 npm 的 `@ffmpeg-installer`，20 秒完成 |
| `-File` 传参不拆逗号 | `-At 1:30,5:00` 被当成一个字符串 | 脚本内手动 `-split ','` |
| `$bvid?p=` 被当变量名 | 回看链接变成 `.../video/=5&t=600` | 改用 `${bvid}?p=` |
| PowerShell 把 ffmpeg 的 stderr 当致命错误 | TLS 抖动直接抛异常中断 | `ErrorActionPreference='Continue'` + 显式 `throw` |
| B 站 CDN 偶发 TLS 失败 | `Error in the pull function` | URL 列表轮换（主地址 + backupUrl）+ 重试 |
| 多 P 时间点越界 | 抽帧空文件 | 先读 `pages[].duration` 校验，越界直接给警告 |
| 计数为空 | "成功  个" | `@(...).Count` 强制数组 |

这些都已经写进 `bili-frame.ps1` 了。
