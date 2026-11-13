# dsh-bili-video

一个 [DeepSeek Harness](https://github.com/deepseek-ai/dsh) 插件，把 **B站 的「读嘴」** 和 **视频的「看眼」** 合进同一个包：

- **读嘴**：搜视频、读字幕原文、翻评论、发评论、三连、私信、扫码登录、收件箱
- **看眼**：一条视频（链接或 BV 号）→ 切点检测 + 带编号的宫格图 + 时间码清单 + 音频波形条 → 想看细节再放大

> **这是我给自己用的小工具，顺手放上来给朋友抄作业。**
> 不是产品：没有 roadmap、不承诺更新、也不保证在任何环境和 DSH 版本上都一模一样地跑。
> 坏了我会自己修，修到能用就算了。介意这个的话，建议直接用上游那两个项目。

## 三步装好

1. 机器上要有 **Python 3.10+**（或 `uv`）和 **`ffmpeg`**。
   Python 是 B站 工具那半要用的；没有 ffmpeg 的话「看视频」那半用不了，B站 那半照常。
2. 在 DSH 里：**设置 → 插件 → 安装**，填这一行；或者命令行：

```
github:13520rygvv/dsh-bili-video
```

```bash
dsh plugin --profile desktop add github:13520rygvv/dsh-bili-video
```

3. 装完**重启一次 DSH**（插件在 bundle 层组装，不重启不生效），进 **设置 → 看视频**，先把 B站 账号扫码登录。

⭐ 最省事的一条：把仓库链接贴给你自己的 dsh，跟它说「**帮我装这个插件**」。

## 它有什么

### B站 那半边

| 工具 | 干什么 |
| --- | --- |
| `bili_search` | 搜视频（关键词 / 排序 / 时间窗），拿 BV 号、播放量、简介 |
| `bili_subtitle` | 读字幕原文（没字幕会直说） |
| `bili_comments` | 翻评论区（含楼中楼），按赞数排 |
| `bili_reply` | 发一条评论（可 @ 人） |
| `bili_triple` | 三连：点赞 / 投币 / 收藏 |
| `bili_send_message` | 发私信 |
| `bili_whoami` | 当前登录的是谁、凭证还有效吗 |
| `bili_status` | 今天刷了几轮、下次什么时候、环境是否就绪 |
| `bili_login_start` / `bili_login_poll` | 扫码登录（生成二维码 → 轮询结果） |
| `bili_setup` | 装主依赖 / 修环境 |
| `bili_config` | 读或改配置（等价于设置页，但能一次改一批） |

### 看视频那半边

| 工具 | 干什么 |
| --- | --- |
| `video_probe` | 只读容器头：时长、分辨率、有没有字幕轨、可用档位。**不花图片 token** |
| `video_storyboard` | 一条视频 → N 格宫格图 + 时间码清单 + 音频条（切点、静音、镜头数） |
| `video_zoom` | 只在某个时间窗内重扫一遍，要更细的帧 |
| `video_locate` | 给一句话，找回它在片子里的大致时间码 |
| `video_watch` | 按「看点」模式跑一遍（自动挑重点段的组合流程） |

几个实际行为，先说清楚免得踩坑：

- **BV 号直喂**：`video_storyboard({ input: "BV1TDC6YVEK7" })` 就行，插件自己补成完整链接。
- **用自己的登录态取流**：默认 480p 够看结构；登录后能拿到 1080p / 1440p（大会员专属档位另算）。
- **没有字幕才听写**：先找站点 CC 字幕轨，没有才调 ASR —— 钱只花在真需要的地方。
- **宫格图是低码率扫描副本**，看细节要用 `video_zoom` 去原流里取。

## 设置页

**设置 → 看视频**，5 个页签：

| 页签 | 放什么 |
| --- | --- |
| 看视频 | 一次出几张图、每张几格、细节档位、扫描/放大清晰度、听写语言 |
| B站 | 三连策略、收件箱（谁 @ 我 / 私信我）、回复频率、是否替你说话 |
| 自动刷 | 什么时候跑（只在谷时 / 全天）、两轮间隔、挑几条、筛选门槛、日报详细度 |
| 提示词 | 子代理流程、评论怎么写的提示词（都带占位符，改完即时生效） |
| 环境与高级 | 版本与更新、Python 路径、登录状态、数据目录 |

「看视频」那页的 7 个字段是**真配置**，改完对下一次工具调用立即生效（不用重启、不用重装）：

| 配置 | 含义 |
| --- | --- |
| `videoCells` | 一张图放几格（0 = 自动） |
| `videoSheets` | 出几张图（0 = 自动） |
| `videoDetail` | 每格给多少文字：`low` / `med` / `high`（high 会读画面上的硬字幕） |
| `videoScanHeight` | 扫描用的低清档：240 / 360 / 480 / 720 |
| `videoZoomHeight` | 放大看时从原流取的档：720 / 1080 / 1440 / 2160 |
| `videoTranscript` | 听写策略：`auto`（没字幕才听）/ `off` |
| `videoAsrLang` | 听写语言：空 = 跟 `asr.json`，或 `auto` / `zh` / `en` / `ja` |

## 需要什么

| 依赖 | 必需？ | 说明 |
| --- | --- | --- |
| Python 3.10+ 或 `uv` | B站 那半必需 | 没有的话，点设置页的「装主依赖」，插件会自己下一份 `uv` 到家目录 |
| `ffmpeg` | 看视频那半必需 | 放在 PATH 里即可 |
| `yt-dlp` | 可选 | 想让工具直接吃 B站 链接 / BV 号才需要；装进插件自己的 venv 也行 |
| ASR key | 可选 | 只在「视频没有 CC 字幕」时用；写在 `~/.dsh/asr.json` |

`asr.json` 长这样（配完即时生效，不用重启）：

```json
{
  "baseUrl": "https://api.siliconflow.cn/v1",
  "key": "sk-...",
  "model": "FunAudioLLM/SenseVoiceSmall",
  "language": "auto"
}
```

> `language` 建议 `auto`：中文视频出中文、日语原声出日文；写死 `zh` 会把日语硬转成乱码汉字。
> SenseVoice 对动漫台词准确率一般，引用台词前最好拿画面上的字幕核对一遍。

## 更新

```bash
dsh plugin --profile desktop remove dsh-bili-video
dsh plugin --profile desktop add github:13520rygvv/dsh-bili-video
```

设置页「环境与高级 → 检查更新」也会提示有没有新提交。

## 更新记录

| 日期 | 提交 | 一句话 |
| --- | --- | --- |
| 2026-10-29 | `79f3ac6` | LICENSE 换成标准 MIT（多版权人），第三方说明归并进 NOTICE；仓库首次公开 |
| 2026-10-29 | `e0eb883` | 发布包补上 NOTICE（`files` 白名单），加 `.gitattributes` 统一 LF |
| 2026-10-29 | `7ddf0e8` | v0.9.0 首个提交：合并 B站 工具与视频分镜，重写 README |

更细的历史见 [`CHANGELOG.md`](CHANGELOG.md)。

## 常见问题

- **装了但设置里没有「看视频」** → 多半是 DSH 版本太老，内核会**静默跳过**。要求 `dsh >= 0.1.7-rc.1`。
- **重启后应用起不来，报 `import failed`** → 检查 `client.js` 里 `load({ id: ... })` 的 id 是否等于 `package.json` 的 `name`；两者不一致会导致客户端模块重复注册、整个 web boot 挂掉。
- **看视频说没有字幕** → 那是 ASR 没配，不是视频没声音；`transcript: no-key` 就是提示这个。
- **B站 链接下载失败** → 装 `yt-dlp`，并确认插件家目录的 venv 里能找到它。

## 来源与致谢（这不是我从零做的）

本仓库是两个人的作品的**合并 / 改造版**：

1. **Yuuyuko-uu / [`dsh-bili-subagent`](https://github.com/Yuuyuko-uu/dsh-bili-subagent)**（MIT）——
   底座：`index.js` / `client.js` / `lib/` / `prompts/` / `vendor/bilibili-mcp/` / `selfcheck.mjs`。
   它的上游又是 **c1overzz / [`dsh-bili-scroll`](https://github.com/c1overzz/dsh-bili-scroll)**（MIT）。
2. **SAOS-3624 / [`dsh-video-storyboard`](https://github.com/SAOS-3624/dsh-video-storyboard)**（MIT）——
   `vendor/storyboard/**` 基本原样拷贝（含它的 `LICENSE` / `NOTICE` / `CREDITS.md`）。

我对它们的改动：删掉 `bili_scan` 与会话页视频卡片墙、包名改成 `dsh-bili-video`、
把 storyboard 作为 vendor 挂进来、新增 BV 号直喂 / 登录态 cookies / ASR 兜底 / 全新设置页。

每个素材文件的原始出处和授权范围见 [`NOTICE`](NOTICE)。

## 许可证

我写的改动部分按 **MIT** 提供；`vendor/**` 下每个文件仍由各自作者拥有，按其 MIT 条款使用。
如果上游作者认为这样合并 / 分发不妥，说一声，我会转私有或删除。

**使用提醒**：插件只是替你去 B站 点按钮、读公开内容。别拿它刷量、别高频打扰别人，
账号出问题（限流 / 封禁）是使用者自己的事。
