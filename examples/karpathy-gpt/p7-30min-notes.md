# Karpathy《Let's build GPT》P7 · 第 30 分钟精讲

> **视频**：<https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1800>（P7，1:56:20）
> **本节定位**：实现 `BigramLanguageModel.generate()` —— 语言模型的**自回归采样循环**
> **素材**：6 帧抽帧（734×480）+ 28:00–33:00 原声转写
> **注意**：这是进入 Transformer **之前**的 bigram 版本。GPT 的 generate 用的就是这同一套骨架，一行没变。

---

## 一、这段代码在整节课里的位置

```
27:00  定义 BigramLanguageModel、forward、算 loss  →  loss = 4.87
28:14  Karpathy 检查：词表 65，随机猜应该是 ln(65) ≈ 4.17，为什么是 4.87？
       → 说明初始 embedding 的预测还不够"平"，带一点熵
28:52  "we'd like to also be able to generate from the model. So let's do the generation."
30:08  ← 【你现在看的位置】"Now inside the generation, what are we doing?"
31:24       关键澄清：generate 里调用 self(idx) 没传 targets，
            所以 forward 的 targets 必须改成可选（默认 None）
32:04  跑起来，生成 100 个 token —— 得到一堆乱码
35:00  已经在用 AdamW 训练
之后    才引入 self-attention，把 bigram 换成 Transformer
```

**一句话**：这段是"让模型能开口说话"的那一步。它此时只会看前一个字符，所以说出来的话很蠢——但**说话的方式**（自回归循环）和最终 GPT 一模一样。

---

## 二、完整代码

![第 30 分钟的 generate 方法全貌（P7 @30:10）](frames/BV1mqrTBvEaf_P7_1810s.jpg)

```python
import torch
import torch.nn as nn
from torch.nn import functional as F
torch.manual_seed(1337)

class BigramLanguageModel(nn.Module):

    def __init__(self, vocab_size):
        super().__init__()
        # each token directly reads off the logits for the next token from a lookup table
        self.token_embedding_table = nn.Embedding(vocab_size, vocab_size)

    def forward(self, idx, targets=None):
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
            logits = logits[:, -1, :]        # becomes (B, C)
            # apply softmax to get probabilities
            probs = F.softmax(logits, dim=-1) # (B, C)
            # sample from the distribution
            idx_next = torch.multinomial(probs, num_samples=1)  # (B, 1)
            # append sampled index to the running sequence
            idx = torch.cat((idx, idx_next), dim=1)  # (B, T+1)
        return idx
```

---

## 三、逐行拆解

### 3.1 函数契约：`(B,T) → (B, T+n)`

Karpathy 的原话（29:29）：

> "The job of generate is to basically take this b by t and **extend it to be b by t plus one plus two plus three**."

- `idx` 是**当前上下文**，形状 `(B, T)`——batch 里每个样本一条字符序列；
- `max_new_tokens` 是要往后接多少个字；
- 返回的 `idx` 已经是 `(B, T+n)`——**函数自己把序列变长了**。

这就是"生成"最朴素的定义：喂一段开头，让它往后长。

### 3.2 `logits, loss = self(idx)` —— 为什么要重新 forward

因为要复用模型的预测逻辑（包括 batch 处理、设备、梯度状态）。
代价是：**每一步都把整段 `idx` 从头算了一遍**，但后面只用到最后一个位置。

> Karpathy 没在这段优化它。真实推理时会用 KV cache 把已算过的部分缓存起来，
> 只算新 token——但那是工程优化，概念模型就是这里写的这样。

`loss` 被丢弃（`_` 可以写成 `loss` 但不用）。原因见 3.5。

### 3.3 `logits[:, -1, :]` —— 全篇最关键的一行

> 原话（30:29）："we are only focusing on the last step. So instead of a b by t by c, we're going to pluck out the negative one, the last element in the time dimension, because those are the **predictions for what comes next**."

- `logits` 形状 `(B, T, C)`，`C` 是词表大小（65）；
- `[:, -1, :]` 取每个样本**最后一个时间步**的 65 个分数；
- 结果 `(B, C)`。

为什么只取最后一个？因为位置 `t=0..T-1` 的预测分别是"第 0 个字符之后是什么""第 1 个字符之后是什么"……
而我们只关心"最后一个字符之后是什么"——那才是序列的**下一个** token。

> 其余位置的预测在训练时有用（每个位置都能提供监督信号），在生成时全是浪费。

### 3.4 `softmax` + `multinomial` —— 采样，不是取最大

```python
probs = F.softmax(logits, dim=-1)                    # (B, C) 概率
idx_next = torch.multinomial(probs, num_samples=1)   # (B, 1) 按概率抽 1 个
```

- `softmax(dim=-1)`：沿词表维度把 65 个 logit 变成概率，和为 1；
- `multinomial`：**按概率随机抽**，不是 `argmax`。

这两行的差别决定了模型是"活的"还是"死的"：

| 做法 | 结果 |
|---|---|
| `argmax` | 每次都选最高分 → 输出**确定**、容易重复、无法采样多样性 |
| `multinomial` | 按分布抽 → 有随机性，同一起点能生成不同文本 |

> 你现在听到的"温度""top-k""top-p"采样，全都是在改**这一步**的分布形状，
> 但骨架仍然是 softmax → sample。

`num_samples=1` 决定了 `idx_next` 是 `(B,1)` 而不是 `(B,k)`。

### 3.5 `targets=None` —— 为什么 forward 要改签名

这是 31:24 那段最容易被忽略、但很关键的工程细节。原话：

> "you see how I'm calling self of IDX, which will end up going to the forward function. I'm **not providing any targets**. So currently, this would give an error... So targets has to be optional. So targets is none by default."

推理时没有"正确答案"可比，自然没有 loss。所以：

```python
def forward(self, idx, targets=None):     # 默认 None = 推理模式
    ...
    if targets is None:
        loss = None                        # 只给 logits
    else:
        ...                                # 训练模式，算 loss
```

**一行 `=None` 让同一个 forward 同时服务训练和推理**。这是 PyTorch 里非常常见的写法，
后面 GPT 版本原样保留。

### 3.6 `torch.cat((idx, idx_next), dim=1)` —— 滚动

新 token 接在**时间维**（`dim=1`）后面，`(B,T) + (B,1) = (B,T+1)`。
下一轮循环拿这个更长的 `idx` 再去预测，如此往复。

> 这也是为什么它是"自回归"（autoregressive）：**自己的输出变成自己的输入**。

---

## 四、为什么说这是"最笨的 GPT"

看 `__init__`：

```python
self.token_embedding_table = nn.Embedding(vocab_size, vocab_size)
```

这是一个 `65×65` 的查找表：第 `i` 行直接就是"字符 i 之后各字符的分数"。

- **上下文长度 = 1**：预测下一个字时，只看紧挨着的那一个字，前面全忘了；
- 所以生成结果是 `"SELEEEEEEEEEEEOOOOOOOO..."` 这种——它学会了"e 后面常跟 e"，但学不会"单词"。

**但注意**：`generate()` 这个方法本身**没有任何问题**。
后面把 bigram 换成 Transformer 时，Karpathy 改的是 `forward`（加入 attention + MLP），
`generate` **一个字都没改**。

所以这段代码真正的价值是：**它定义了 GPT 的"输出接口"**。

---

## 五、跑起来会发生什么

```python
context = torch.zeros((1, 1), dtype=torch.long, device=device)
print(decode(m.generate(context, max_new_tokens=100)[0].tolist()))
```

两个细节：

1. **`torch.zeros((1,1))`**：batch=1、长度=1，内容是 `0`。
   Karpathy 说 `0` 在 tiny Shakespeare 数据集里正好是**换行符** `\n`——
   所以"从换行开始写"是个合理的开场。
2. **输出形态**：因为模型只看前一个字，输出会是一堆局部重复的字符。
   等加上 attention，才会开始出现像样的英文单词和莎士比亚腔调。

---

## 六、和后续内容的衔接

| 时间 | 发生了什么 |
|---|---|
| 28:14 | 检查初始 loss（4.87 vs 理论 ln65≈4.17），理解"预测还不够平" |
| **30:00** | **实现 generate（本节）** |
| 32:04 | 跑通，生成 100 token 的乱码 |
| 35:00 | 用 `AdamW(model.parameters(), lr=1e-3)` 进入训练循环 |
| 之后 | 引入 `Head` / `MultiHeadAttention`，把 bigram 换成真正的 Transformer |

**这一节是"从能算 loss"到"能生成文本"的分水岭**，也是后面所有改进的对照组：
你会看到 attention 如何把这段乱码变成通顺的英文。

---

## 七、三个容易误解的点

| 误解 | 实际 |
|---|---|
| "`loss` 在 generate 里没用，是不是写错了？" | 故意丢弃。推理没有 ground truth，`forward` 返回 `None` |
| "为什么要 `self(idx)`，不能直接查表？" | 为了复用 forward（batch/设备/梯度）。效率问题留给后续优化 |
| "`logits[:, -1, :]` 是取最后一个 batch？" | 取的是**时间维**的最后一个位置，batch 维原样保留 |

---

## 八、回看清单

| 时间点 | 看什么 |
|---|---|
| [28:14](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1694) | 初始 loss 4.87 的推理过程（为什么不是 4.17） |
| [29:29](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1769) | "b by t → b by t+n" 的契约讲解 |
| [30:29](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1829) | **只取最后时间步**的理由 |
| [31:24](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1884) | 为什么 `targets` 要改成可选 |
| [32:38](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=1958) | `0` = 换行符，为什么拿它当起点 |
| [35:00](https://www.bilibili.com/video/BV1mqrTBvEaf?p=7&t=2100) | 进入 AdamW 训练 |

---

## 附：素材说明

- 抽帧：`bili-frame.ps1`，P7 的 29:00 / 29:40 / 30:10 / 30:40 / 31:10 / 31:40 / 35:00 共 7 帧，734×480。
- 转写：本地 faster-whisper small，28:00–33:00 共 5 分钟，英文，1.1 秒加载 + 40 秒转完。
- 转写文本：[transcript_1680_1980.txt](transcript_1680_1980.txt)
- 画面对照：`frames/` 目录
