# 01 · 社区生态调研：DSH 的 B 站插件地图

> 数据抓取于 2026-11-13。原始索引已备份到 [_sources/awesome-dsh-plugins.json](_sources/awesome-dsh-plugins.json)（13.5 MB）。
> Star / 下载量为索引快照值，会随时间变化；下载量比 star 更能反映真实使用。

---

## 一、调研方法与口径

三个数据源：

| 来源 | 用途 | 局限 |
|---|---|---|
| `awesome-dsh-plugin.com/plugins.json` | 全量插件清单（**10,778 条**），含 stars / 月下载 / 版本 / 能力声明 | 索引每日 10:23 刷新一次，收录有延迟；部分 GitHub 项目未收录 |
| GitHub Search API | 发现索引外的仓库（`dsh-bili-*` 等 204 个结果） | star 可刷，不能单独作为质量依据 |
| npm registry + downloads API | 核实包是否真发布、版本、engines、真实月下载 | 仅覆盖已发布到 npm 的项目 |

**三个统计口径，别混用：**

| 口径 | 数量 | 含义 |
|---|---|---|
| 名字里带 `bili` | **48** | 明确的 B 站插件 |
| 名字或描述提及 B 站 / bilibili | **102** | 含"顺便支持 B 站"的通用插件 |
| 全量插件 | 10,778 | 整个 DSH 生态 |

> ⚠️ 网上有说法把"B站相关"算到 500+，那是把描述里出现过"视频/B站"字样的通用插件也算进去了。
> 本报告采用 **102** 这个更严格的口径。

---

## 二、按玩法分类：B 站插件其实分七派

| 派别 | 数量 | 代表项目 | 和学习的关系 |
|---|---|---|---|
| **字幕 / 转写** | 26 | `dsh-bili-watch`、`dsh-bili-summary` | ⭐⭐⭐ 核心：把课变成文字 |
| **互动 / 社交** | 21 | `dsh-bili-subagent`、`dsh-bili-eyes` | ⭐ 学习场景基本用不上（点赞/评论/私信） |
| **宠物 / 人设** | 20 | `dsh-bili-whale`、`dsh-bili-pond`、`dsh-fish` | ✗ 娱乐向，"养鱼"文化产物 |
| **视频理解 / 看画面** | 17 | `dsh-bili-eyes`、`dsh-bili-vision`、`dsh-video-storyboard` | ⭐⭐ 板书/PPT 场景有用，但依赖视觉模型 |
| **自动刷 / 推荐** | 15 | `dsh-bili-scroll`、`dsh-bili-jar` | ✗ 帮你"发现内容"，不帮你"学会内容" |
| **学习管理** | 14 | `dsh-bili-study`、`dsh-video-coursemap`、`dsh-web-studyhub` | ⭐⭐⭐ 核心：笔记、目录、复习 |
| **直播** | 6 | `dsh-bili-live`、`dsh-bili-danmaku-lite` | ✗ 与网课无关 |

> 一个插件可能同时命中多类（例如 `dsh-bili-eyes` 既算"看画面"也算"互动"），所以七类相加（119）大于总数（102）。

**关键观察**：下载量最大的那一派（自动刷站，`dsh-bili-scroll` 月下载 7.3 万）恰恰**和学习无关**——
它是"让 AI 替你刷 B 站然后写日报"。真正服务学习的插件，下载量普遍在几千到几百量级，属于**小众但精准**。

---

## 三、真实热度榜（按 npm 月下载，2026-11-13）

| 插件 | Stars | 月下载 | 定位 | 和学习相关？ |
|---|---:|---:|---|---|
| `dsh-bili-scroll` | 1,381 | **73,647** | 自己刷 B 站、读字幕挑内容、写日报 @ 你 | ✗ |
| `dsh-video-storyboard` | 530 | 33,475 | 视频 → 宫格图 + 时间码 + 台词（**底层能力**） | ⭐⭐ 被多个插件复用 |
| `dsh-bili-watch` | 16 | **16,154** | 结构化内容：元数据/评论/弹幕/字幕/ASR/抽帧OCR | ⭐⭐⭐ |
| `dsh-bili-subagent` | 109 | 9,683 | 派子代理刷站、带笔记与卡片墙 | ⭐⭐ 附带逐条笔记 |
| `dsh-bili-pond` | 29 | 6,216 | 肥鱼替你刷、私信你 | ✗ |
| `dsh-video-understand` | 15 | 5,125 | 低成本信息层（ASR+场景+轨迹）→ 摘要问答 | ⭐⭐ |
| `dsh-bilibili-video-summary` | 2 | 4,037 | yt-dlp 下载 + 抽帧 + 转写 | ⭐⭐ |
| `dsh-bili-jar` | 11 | 3,620 | 右下角罐子，按兴趣搜片 | ✗ |
| `dsh-bili-eyes` | 6 | 3,742 | 分镜图 + 台词 + 热评 + 逛站 + 互动 | ⭐⭐ |
| `dsh-bili-study` | 0 | 404 | **B 站学习台**：科目→章→主题、笔记、知识图谱 | ⭐⭐⭐ |
| `dsh-video-coursemap` | 21 | — | 自动检测前台视频 → 学科分类 → Word 知识地图 | ⭐⭐⭐ |
| `dsh-web-studyhub` | 186 | 1,946 | 资料/录音 → 闪卡 + 测验 + FSRS-6 复习 | ⭐⭐⭐ |

> 注意：**star 数和下载量严重背离**。`dsh-bili-watch` 只有 16 star 却有 1.6 万月下载，
> `dsh-bili-scroll` 1,381 star。前者是"工具"，后者是"玩具+社交货币"。选型看下载和 README 质量，别只看 star。

---

## 四、上游依赖链：整张地图其实是三棵树的枝叶

这是理解这个生态最重要的一件事——**大部分插件不是从零写的，而是同几个底座的封装**。

```
adoresever/bilibili-mcp（Python MCP，搜索/字幕/评论/发评论）
        │
        ├── c1overzz/dsh-bili-scroll ──┬── Yuuyuko-uu/dsh-bili-subagent
        │                              ├── 13520rygvv/dsh-bili-video（+ storyboard）
        │                              ├── QiuYeDx/dsh-bili-eyes（+ storyboard）
        │                              └── Alterssss/dsh-bili-whale / dsh-bili-pond / dsh-fish …
        │
SAOS-3624/dsh-video-storyboard（宫格分镜、时间码、音频包络）
        │
        ├── QiuYeDx/dsh-bili-eyes
        ├── 13520rygvv/dsh-bili-video
        └── icyaaaww/dsh-bili-vision（自带 Python 引擎）

独立实现（不走上面两条链）：
  Sacredbluedragon/dsh-bili-watch（自研 CLI + 本地 ASR/OCR，MIT）
  YZz-S/dsh-bili-summary（纯 Node + sharp）
  ilps2/dsh-video-understand（自研 Python 引擎 AVIS）
  linner1224/dsh-video-coursemap（纯 Node，无视频流）
  ijerrywong/bili-study-plugin（纯 JS，不下载视频）
```

**实践含义：**
1. 装了 `dsh-bili-eyes` 就等于间接装了 `bilibili-mcp` + `storyboard` 那一套；再装 `dsh-bili-subagent` 会功能重叠。
2. 上游作者的 bug 会传导到所有下游，反之上游修了你也得等下游更新。
3. 选"独立实现"往往意味着更少的历史包袱，但也意味着作者一个人扛全部维护。

---

## 五、学习类插件专项（和"看网课"直接相关）

### 5.1 `dsh-bili-study` — B 站学习台（npm，v1.0.0）
- **定位**：学习**管理**，不是视频理解。不下载视频、不登录、不碰视频流，播放用 B 站官方嵌入播放器。
- **能力**：UP 主页/收藏夹/单链接 → 「科目 → 章 → 主题」目录；Markdown + KaTeX 笔记；概念速查；知识图谱；AI 前置连线（主题先修关系）；智能分类。
- **数据**：全在本机 `~/.dsh/bili-study/state.json`。
- **短板**：AI 看不到视频内容，只能基于**标题**做分类和概念解释。它不会告诉你"第 12 分钟讲了什么"。
- 仓库：<https://github.com/ijerrywong/bili-study-plugin>

### 5.2 `dsh-video-coursemap` — 视频课程知识地图 2.0
- **定位**：全自动。定时（15s）读 **Windows 前台窗口标题** → 判断是不是课程视频 → 自动抓 B站 字幕/弹幕/热评 → 提炼知识点 + Mermaid 思维导图 → 输出 Word《学习手册》。
- **亮点**：**零运行时依赖**（纯 Node），按学科自动分文件夹，老学科追加更新。
- **硬伤**：README 自己承认"多数 B 站视频无机器字幕"，没字幕时只能降级为"仅标题总结"——那就没什么价值了。Word 输出需要 Python。
- 仓库：<https://github.com/linner1224/dsh-video-coursemap>

### 5.3 `dsh-web-studyhub` — 学习工作台（v4.5.1）
- **定位**：**复习**，不是看视频。导入 PDF/DOCX/PPTX/Markdown 和课堂录音 → 带出处引用的闪卡、测验、开放题 → **FSRS-6 间隔复习**。
- **价值**：和 B 站插件是**互补关系**——B 站插件负责"把课变成笔记"，它负责"把笔记变成记牢"。
- npm：`@ericwang1358/dsh-daily-flashcard`

### 5.4 其他值得知道的学习类
| 插件 | Stars | 一句话 |
|---|---:|---|
| `Study-Mate` | 1,437 | AI 学习搭档：定计划、讲知识、做项目。**不碰 B 站**，纯学习方法论 |
| `dsh-knowledge-studio`（EduWork） | 351 | 基于工作区资料做报告/PPT/思维导图/测验/闪卡，需 Python 3.12 + Chromium |
| `deep-read-summarize` | 45 | 书籍/论文/**视频**/网页 → 结构化 Obsidian 笔记，MapReduce 并行精读 |
| `dsh-bili-subagent` | 109 | 虽主打刷站，但报告中带**每条视频的笔记和卡片墙**，可当"批量预习"用 |

---

## 六、非 DSH 生态对照（如果你想知道"别人怎么做的"）

| 项目 | 形态 | 特点 | 为什么不如 DSH 插件适合你 |
|---|---|---|---|
| `bilibili-video-mcp`（yzfly） | Python MCP Server | you-get 下载 + 弹幕字幕 + ASR + 硅基流动 | 需自己配 Claude Desktop/客户端，没有 DSH 的工具挂载与设置页 |
| `@xzxzzx/bilibili-mcp` | npm MCP | 功能全（搜索/字幕/评论/登录） | 同上，且要在各客户端重复配置 |
| `BiliNote`（多实现） | Chrome 扩展 / CLI / Go | 字幕总结、随看随问、同步 Notion、截图入笔记 | 绑定浏览器场景，笔记在扩展里，DSH 读不到 |
| `Bilibili Subtitle to AI` | Chrome 扩展 | 字幕/音频发 ChatGPT 或 AI Studio | 数据出本机，且只能在浏览器里用 |
| `BibiGPT` skill | Agent Skill | YouTube/B站/播客摘要、章节、导出笔记 | 依赖其云服务与账号 |
| `OpenBiliClaw` | 跨平台 Agent（3,750★） | 内容发现，支持 DSH 插件形态 | 定位是"发现内容"，不是"学会内容" |

**结论**：DSH 插件的不可替代性在于——**工具直接进对话上下文**，模型能自己决定"先读字幕、再翻评论、再抽三帧看看板书"，而且数据留在本机。

---

## 七、生态观察与风险提示

**成熟度**：这个生态明显已经过了"实验期"。
- 有统一的市场索引和每日构建流水线；
- 插件普遍带设置页、扫码登录、依赖自检、缓存管理、错误降级；
- 文档质量超出一般开源项目（`dsh-bili-watch` 的 README 写了 400 行，连缓存子目录哪些能删都列清楚了）。

**但也别盲目乐观：**

| 风险 | 具体表现 | 建议 |
|---|---|---|
| **同质化** | 20 个"刷 B 站"插件，功能高度重叠 | 只装一个，别叠着装 |
| **个人项目** | 多数是"自己用顺手放上来"，无 roadmap、不承诺更新 | 优先选发布到 npm、有版本号、近期有提交的 |
| **Host 进程内代码** | 插件代码跑在 DSH 主进程，权限等同于你 | 只装能看懂来源的；写操作默认全关就别开 |
| **凭证风险** | SESSDATA / bili_jct 等同账号密码 | 用小号；凭证文件不要提交、不要外传 |
| **接口非官方** | 依赖 B 站未公开接口，随时可能失效（-412 风控） | 接受"某天突然不能用" |
| **合规** | 抓取字幕/评论属个人学习用途 | 别商用、别批量爬、别高频请求 |

**许可证**：主流项目均为 **MIT**，可放心阅读和修改；个别插件合并了多个上游（如 `dsh-bili-video`），
使用时注意其 `NOTICE` 里对各家版权的声明。
