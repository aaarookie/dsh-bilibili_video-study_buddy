# Karpathy《Let's build GPT》P7 · 第 30 分钟精讲（1080P 版）

> **视频**：<https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1800>（P7，1:56:20）
> **本节**：`BigramLanguageModel.generate()` —— 语言模型的自回归采样循环
> **素材**：1080P 抽帧 + 局部裁剪（1234×800）+ 本地 ASR 英文转写（28:00–33:00）
> **说明**：这是**进入 Transformer 之前**的 bigram 版本。GPT 的 `generate` 用的是同一套骨架。

---

## 一、本节在整节课里的位置

```
27:00  定义 BigramLanguageModel / forward / 算 loss
28:14  Karpathy 验算：词表 65，随机猜应该 -log(1/65)≈4.17，为什么是 4.87？
       → 说明初始 embedding 的预测还带着一点熵，不够"平"
28:52  "we'd like to also be able to generate from the model. So let's do the generation."
30:08  ←【本节】"Now inside the generation, what are we doing?"
31:24       关键澄清：generate 调 self(idx) 不传 targets，所以 forward 必须让 targets 可选
32:04  跑起来，生成 100 token 的乱码
35:00  进入 AdamW 训练循环
45:00  才开始 self-attention
```

**一句话**：这段是"让模型能开口说话"。它此时只会看前一个字符，所以说出来的话很蠢；
但**说话的方式**（自回归循环）和最终 GPT 一模一样。

---

## 二、完整代码

![generate 方法全貌（P7 @29:40，1080P 裁剪）](hd-frames/BV1mqrTBvEaf_P7_1780s_crop.jpg)

```python
class BigramLanguageModel(nn.Module):

    def __init__(self, vocab_size):
        super().__init__()
        # each token directly reads off the logits for the next token from a lookup table
        self.token_embedding_table = nn.Embedding(vocab_size, vocab_size)

    def forward(self, idx, targets=None):        # targets 改为可选是关键
        # idx and targets are both (B,T) tensor of integers
        logits = self.token_embedding_table(idx)  # (B,T,C)

        if targets is None:
            loss = None
        else:
            B, T, C = logits.shape
            logits = logits.view(B*T, C)
            targets = targets.view(B*T)
            loss = F.cross_entropy(logits, targets)

        return logits, loss

    def generate(self, idx, max_new_tokens):
        # idx is (B, T) array of indices in the current context
        for _ in range(max_new_tokens):
            # get the predictions
            logits, loss = self(idx)
            # focus only on the last time step
            logits = logits[:, -1, :]         # becomes (B, C)
            # apply softmax to get probabilities
            probs = F.softmax(logits, dim=-1)  # (B, C)
            # sample from the distribution
            idx_next = torch.multinomial(probs, num_samples=1)  # (B, 1)
            # append sampled index to the running sequence
            idx = torch.cat((idx, idx_next), dim=1)  # (B, T+1)
        return idx
```

---

## 三、函数契约：`(B,T) → (B, T+n)`

Karpathy 原话（29:29，ASR 转写）：

> "The job of generate is to basically take this b by t and **extend it to be b by t plus one plus two plus three**... So that's its job. And it will do that for max new tokens."

- 输入 `idx` 是当前上下文，形状 `(B, T)`；
- 输出已经变成 `(B, T+n)` —— **函数自己把序列变长了**；
- 这就是"生成"最朴素的定义：喂一段开头，让它往后长。

---

## 四、逐行拆解

### 4.1 `logits, loss = self(idx)` —— 为什么重新 forward

复用模型的预测逻辑（batch 处理、设备、梯度状态）。代价是**每步都把整段 `idx` 从头算一遍**，却只用最后一个位置。

> Karpathy 在这段没优化它。真实推理会用 KV cache 缓存已算部分，只算新 token；
> 但概念模型就是这里写的这样。

`loss` 被丢弃，因为推理时没有 ground truth。

### 4.2 `logits[:, -1, :]` —— 全篇最关键的一行

> 原话（30:29）："we are only focusing on the last step. So instead of a b by t by c, we're going to **pluck out the negative one, the last element in the time dimension**, because those are the predictions for what comes next."

- `logits` 是 `(B, T, C)`，`C` = 词表大小 65；
- `[:, -1, :]` 取每个样本**最后一个时间步**的 65 个分数 → `(B, C)`。

**为什么只取最后一个**：位置 `t=0..T-1` 的预测分别是"第 0 个字之后是什么""第 1 个字之后是什么"……
我们只要"最后一个字之后是什么"，那才是序列的**下一个** token。
其余位置在训练时有用（每个位置都是监督信号），在生成时全是浪费。

### 4.3 `softmax` + `multinomial` —— 采样，不是取最大

```python
probs = F.softmax(logits, dim=-1)                    # (B, C) 概率，和为 1
idx_next = torch.multinomial(probs, num_samples=1)   # (B, 1) 按概率抽 1 个
```

这两行决定模型是"活的"还是"死的"：

| 做法 | 结果 |
|---|---|
| `argmax` | 每次选最高分 → 输出确定、容易重复、无法采样多样性 |
| `multinomial` | 按分布随机抽 → 同一起点能生成不同文本 |

> 今天的"温度 / top-k / top-p"全都在改**这一步的分布形状**，骨架仍是 softmax → sample。

`num_samples=1` 决定了 `idx_next` 是 `(B,1)` 而不是 `(B,k)`。

### 4.4 `targets=None` —— 最容易被忽略的工程细节

31:24 原话：

> "you see how I'm calling self of IDX, which will end up going to the forward function. I'm **not providing any targets**. So currently, this would give an error... So targets has to be optional. So targets is none by default."

推理时没有正确答案可比，自然没有 loss。于是：

```python
def forward(self, idx, targets=None):     # 默认 None = 推理模式
    ...
    if targets is None:
        loss = None                        # 只给 logits
    else:
        ...                                # 训练模式，算 loss
```

**一行 `=None` 让同一个 forward 同时服务训练和推理**。GPT 版本原样保留。

### 4.5 `torch.cat((idx, idx_next), dim=1)` —— 滚动

新 token 接在**时间维**后面，`(B,T) + (B,1) = (B,T+1)`。
下一轮拿更长的 `idx` 再预测 —— 这就是"自回归"：**自己的输出变成自己的输入**。

---

## 五、为什么说这是"最笨的 GPT"

```python
self.token_embedding_table = nn.Embedding(vocab_size, vocab_size)  # 65×65 查找表
```

- **上下文长度 = 1**：预测下一个字时只看紧挨着的那一个，前面全忘了；
- 所以生成结果是 `"SELEEEEEEEEEEE..."` 这种——学会了"e 后面常跟 e"，学不会"单词"。

**但 `generate()` 这个方法本身没有任何问题**。后面换成 Transformer 时，
Karpathy 改的是 `forward`（塞进 attention + MLP），`generate` **一个字都没改**。

所以这段代码真正的价值是：**它定义了 GPT 的"输出接口"**。

---

## 六、跑起来是什么样

![运行结果 torch.Size 32x65 与 loss 4.8786（P7 @32:10）](hd-frames/BV1mqrTBvEaf_P7_1930s_crop.jpg)

```python
m = BigramLanguageModel(vocab_size)
logits, loss = m(xb, yb)
print(logits.shape)   # torch.Size([32, 65])
print(loss)           # tensor(4.8786, grad_fn=<NllLossBackward0>)
```

两个可验证的数字：

- **`torch.Size([32, 65])`**：batch=32，词表=65。`forward` 里 `logits.view(B*T, C)` 之前是 `(32, 8, 65)`；
- **`loss = 4.8786`**：接近但高于理论随机值 `-ln(1/65) ≈ 4.174`。
  高出来的部分说明初始 `nn.Embedding` 的分布**不是均匀的**，带着一点熵——
  这正是 28:14 那段验算想说明的事。

生成时：

```python
context = torch.zeros((1, 1), dtype=torch.long, device=device)
print(decode(m.generate(context, max_new_tokens=100)[0].tolist()))
```

- `torch.zeros((1,1))`：batch=1、长度=1、内容 `0`；
- **`0` 在 tiny Shakespeare 里正好是换行符** `\n`，所以"从换行开始写"是合理的开场；
- 输出会是局部重复的乱码，等加上 attention 才开始像英文。

---

## 七、和后续的衔接

| 时间 | 内容 |
|---|---|
| 28:14 | 验算初始 loss（4.87 vs 理论 4.17） |
| **30:08** | **generate 内部逐行** |
| 32:04 | 跑通，生成 100 token |
| 35:00 | 进入 AdamW 训练 |
| 40:00 | 训练后已能生成 "Foulf tountry tory ars dor yoresz..." |
| 45:00 | 开始 self-attention |

---

## 八、三个容易误解的点

| 误解 | 实际 |
|---|---|
| "generate 里的 loss 没用，是不是写错了？" | 故意丢弃。推理无 ground truth，`forward` 返回 `None` |
| "为什么不直接查表，要 `self(idx)`？" | 复用 forward 的 batch/设备/梯度逻辑；效率问题留给 KV cache |
| "`logits[:, -1, :]` 取的是最后一个 batch？" | 取的是**时间维**最后一个位置，batch 维原样保留 |

---

## 九、回看清单

| 时间点 | 看什么 |
|---|---|
| [28:14](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1694) | 初始 loss 4.87 的推理 |
| [29:29](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1769) | `(B,T) → (B,T+n)` 的契约 |
| [30:29](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1829) | **只取最后时间步**的理由 |
| [31:24](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1884) | 为什么 `targets` 要可选 |
| [32:38](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1958) | `0` = 换行符，为何拿它当起点 |
| [35:00](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=2100) | 进入 AdamW 训练 |

---

## 十、素材与校验

- **画面**：`bili-frame.ps1` 抽 1080P（1654×1080）后裁剪顶部 150 / 底部 130 / 右侧 420，
  得到 1234×800，token 从约 1768 降到约 975。
- **口述**：本地 faster-whisper small 转写 28:00–33:00（英文），
  5 分钟音频 40 秒转完；ASR 对代码术语会听错（如 `*p`→"星匹"），
  所以**代码一律以画面为准**，ASR 只用来还原讲解逻辑。
- **字幕**：本视频的 B 站 AI 字幕经检测为**串台**（返回了无关内容），已弃用。
  检测方法见 `bili-subs.ps1` 的覆盖度 / 术语命中 / 语速三项。
