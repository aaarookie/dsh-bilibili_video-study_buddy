视频：Andrej Karpathy【中英⚡从零构建 GPT（重制版）|Neural Networks: Zero to Hero】
P7  P7 Let's build GPT： from scratch, in code, spelled out.
区间：29:00 ~ 30:30（90 秒）｜ 语言 en ｜ 耗时 9.53s
目标点 30:00（前 60s 铺垫 + 后 30s 延续）

[29:00] generation. Now I'm going to go again a little bit faster here because I covered all this already in
[29:05] the previous videos. So here's a generate function for the model. So we take some, we take the same
[29:15] kind of input idx here and basically this is the current context of some characters in a batch,
[29:24] in some batch. So it's also b by t and the job of generate is to basically take this b by
[29:31] and extended to be b by t plus 1 plus 2 plus 3 and so it's just basically it
[29:35] continues the generation in all the batch dimensions in the time dimension. So
[29:39] that's its job and it will do that for max new tokens. So you can see here on
[29:44] the bottom there's gonna be some stuff here but on the bottom whatever is
[29:47] predicted is concatenated on top of the previous IDX along the first
[29:53] dimension which is the time dimension to create a b by t plus 1. So that
[29:57] becomes a new IDX. So the job of generate is to take a B by T and make it a B by T plus   <<< 目标点
[30:02] one plus two plus three as many as we want maximum tokens. So this is the generation from
[30:07] the model. Now inside the generation, what are we doing? We're taking the current indices,
[30:13] we're getting the predictions. So we get, those are in the logits. And then the
[30:19] loss here is going to be ignored because we're not, we're not using that. And we
[30:22] We have no targets that are sort of ground truth targets
[30:26] that we're going to be comparing with.
[30:29] Then once we get the logits.