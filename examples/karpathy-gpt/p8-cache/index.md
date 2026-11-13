# P8 · State of GPT ｜ BRK216HFS — 全片索引

> **视频**：<https://www.bilibili.com/video/BV1mqrTBvEaf?p=8>
> **时长**：42 分 40 秒（2560 秒）｜ 11 个分P中的第 8 个
> **素材**：本地 ASR 全文（52 KB，带时间码）+ 4 张帧网格（每张 6 格，约 585 token）
> **用途**：预设索引，之后任何追问都能在 1~2 步内定位，不必重新理解整片

---

## 一、全片结构（从帧网格 + ASR 归纳）

| 时间段 | 主题 | 关键帧 | 网格 |
|---|---|---|---|
| 00:00–02:00 | 开场 | — | grid-1 #01 |
| 02:08 | **Data collection**：预训练数据配比（CommonCrawl 67%、C4 15%、GitHub 4.5%…） | 数据集表格 | grid-1 #02 |
| 04:16 | **2 example models**：GPT-3(2020) vs LLaMA(2023) 参数/数据/算力对比 | 双栏表格 | grid-1 #03 |
| 06:24 | **Training**：B=4、T=10 的 token 矩阵，one training batch | 矩阵图 | grid-1 #04 |
| 08:32 | **模型学到了通用表示**：Step1 pretraining → Step2 finetuning | 流程图 | grid-1 #05 |
| 12:48 | **SFT Dataset**：Prompt / Response / Labeling instructions 三栏 | 数据集文档 | grid-2 #02 |
| 14:56 | **RM Training**：奖励模型训练 | 流程图 | grid-2 #03 |
| 17:04 | **GPT Assistant training pipeline**：Pretraining → SFT → RM → RL 四阶段对照表 | 大表格 | grid-2 #04 |
| 19:12 | **Mode collapse**：微调后模型失去熵，只会给"最安全"答案 | 对话示例 | grid-2 #05 |
| 21:20 | **幻觉**：加州人口 vs 阿拉斯加，LLM 生成长文本时的自信错误 | 两栏对比 | grid-2 #06 / grid-3 #01 |
| 25:36 | **Chain of thought**：让模型分步思考 | 论文截图 | grid-3 #03 |
| 29:52 | **Chains / Agents**：AutoGPT、ReAct（Yao et al. 2022） | 两张架构图 | grid-3 #05 |
| 32:00 | **Condition on good performance**：提示技巧 | 列表 | grid-4 #01 |
| 34:08 | **Retrieval-Augmented LLMs（RAG）**：检索增强 | 架构图 | grid-4 #02 |
| 36:16 | **Finetuning**：什么时候该微调、它的局限 | 双栏对照 | grid-4 #03 |
| 38:24 | **Default recommendations**：给实践者的默认建议 | 列表 | grid-4 #04 |
| 40:32 | **Looking forward**：未来方向（多张演进图） | 多图 | grid-4 #05 |

> 时间点为**网格采样时刻**（约 2 分钟粒度），不是精确章节边界。
> 要精确定位就在该时间点附近用 `bili-scan.ps1` 加密扫描。

---

## 二、四个高频问题的快速路径

| 你问 | 查哪里 | 耗时 |
|---|---|---|
| "这段视频讲了什么" | 本文结构表 | 0 步（已在上下文） |
| "RLHF 的具体流程" | ASR 搜 `SFT`/`RM`/`RL`；帧 grid-2 #04 | 1 次搜索 + 0~1 次看图 |
| "为什么微调后模型变笨了" | ASR 搜 `mode collapse`；帧 grid-2 #05 | 1 次搜索 |
| "RAG 怎么做的" | ASR 搜 `retrieval`；帧 grid-4 #02 | 1 次搜索 |

---

## 三、素材清单

```
p8-cache/
├── asr/
│   ├── BV1mqrTBvEaf_P8_0s-2560s.md      52.2 KB  全文带时间码
│   └── BV1mqrTBvEaf_P8_0s-2560s.json    101.4 KB 结构化（from/to/text）
├── grid-1/grid.jpg  1224x450  585 token  0:00-10:40  6 格
├── grid-2/grid.jpg  1224x450  585 token  10:40-21:20 6 格
├── grid-3/grid.jpg  1224x450  585 token  21:20-32:00 6 格
├── grid-4/grid.jpg  1224x450  585 token  32:00-42:40 5 格
├── grid-N/frames/    每个采样点的 1080P 原图（可精读）
├── grid-N/manifest.json  格子号 → 时间点 → 原图路径
└── index.md（本文件）
```

---

## 四、建立这份索引的成本

| 环节 | 耗时 | 成本 |
|---|---|---|
| ASR 全片转写（本地 faster-whisper） | 229 秒 | **0 元**（CPU，无 API 调用） |
| 抽 23 帧 + 4 张网格（ffmpeg） | 约 90 秒 | **0 元** |
| 读 4 张网格 + 归纳结构 | 约 30 秒 | 2340 token 输入 + ~1500 输出 ≈ **0.006 元** |
| **合计（一次性）** | **约 6 分钟** | **< 1 分钱** |

之后每次追问的边际成本见 [成本测算](cost-analysis.md)。
