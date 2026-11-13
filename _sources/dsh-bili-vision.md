# bili-vision 0.2

让 DSH 的当前视觉模型直接读取 B 站视频证据：**带实际时间戳的画面、官方字幕或本地转写、画面文字 OCR**。

默认 `inspect` 在本地整理证据并交给当前视觉模型；`run` 可使用独立视觉模型分析，适合主模型不能看图或希望由低成本模型承担视觉工作的场景。两种路线的总成本取决于实际模型与用量，少一次调用不一定更便宜。

## 推荐用法

在 DSH 中直接说：

> 看懂这条视频，说明主线、关键结论和画面中的重要细节：视频链接

工具默认参数相当于：

```json
{"target":"BV1GJ411x7h7","action":"inspect","policy":"auto","maxVision":12,"gridSize":4,"ocr":true}
```

首次先看全片。图表、小字或某个操作不清楚时，只补看对应区间：

```json
{"target":"BV1GJ411x7h7","action":"inspect","start":65,"end":80,"gridSize":1,"maxVision":6,"ask":"这一步点击了什么，界面有什么变化？"}
```

只需要口播摘要时调用 `bili_summary`，或 `bili_vision(action=text)`。这条路径不下载视频、不抽帧、不额外调用模型。

支持完整 BV 号、B 站视频链接、`b23.tv` 短链，以及多分 P 链接中的 `?p=2`。不同分 P 使用独立缓存。

## 安装与升级

需要 Python **3.10+**、`ffmpeg` 和 `ffprobe`；插件入口支持 Node **18+**，实际 Node 版本还必须满足所安装 DSH 的要求。已在 Windows / DSH `0.2.0-rc.2` 验证工具 schema 和图片附件服务；清单声明 `engines.dsh >=0.2.0-rc.2 <0.3.0`，不代表已经测试其中每个宿主版本。

### 标准 DSH bundle 安装

在已安装 DSH 的环境执行（示例为 `web` profile）：

```powershell
dsh plugin --profile web add 'git+https://github.com/icyaaaww/dsh-bili-vision.git#v0.2.0'
```

包名是 `bili-vision`，仓库名是 `dsh-bili-vision`。该包通过 `package.json` 的 `dsh.bundle.patch` 注册 `cordis.patch.yml`，不需要构建步骤。GitHub 发布不等于发布到 npm，暂时不要使用 `npm install bili-vision`。

标准包管理命令只安装插件包，**不会自动安装 Python、Python 依赖或 FFmpeg**。安装前后均可准备独立 Python 环境；下面示例假定 Python 3.10+、FFmpeg/ffprobe 已在 PATH：

```powershell
# 进入源码目录，使用与当前插件版本相同的 requirements.txt
git clone --branch v0.2.0 --depth 1 https://github.com/icyaaaww/dsh-bili-vision.git
cd dsh-bili-vision
python -m venv "$HOME/.dsh/bili-vision-venv"
& "$HOME/.dsh/bili-vision-venv/Scripts/python.exe" -m pip install -r requirements.txt
```

Linux/macOS 对应解释器为 `~/.dsh/bili-vision-venv/bin/python`；这两个平台尚未完成宿主集成验证。使用自定义 `DSH_HOME` 时将上述环境建在该目录下，或设置 `BILI_VISION_PYTHON` 为已有解释器绝对路径。首次 ASR 使用可能需要下载模型，默认 CPU 运行，无须独显。

标准安装的卸载方式：

```powershell
dsh plugin --profile web remove bili-vision
```

桌面版用户请使用桌面插件管理界面或该版本提供的内置命令运行时；npm CLI 不能管理保留的 `desktop` profile。

### Windows 源码安装器（替代方式）

在解压的 Release 源码包或 Git 克隆目录运行。选择一种安装方式即可；标准包管理安装后不要再用源码安装器覆盖其包目录。

```powershell
.\install.ps1 -Profile web
# 或桌面 profile
.\install.ps1 -Profile desktop
# 已有完整依赖时
.\install.ps1 -Profile web -SkipDeps
```

默认把 Python 依赖装进 `.dsh/bili-vision-venv`，不修改 DSH 自带 Python。设置 `BILI_VISION_PYTHON` 可以选择已有解释器。安装器保存实际使用的解释器路径，结构化修改 bundles 并保留 package.json 备份。

安装后重启 DSH。默认 `inspect` 要求当前对话使用支持图片的模型，且宿主加载 `attachments` 服务；不满足时工具会明确报错。`run` 通过独立视觉 API 返回文本，不要求当前对话模型支持图片。

```powershell
.\install.ps1 -Profile web -Uninstall
```

上述 `-Uninstall` 仅用于源码安装器安装的副本。卸载保留视频缓存与独立 Python 环境。

## 如何平衡效果与开销

- **先覆盖，再定向补充。** 本地用 2 fps 灰度帧计算全局与分块变化，候选帧按时间覆盖全片，保留首尾。默认最多 60 张候选帧；最终最多 12 帧，至少约三分之二的名额用于全片覆盖，其余按问题相关性和画面变化选择。
- **长镜头也采样。** 不再让一个 scene 内的全部字幕绑定到同一张图。15 秒为本地候选覆盖目标；长视频受候选上限限制时会扩大间隔，返回实际最大采样间隔。
- **四宫格优先。** 默认每图 4 帧、每格最大宽 480px，便于辨识。局部细看默认单图，最大宽 960px。九宫格可选，但小字更难辨识，不承诺信息无损。
- **只删除完全相同的画面。** 比较解码后的完整 RGB 像素，重复画面只发送一次，并列出其出现时间；没有使用有损的相似度阈值去重。全黑帧在存在其他有效画面时用带时间的文字标记替代，避免浪费图片预算。
- **OCR 真正进入证据。** 默认只对最终选中的画面运行 OCR，识别结果进入带时间的文本，并按图片内容缓存。缺少 OCR 时明确提示。
- **保留文字原意。** 只整理空白，不删“这个、那个、我们”等词，不移除可能有含义的重复。
- **复用本地结果。** 元数据、字幕、ASR、候选帧、OCR、拼图分别缓存。刷新会真正重提取图片；下载完成后才发布缓存文件。同视频的并发写入由进程锁串行化。
- **控制上下文。** 默认文本预算估算为 12000 token。`inspect` 和 `text` 的长文本节选兼顾全片覆盖和问题相关性，明确标注省略数量、提供完整文本路径；可指定时间范围继续读，不能把节选当全文。

普通 `inspect` 不产生独立 API 请求，也不要求 `DEEPSEEK_API_KEY`。图片与文本最终花费由当前 DSH 模型、已有对话长度和实际输出决定。推荐先用 12 帧四宫格，再为关键细节追加 3～6 张单帧。

## 动作与参数

| 动作 | 行为 | 独立 API 调用 |
|---|---|---|
| `inspect`（默认） | 返回原生图片附件与文字证据，供当前 DSH 模型分析 | 0 |
| `text` | 返回字幕或本地转写 | 0 |
| `frames` | 输出本地候选帧位置，跳过语音转写 | 0 |
| `plan` | 使用同样的选帧/OCR/拼图过程，报告预算和证据覆盖 | 0 |
| `run` | 可选独立模型分析，返回答案 | 常规 1 次；长文本需分块 |

`policy=auto` 为全片覆盖加相关帧；`always` 完全按时间覆盖；`text` 跳过视频和全部视觉步骤。

`maxVision` 取 1～36（默认 12），`gridSize` 为 1/4/9，`start/end` 单位秒，`maxTextTokens` 取 2000～64000。每次图片数量还受 DSH 附件服务限制；大多数情况下不需要接近上限。

`refresh=true` 绕过视觉/OCR/答案缓存；CLI `--force-asr` 才强制重新转写。

## 命令行

```powershell
python bv.py inspect BV1GJ411x7h7 --no-ocr
python bv.py plan BV1GJ411x7h7
python bv.py text BV1GJ411x7h7
python bv.py inspect BV1GJ411x7h7 --start 65 --end 80 --grid-size 1 --max-vision 6
python bv.py run BV1GJ411x7h7 --ask "主要内容和关键画面是什么？"
```

`inspect` 输出 JSON，图片以本地路径列出；DSH 入口会把它们保存为宿主原生图片附件。CLI 自身不会调用当前 DSH 对话模型。

独立 `run` 常规只调用一次模型，保留完整预算内文本及所选画面；不再默认先做有损摘要再调用第二次。超过文本预算时，先把**全部**文本分块生成与问题相关的证据笔记，再合并作答；超过 20 个分块会要求缩小时间范围。长文本笔记和相同问题的最终答案都缓存，干跑与真实答案缓存隔离。

设置 `BILI_VISION_DRY_LLM=1` 可验证独立请求组装，返回明确的假响应，不代表视频理解效果。

## 配置

| 环境变量 | 作用 |
|---|---|
| `BILI_VISION_PYTHON` | Python 解释器；安装器会保存实际选择 |
| `BILI_VISION_FFMPEG` / `BILI_VISION_FFPROBE` | 媒体工具路径，默认 PATH / 同目录 |
| `BILI_VISION_CACHE` | 缓存目录，默认 `~/.dsh/bili-vision-cache` |
| `BILI_SESSDATA` | 可选官方字幕登录态，不写入缓存明文、不通过子进程命令行传递 |
| `BILI_VISION_ASR_MODEL` | 默认 `small`；`base` 更快，识别效果通常有取舍 |
| `BILI_VISION_ASR_DEVICE` / `BILI_VISION_ASR_COMPUTE` | 默认 `cpu` / `int8` |
| `BILI_VISION_LANG` | 可选转写语言，不设时自动识别 |
| `HF_ENDPOINT` | 模型下载源，默认 `hf-mirror.com`，可自行更换 |
| `DEEPSEEK_API_KEY` | 仅独立 `run` 需要 |
| `DEEPSEEK_BASE_URL` | 独立 API 地址，默认 `https://api.deepseek.com` |
| `BILI_VISION_MODEL` | 独立模型名称，默认沿用 `deepseek-flash`；应按实际账户支持情况设置 |
| `BILI_VISION_IMAGE_TOKENS` | 预算时每图 token 假设，默认 1024；不是实际计费保证 |
| `BILI_VISION_INPUT_PRICE` / `BILI_VISION_OUTPUT_PRICE` | 可选人民币/百万 token 单价；不设置则只估 token，不编造金额 |

不承诺单图固定 384 token，也不假设两次请求必然命中前缀缓存。`run` 记录实际 API `usage`；图像与当前 DSH 对话的实际费用以供应商账单为准。

## 验证与边界

本地 RapidOCR/ONNX Runtime 不产生 OCR API 费用。独立 `run` 会将选中的画面、字幕/转写与 OCR 发送给配置的 API；`inspect` 将这些证据交给当前 DSH 模型。不要把 API 密钥、B 站登录态、视频缓存或模型权重提交到仓库。

```powershell
python -B -m unittest discover -s tests -p 'test_*.py' -v
node --test tests/plugin.test.mjs tests/host.test.mjs
node smoke.mjs
```

目前有 26 项 Python 测试和 7 项 Node/DSH 测试，包含真实 ffmpeg 合成视频、抽帧刷新、首尾覆盖、OCR 输入、分 P、下载中断、文本语义保留及原生图片输出。另已验证 PowerShell 5.1 安装/卸载、运行中取消，以及公开视频的下载、解码和证据导出。宿主集成检查使用本机实际 `dsh-tools` 校验器和 `LocalAttachmentStore`，不消耗模型 API。

稀疏采样可能漏掉短暂事件，2 fps 的候选分析也不适合逐帧动作判定。画面上的极小文字应指定时间范围单帧复核；若源视频下载分辨率本身不足，可在 CLI 调高 `--height` 和 `--frame-width`，其上限仍取决于可访问的视频流。证据返回真实源分辨率；抽帧使用实际媒体时长处理片尾，并显式转换 JPEG 色彩范围。ASR/OCR 不是可靠的逐字原文。首轮模型权重下载、CPU 转写和视频下载仍可能较慢。

`python bv.py clean` 清理当前 v2 视频缓存，旧版本缓存不会自动删除。插件升级后首次会创建新版缓存。
