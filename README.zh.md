# dsh-bilibili_video-study_buddy · B 站网课伴学

[![npm](https://img.shields.io/npm/v/dsh-study-buddy.svg)](https://www.npmjs.com/package/dsh-study-buddy) [![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)


> 让 AI 在**正确的时间点**看**正确的画面**，把一节课变成可核查的图文笔记。
>
> 仓库：<https://github.com/aaarookie/dsh-bilibili_video-study_buddy> ｜ 插件包：`plugin/`（npm 名 `dsh-study-buddy`）

一个 [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) 插件 + 一套实测出来的方法论 + 若干真实笔记样例。

---

## 这个仓库是什么

| 目录 | 内容 |
|---|---|
| [`plugin/`](plugin/) | **DSH 插件包**，可独立安装/发布。四个工具：`study_frame` / `study_scan` / `study_subs` / `study_asr` |
| [`docs/`](docs/) | 方法论：社区调研、插件选型、工作流、环境配置、实测记录 |
| [`examples/`](examples/) | 真实产物：Karpathy GPT 课的精讲笔记（Markdown + Word）、ASR 转写、帧网格 |
| `scripts/` | 插件外的独立 PowerShell 工具（可选，Windows） |

## 核心判断：三个被实测推翻的直觉

### ① 模型不该看整段视频，只该看正确的几帧

一节 30 分钟的课，有信息的画面可能只有 20 帧。按时间点抽帧、裁剪、交给模型看，
比"视频理解"便宜一到两个数量级。

### ② 拼图不是用来读的，是用来定位的

| 方式 | 尺寸 | 估算 token |
|---|---|---|
| 6 张 1080P 单帧 | — | ~5,850 |
| 6 格拼图（每格 400px） | 1224×450 | **~585（省 90%）** |

但每格只有 400px 宽，读不清代码。所以拼图只回答"哪一段值得细看"。

### ③ B 站的 AI 字幕会串台，必须校验

实测一门讲 GPT 的课，字幕接口返回过：

```
[0.0s] 核能一种很硬核的能源
[2.4s] 比如说一克浓缩铀
```

以及一段英文歌词——**与视频完全无关**。直接拿去写笔记会把核能写进 GPT 笔记里。
所以 `study_subs` 用覆盖度 / 标题术语命中 / 语速三个信号判定 PASS/WARN/FAIL，
FAIL 时拒绝输出正文。

## 快速开始

```bash
# 安装插件
dsh plugin --profile web add dsh-study-buddy

# 或者在 DSH：设置 → 插件 → 添加插件 → 填 dsh-study-buddy
```

依赖：Node ≥ 20、`ffmpeg`（必需）；B 站登录态（可选，用于 1080P + AI 字幕）；
`faster-whisper`（仅 `study_asr`）。

## 用法

```
你：讲一下 BV1mqrTBvEaf 的 P8 里 RL Training 那段
```

模型会自己：

1. `study_subs` 探字幕 → 判定串台（这个视频确实串了）
2. `study_scan -from 14:00 -to 18:00` → 拼图定位到 16:20 的幻灯片
3. `study_frame -at 16:20 -crop "0,0,0,190"` → 抽高清帧
4. `study_asr -at 16:20` → 带前后文的老师原话
5. 看图 + 对原话 → 讲解，并落成带时间点的笔记 → 转 Word

## 实测数据

| 项 | 结果 |
|---|---|
| 1080P 裁剪帧 | 1234×800，约 975 token（比整帧省 45%） |
| 6 格拼图 | 1224×450，约 585 token（比逐张省 93%） |
| 90 秒局部转写 | 8.8 秒（faster-whisper small, CPU） |
| 42 分钟全片转写 | 229 秒 |
| 抽帧缓存命中 | < 1 秒（首次 13 秒） |
| 理解一节 30 分钟课 | **约 3 分钱**（DeepSeek 空闲时段） |

成本口径见 [`examples/karpathy-gpt/p8-cache/cost-analysis.md`](examples/karpathy-gpt/p8-cache/cost-analysis.md)。

## 限制（都是从坑里爬出来的）

- **时间点属于某个分 P**，不是整条视频。多 P 必须给对 `page`，否则抽到空文件。
- **匿名最高 640×480**，1080P 需要登录 B 站。
- **ASR 会系统性听错代码术语**：`free(p)` → “4AP”、`栈上` → “站上”。代码一律以画面为准。
- **拼图看不清代码**，只够定位。
- **只读**：不点赞、不评论、不投币。

## 许可证

MIT
