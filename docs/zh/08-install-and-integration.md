# 08 · 本次安装与联调记录

> 2026-11-13 第三轮：装插件、配 ffmpeg、装 ASR 环境、逐项实测。
> 结论先说：**两个插件已装好并当场生效（DSH 的 HMR 让它不用重启就挂载了）**；
> 唯一没搞定的是"自动读取 Chrome 登录态"，需要你扫码一次。

---

## 一、装了什么

| 组件 | 版本 | 状态 |
|---|---|---|
| `dsh-bili-watch` | 0.4.10 | ✅ 已装，工具 `bili_watch` 已挂载 |
| `dsh-bili-study` | 1.0.0 | ✅ 已装，工具 `bili_study_fetch` / `bili_study_save_catalog` 已挂载 |
| 插件的 ffmpeg/ffprobe | 2018 构建 | ✅ 复制到 `~/.dsh/bili-watch/deps/` |
| 插件的 yt-dlp | 2026.10.26 | ✅ fetch-deps 自动安装 |
| ASR 环境 `.venv-asr` | Python 3.12 + faster-whisper 1.2.1 | ✅ 可用 |
| OCR 环境 `.venv-ocr` | Python 3.12 + rapidocr 1.2.3 | ✅ 可用 |
| faster-whisper-small 模型 | 464 MB | ✅ 已下载 |

`~/.dsh/bili-watch/deps/` 总占用 **1.13 GB**。
profile 配置已备份：`~/.dsh/profiles/web/package.json.bak-20261113-205029`。

---

## 二、当场实测结果

### ✅ 能用的

| 命令 | 结果 |
|---|---|
| `view` | 完整元数据 + UP + 8 个分P + 热评（含 UP 置顶） |
| `search` | 命中 4 条，带播放量、时长、UP、发布日期 |
| `frames -at 12:00 -p 5` | 成功抽帧，12.9 秒（含下载），输出 `f_12m00s.jpg` |
| 本地 ASR | 60 秒音频 **0.8 秒**转完，中文可读 |

### ❌ 卡住的

| 命令 | 原因 |
|---|---|
| `sub`（字幕） | `nav code=-101 账号未登录`，且**该视频本身没有 AI 字幕轨**——就算登录也拿不到 |

所以这类"老师手写板书 + 口述"的课，**没有官方字幕可用**，只能走 ASR + 看图。

---

## 三、三个必须知道的实测发现

### 3.1 插件抽帧是 360p，脚本抽帧是 480p

同一时刻（P5 @12:00）两个工具的结果：

| 工具 | 分辨率 | 大小 |
|---|---|---|
| `bili_watch frames` | **480×360** | 42 KB |
| `bili-frame.ps1` | **640×480** | 62 KB |

原因：插件为了省流量，下载 360p 视频再抽帧；脚本直接向 B 站要播放地址，拿匿名最高档。

**结论**：看代码细节用 `bili-frame.ps1`；插件适合快速扫描和九宫格。

### 3.2 B 站 DASH 是音视频分离的

第一次提音频失败，报"Output file does not contain any stream"——因为我把**视频轨**当输入，而视频轨里没有音轨。

正确的是取 `dash.audio`：

```
音频轨 3 条：id=30232 / 30216 / 30280（44.1k / 24k / 48k）
```

这条对写脚本的人很重要，对用插件的人无感（插件自己处理了）。

### 3.3 ASR 会系统性听错代码术语

同一段 60 秒（讲"动态内存分配"），转写结果：

| 老师原话 | ASR 输出 | 错因 |
|---|---|---|
| `*p = 10` | 「星匹等于10」 | `*` 读作"星"，`p` 读作"匹" |
| 解引用 | 「解码解地址」 | 同音近义混淆 |
| `free(p)` | 「4AP」 | 英文函数名听成数字+字母 |
| 栈上 | 「站上」 | 同音 |
| 堆上 | 「堆上」 | ✅ 正确 |

**所以正确用法是分工**：

- **ASR 给"脉络"**：在讲什么、为什么这么讲、结论是什么——它这部分很准；
- **看图给"代码"**：变量名、符号、缩进、运算——它这部分 ASR 完全靠不住；
- 两者对齐时间点，才是一份完整笔记。

这也再次说明：**不要把 ASR 文本直接当代码引用**。

---

## 四、为什么没能自动用上你的 Chrome 登录态

你 Chrome 里登着小号，我尝试了三种方式读 Cookie，全部失败：

| 方式 | 结果 |
|---|---|
| 直接复制 `Cookies` 文件 | ❌ 被 Chrome 独占锁定 |
| 共享读（FileShare 含 Delete） | ❌ 同样被锁 |
| `robocopy /B` 备份模式 | ❌ 退出码 16 |
| 卷影副本 | ❌ 无可用副本，创建需管理员 |

**而且即使读到文件也解不开**：Chrome 156 的 `Local State` 里同时有
`encrypted_key`（DPAPI）和 **`app_bound_encrypted_key`**——后者是 Chrome 127+ 引入的
**App-Bound Encryption**，密钥绑定在 Chrome 进程上，普通程序解不了。这是它防 cookie 窃取的设计，不是配置问题。

**所以走插件的正规路径：扫码登录。**

---

## 五、你重启后要做的三件事

### 5.1 重启（可选但推荐）

插件其实已经热挂载了，当前会话就能用。但重启有两个好处：

1. DSH 进程会读到**新的 PATH**（含 `ffmpeg`、`uv`、`yt-dlp`），插件找依赖更省事；
2. 环境变量 `BILI_WATCH_FFMPEG` 生效，多一层保险。

### 5.2 扫码登录（拿字幕和高画质）

1. 打开 DSH：<http://127.0.0.1:3080>
2. **设置 → 插件 → dsh-bili-watch**，进入它的面板
3. 点「去扫码登录」，手机 B 站扫（用你那个小号）
4. 确认时选「**记住我 / 长期**」，别选 24 小时
5. 凭证存到 `~/.dsh/bili-watch/credential.json`

> 如果面板里二维码出不来，点一次「装主依赖」让它把 pythonPath 指回自己的 venv。

### 5.3 验收清单

```
① 新会话问：「你有哪些 bilibili 相关工具？」→ 应看到 bili_watch
② 说：「view BV1HE421j7Lt」→ 应返回标题、UP、8 个分P
③ 说：「search 数据结构 代码讲解」→ 应返回 4 条带播放量的结果
④ 说：「frames BV1HE421j7Lt P5 at 12:00」→ 应输出一张图
⑤ 登录后说：「sub BV1HE421j7Lt P5」→ 看是否拿到字幕（这个视频大概率仍提示无字幕）
⑥ 说：「text BV1HE421j7Lt P5 head 800」→ 应走本地 ASR 返回转写开头
```

---

## 六、重启后建议的第一次真任务

```
看 BV1HE421j7Lt 的 P5，先用 text 拿 12:00 前后的转写，
再用 bili-frame.ps1 抽 12:00 那一帧，
然后把"老师在讲什么"和"代码长什么样"对齐，
整理成一节笔记存到 examples 下
```

这正好同时用到：ASR（插件）+ 高清抽帧（脚本）+ 看图（模型）+ 笔记模板。

---

## 七、配置速查

| 项 | 值 |
|---|---|
| 插件 deps | `~/.dsh/bili-watch/deps` |
| ASR 解释器 | `~/.dsh/bili-watch/deps/.venv-asr/Scripts/python.exe` |
| OCR 解释器 | `~/.dsh/bili-watch/deps/.venv-ocr/Scripts/python.exe` |
| 模型 | `~/.dsh/bili-watch/deps/.hf-home/hub/models--Systran--faster-whisper-small` |
| 抽帧缓存 | `~/.dsh/bili-watch/cache/frames` |
| 登录凭证 | `~/.dsh/bili-watch/credential.json`（扫码后生成） |
| ffmpeg 环境变量 | `BILI_WATCH_FFMPEG`（用户级，已设） |
| 插件备份 | `~/.dsh/profiles/web/*.bak-20261113-205029` |
