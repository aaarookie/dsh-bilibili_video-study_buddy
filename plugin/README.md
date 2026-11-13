# dsh-study-buddy · B 站网课伴学（插件）

> 本仓库：<https://github.com/aaarookie/dsh-bilibili_video-study_buddy>
> 插件包目录：`plugin/`

> 让 AI 在**正确的时间点**看**正确的画面**，然后把一节课变成可核查的图文笔记。

一个 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 插件 + 一套实测出来的方法论。

---

## 核心判断：三个反直觉结论

这个项目不是“把视频喂给模型”再做一遍，而是三条实测推翻了直觉：

### ① 模型不该看整段视频，只该看正确的几帧

一节 30 分钟的课，真正有信息的画面可能只有 20 帧。
按时间点抽一帧、裁剪、交给模型看，比“视频理解”便宜一到两个数量级。

### ② 拼图不是用来读的，是用来定位的

6 张 1080P 单帧约 5,850 token；6 格拼一张约 600 token——**省 89%**。
但每格只有 400px 宽，读不清代码。所以拼图只回答“哪一段值得细看”。

### ③ B 站的 AI 字幕会串台，必须校验

实测一门讲 GPT 的课，字幕接口返回过：

```
[0.0s] 核能一种很硬核的能源
[2.4s] 比如说一克浓缩铀
```

以及一段英文歌词。**内容与视频完全无关**。直接拿去写笔记，会把核能写进 GPT 笔记里。

---

## 四个工具

| 工具 | 做什么 | 依据 |
|---|---|---|
| `study_frame` | 按时间点抽帧 + 回看链接 | 登录态 1080P、裁剪、放大、缓存 |
| `study_scan` | 区间抽 N 帧拼一张网格 | 定位用，省 89% token |
| `study_subs` | 字幕 + **串台检测** | 覆盖度 / 术语命中 / 语速三信号 |
| `study_asr` | 局部转写，自带前后文 | 前 60s 铺垫 + 后 30s 延续 |

## 安装

```bash
dsh plugin --profile web add dsh-study-buddy
```

或在 DSH 的 **设置 → 插件 → 添加插件** 填包名，装完重启一次。

### 依赖

| 依赖 | 必需 | 说明 |
|---|---|---|
| Node ≥ 20 | ✅ | 插件本体，纯 Node 实现，不依赖 PowerShell |
| `ffmpeg` | ✅ | 抽帧/拼图；放 PATH 或配置绝对路径 |
| B 站登录态 | 可选 | 有登录才能 1080P + AI 字幕 |
| `faster-whisper` | 仅 ASR | Python 3.10–3.14 + 模型 |

登录态与 [`dsh-bili-watch`](https://github.com/Sacredbluedragon/dsh-bili-watch) 共用 `~/.dsh/bili-watch/credential.json`。

## 用法

```
你：讲一下 BV1mqrTBvEaf 的 P8 里 RL Training 那段
```

模型会自己：

1. `study_subs` 先探字幕 → 判定串台（这个视频确实串了）
2. `study_scan -from 14:00 -to 18:00` → 拼图定位到 16:20 那张幻灯片
3. `study_frame -at 16:20 -crop "0,0,0,190"` → 抽高清帧
4. `study_asr -at 16:20` → 带前后文的老师原话
5. 看图 + 对原话 → 讲解

## 实测数据

| 项 | 结果 |
|---|---|
| 1080P 裁剪帧 | 1234×800，约 975 token（比整帧省 45%） |
| 6 格拼图 | 1224×450，约 585 token（比逐张省 93%） |
| 90 秒局部转写 | 8.8 秒（faster-whisper small, CPU） |
| 42 分钟全片转写 | 229 秒 |
| 抽帧缓存命中 | < 1 秒（首次 13 秒） |
| 理解一节 30 分钟课 | **约 3 分钱**（DeepSeek 空闲时段） |

## 限制（都是从坑里爬出来的）

- **时间点属于某个分 P**，不是整条视频。多 P 必须给对 `page`。
- **匿名最高 640×480**，1080P 需要登录。
- **ASR 会听错代码术语**：`free(p)` → “4AP”、`栈上` → “站上”。代码以画面为准。
- **拼图看不清代码**，只够定位。
- **只读**：不点赞、不评论、不投币。

## 仓库结构

```
.
├── plugin/             插件包（可独立 npm 发布）
│   ├── index.js        四个工具的实现
│   ├── lib/asr.py      faster-whisper helper
│   ├── locale/         中英文界面文案
│   └── docs/DETAIL.md  插件详情页
├── docs/               方法论（调研、选型、工作流、环境、实测）
├── examples/           真实笔记产物（Karpathy GPT 课、C 语言课）
└── scripts/            独立 PowerShell 工具（插件外的可选项）
```

## 许可证

MIT
