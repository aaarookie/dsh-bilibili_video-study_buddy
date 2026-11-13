# 04 · 安装配置与避坑

> 面向本机现状写的：Windows、DSH `0.2.2-rc.1`、profile `web`、无 Python、无 ffmpeg。
> 每一步都标了"为什么"和"失败了怎么办"。

---

## 一、先搞清楚三件事

### 1.1 你的 `dsh` 命令在哪

本机的 `dsh` **不在 PATH 里**，它是从源码 checkout 直接跑的：

```powershell
# 等价于 dsh 的完整调用
node E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js --version
# → 0.2.2-rc.1
```

所以本文所有 `dsh plugin ...` 命令，在本机都要写成：

```powershell
$dsh = "E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js"
node $dsh plugin --profile web add dsh-bili-watch
```

（想省事就把 `$dsh` 设成环境变量，或者用 [install.ps1](install.ps1) 里的封装。）

### 1.2 你的 profile 是 `web`

```powershell
node $dsh plugin --profile web add <包名>
```

`--profile` 写错是最常见的"装了但没反应"原因。桌面版用户通常叫 `desktop`，
本机是 Web 版，用 **`web`**。

### 1.3 装完必须重启

DSH 的插件在 bundle 层组装，**不重启不加载**。而且它缓存插件模块，
`remove` + 重装也不热重载。重启方式：

- 关掉当前 DSH Web 进程（任务管理器里那个 `bin.js web --no-open`），重新启动；
- 或者用你平时启动 DSH 的快捷方式重开。

> ⚠️ 重启会中断当前会话（对话记录不丢，但正在跑的任务会断）。挑个空闲时候做。

---

## 二、装依赖（按需要，不必全装）

### 2.1 ffmpeg —— 只有"看画面"才需要

**路线一（推荐）：让插件自己装**

装好 `dsh-bili-watch` 后，进「插件 → dsh-bili-watch → 依赖状态」，
ffmpeg 那一行点末尾的下载按钮，走它内置的 `fetch-deps`（支持国内镜像）。
`dsh-bili-eyes` 的设置页也有「下载 ffmpeg」按钮。

- ✅ 优点：版本对、路径自动配好、不用管 PATH
- ⚠️ 注意：**下载期间 DSH 不能关**，宿主退出会连下载进程一起杀；中断了重进面板再点一次，已下完的会跳过

**路线二：winget 装（本机 winget 可用，v1.29.380）**

```powershell
winget install --id Gyan.FFmpeg -e --accept-source-agreements
```

装完**新开一个终端**验证（PATH 要刷新）：

```powershell
ffmpeg -version | Select-Object -First 1
```

**路线三：便携版（不想动系统）**

从 gyan.dev 下 `ffmpeg-release-essentials.zip`，解压到比如 `D:\tools\ffmpeg`，
然后把 `D:\tools\ffmpeg\bin` 加进用户 PATH；或者干脆在插件面板里指定
`BILI_WATCH_FFMPEG` 环境变量指向 `ffmpeg.exe`。

> 判断标准：`ffmpeg -version` 和 `ffprobe -version` **两个**都要能跑（有些包只带 ffmpeg）。

### 2.2 Python —— 只有本地 ASR / OCR 才需要

**⚠️ 本机最大的坑：`python` 命令存在，但它是个假的。**

```
> python --version
Python was not found; run without arguments to install from the Microsoft Store...
```

那是 Windows 的「应用执行别名」占位符。装了插件后如果它检测到"Python 可用"但一跑就崩，
八成就是这个。

**正确装法：**

```powershell
winget install --id Python.Python.3.12 -e
```

然后**必须**做这一步：打开「设置 → 应用 → 高级应用设置 → 应用执行别名」，
把 `python.exe` 和 `python3.exe` 两个开关**关掉**，再新开终端验证：

```powershell
python --version    # 期望：Python 3.12.x
py --version        # 也可以用 py 启动器
```

**替代方案：装 `uv`（更省事）**

```powershell
winget install --id astral-sh.uv -e
uv --version
```

`uv` 能自己拉 Python、建 venv、装 wheel，很多插件优先用它。
`dsh-bili-subagent`、`dsh-bili-video` 在检测不到 Python 时会尝试自己下一份 uv。

> Python 版本范围：`dsh-bili-watch` 要求 3.10~3.14；`dsh-bili-vision` 要求 3.10+。**3.12 最稳**。

### 2.3 yt-dlp —— 只影响"非 B 站链接"

```powershell
winget install --id yt-dlp.yt-dlp -e
```

纯 B 站场景可以不装。

### 2.4 VC++ 运行库 —— ASR/OCR 的隐藏依赖

`faster-whisper` / `onnxruntime` 是 C++ 编译的 wheel，运行时要 `vcruntime140.dll`。
Win10/11 一般自带，但精简版镜像会缺，症状是 **pip 装得上、import 时报 `DLL load failed`**。

修复（与 Python 版本无关，不用重装 venv）：
<https://aka.ms/vs/17/release/vc_redist.x64.exe>

---

## 三、按方案装插件

> 下面两条路等价，任选：**GUI**（设置 → 插件 → 添加插件，填包名）或 **CLI**。
> GUI 更适合日常；CLI 适合批量、可复制。

### 方案 A：零依赖起步

```powershell
$dsh = "E:\deepseekharness\deepseek-harness\apps\cli\lib\bin.js"
node $dsh plugin --profile web add dsh-bili-study
```

- 包名：`dsh-bili-study`（npm v1.0.0，月下载 404）
- 声明要求：`dsh >=0.2.1-rc.5 <0.3.0` → 本机 0.2.2-rc.1 ✅
- 装完重启，侧栏出现「B 站学习台」

### 方案 B：主力组合（推荐）

```powershell
node $dsh plugin --profile web add dsh-bili-watch
node $dsh plugin --profile web add dsh-bili-study
```

- `dsh-bili-watch` v0.4.10，要求 Node ≥ 22（本机 v24 ✅）
- 两者功能不重叠，可共存
- 装完重启 → 设置里出现「bili-watch」面板

> 如果你只想要"链接进、总结出"的最小闭环，可以再加 `dsh-bili-summary`
> （纯 Node，未上 npm，只能 `add github:YZz-S/dsh-bili-summary`），
> 但它没实现 WBI 签名，B 站接口一收紧就失效，**不如 dsh-bili-watch 稳**。

### 方案 C：全功能（先补 Python + ffmpeg）

```powershell
# 视觉/互动向（二选一，别都装，功能重叠）
node $dsh plugin --profile web add dsh-bili-eyes
# 或
node $dsh plugin --profile web add github:13520rygvv/dsh-bili-video

# 复习向（和上面互补）
node $dsh plugin --profile web add "@ericwang1358/dsh-daily-flashcard"
# 即 dsh-web-studyhub 的 npm 包名
```

- `dsh-bili-eyes`：npm 0.8.3，Node ≥ 20，ffmpeg 可面板一键下
- `dsh-bili-video`：GitHub only，**Python + ffmpeg 硬依赖**，装完要扫码登录
- `dsh-bili-vision`：GitHub only，Python + ffmpeg + ffprobe，且 `inspect` 要当前模型能看图
  ```
  node $dsh plugin --profile web add "git+https://github.com/icyaaaww/dsh-bili-vision.git#v0.2.0"
  ```

### 不要装的东西

| 包 | 原因 |
|---|---|
| `dsh-bili-scroll` / `dsh-bili-whale` / `dsh-bili-pond` / `dsh-fish` | 自动刷站 + 往你号上发评论，学习用不上，还有账号风险 |
| `dsh-bili-live` / `dsh-bili-danmaku-lite` | 直播 |
| `dsh-video-coursemap` | 依赖字幕覆盖率，多数视频无字幕 → 生成空手册 |
| `dsh-video-understand` | 需 ffmpeg + MiMo API key，且语义层 2 GB，性价比对本机不高 |

---

## 四、B 站登录（要用 AI 字幕才需要）

### 方式一：扫码（推荐）

`dsh-bili-watch` 装好后，面板里点「去扫码登录」，二维码直接在面板里出，手机 B 站扫完自动刷新。
凭证落在 `~/.dsh/bili-watch/credential.json`。

> 扫码时确认页选「**记住我 / 长期**」，选 24 小时的话第二天就得重扫。

### 方式二：手动填 SESSDATA

从浏览器 Cookie 里取 `SESSDATA`、`bili_jct`，拼成：

```json
{"sessdata":"...","bili_jct":"...","buvid3":"...","buvid4":"..."}
```

### 安全须知（务必看）

- **用小号**。凭证等同于账号密码，拿到就能以你的身份操作。
- 凭证文件**不要**提交到 git、不要截图发人、不要同步到云盘。
- 这些插件的写操作（点赞/评论/三连）默认全关，**学习场景不要打开**。
- B 站对异常请求会返回 `-412` 风控，也可能要求验证码；遇到就停一段时间。

---

## 五、装完怎么验证

### 5.1 工具是否挂载

**新开一个会话**（重要：旧会话的工具列表不会刷新），问：

```
你现在有哪些和 bilibili 或视频相关的工具？列出工具名和一句话用途。
```

期望看到 `bili_watch`（或你装的其他插件的工具名）。

### 5.2 冒烟测试

```
用 bili_watch 的 view 看一下 BV1GJ411x7h7，告诉我标题、UP 主、播放量。
```

`view` 是纯 HTTP，**不需要 ffmpeg、不需要登录**，最适合验证链路通不通。

### 5.3 面板检查

「设置 → 插件 → dsh-bili-watch」里，依赖状态应该逐项列出：
ffmpeg / yt-dlp / ASR 环境 / OCR 环境 / 转写模型 / 登录凭证，各自是否就绪、路径、体积。

> 面板里还有一个「排查提示词」按钮：一键复制一段诊断指令，粘给 DSH，它会只读排查并出报告。

---

## 六、错误速查

| 现象 | 原因 | 解决 |
|---|---|---|
| 装完重启，什么都没有 | 插件在 bundle 层，需要重启；或 `--profile` 写错 | 确认 `--profile web`；彻底关掉进程重启 |
| 插件页显示"已启用"但工具不可用 | 老版本的 `disabled: true` 残留（`dsh-bili-watch` 0.3.1 及更早的已知 bug） | 升到 0.3.2+，重跑一次 `add` |
| 装了跟没装一样，也不报错 | DSH 版本不满足，内核**静默跳过** | 比对插件 `engines.dsh`；本机 0.2.2-rc.1 已满足主流插件 |
| 启动崩溃，报 `import failed` | `client.js` 里 `load({id})` 与 `package.json` 的 `name` 不一致 | 联系插件作者；或先禁用该插件 |
| 启动崩溃，报 `Unexpected token ''` / `is not valid JSON` | profile 的 `package.json` 存成了 **UTF-8 带 BOM** | 用 `UTF8Encoding($false)` 重写；详见下方 |
| `python` 检测通过但一跑就崩 | Windows 应用执行别名存根 | 关掉别名，或在插件里指定真解释器路径 |
| ASR 报 `DLL load failed` | 缺 VC++ 运行库 | 装 vc_redist.x64 |
| 取字幕返回"无字幕轨" | 没登录，或视频真没字幕 | 扫码登录；否则走 ASR |
| 返回 `-412` | 触发风控 | 降低频率，等一段时间，换小号 |
| 抽帧/九宫格报 ffmpeg 不存在 | 没装或不在 PATH | 面板一键装，或设 `BILI_WATCH_FFMPEG` |
| 下载依赖下载到一半失败 | 宿主退出杀了下载进程 | 重进面板再点，已完成的会跳过 |
| sharp 安装要编译 | node-gyp 在 Windows 缺构建工具 | 装 `dsh-bili-summary` 时才会遇到；不给编译权限就降级为"仅封面" |

**BOM 修复**（会崩在 `readProfileManifest` 的那种）：

```powershell
$p = "$env:USERPROFILE\.dsh\profiles\web\package.json"
$txt = [System.IO.File]::ReadAllText($p)
[System.IO.File]::WriteAllText($p, $txt, (New-Object System.Text.UTF8Encoding($false)))
```

> ⚠️ 手动改 profile 里的文件，一律 **UTF-8 无 BOM**。别用 `Set-Content -Encoding UTF8`
> 或 `Out-File -Encoding utf8`（Windows PowerShell 的这两个默认带 BOM）。

---

## 七、卸载与回滚

```powershell
# 卸载单个
node $dsh plugin --profile web remove dsh-bili-watch

# 看装了什么（pnpm list 在非 TTY 下可能输出为空，此时看 package.json 更可靠）
Get-Content "$env:USERPROFILE\.dsh\profiles\web\package.json" -Raw |
  ConvertFrom-Json | Select-Object -ExpandProperty dependencies
```

- 卸载**不会**删数据：`~/.dsh/bili-watch/`（缓存、凭证、配置）、
  `~/.dsh/bili-study/state.json` 都还在。重装后自动接上。
- 如果插件导致 DSH 起不来：DSH 的崩溃弹窗有
  **「Disable third-party plugins, back up profile patch, and restart」**，先起来再定位。
- 极端情况可手动编辑 `~/.dsh/profiles/web/cordis.patch.yml`，把那行 `disabled: true` 加上。

---

## 八、一键脚本

本目录下的 [install.ps1](install.ps1) 把上面的步骤封装了：

```powershell
# 只看要做什么，不动手
.\install.ps1 -Plan B -WhatIf

# 装方案 B（会依次检查环境 → 装插件 → 提示重启）
.\install.ps1 -Plan B

# 连 ffmpeg 一起用 winget 装
.\install.ps1 -Plan B -WithFFmpeg

# 检查环境，不装任何东西
.\install.ps1 -Check
```

脚本只做四件事：**探测环境 → 打印计划 → 执行你选的步骤 → 给出重启提示**。
不会动你的 B 站账号，不会开写操作，不会改 profile 里已有的插件行。

---

## 九、安装后建议的收尾配置

1. **关掉所有写操作**：点赞/评论/三连/私信，学习场景一律关闭（默认就是关的，别去开）。
2. **限制自动刷**：如果你装了带自动刷的插件（不建议），把"每天轮数"设成 0。
3. **缓存上限**：`dsh-bili-watch` 默认保留 7 天 / 2048 MB，按磁盘情况调。
4. **给模型加一条常驻指令**（写进 `~/.dsh/AGENTS.md` 或项目 AGENTS.md）：

```markdown
## B站学习约定
- 处理 B 站视频时优先用 bili_watch 工具，不要凭标题猜内容。
- 引用课程原话前，若 ASR 标记为「疑似幻觉」，先说明不确定性。
- 长字幕超过 800 字会落盘，请用 read 分段读，不要要求一次性全文。
- 总结必须带 [mm:ss] 时间码，方便我回看。
```

这条比任何插件设置都管用——它让模型每次都知道该调什么工具、该怎么输出。
