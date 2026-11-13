# ASR 转写 | Andrej Karpathy【中英⚡从零构建 GPT（重制版）|Neural Networks: Zero to Hero】

> P8 P8 State of GPT ｜ BRK216HFS ｜ 区间 00:00 ~ 42:40（2,560 秒）｜ 语言 en ｜ 耗时 226.11 秒

[00:07] Please welcome AI researcher and founding member of OpenAI,
[00:12] Andre Carpathi.
[00:23] I'm happy to be here to tell you about the state of GPT
[00:26] and more generally about the rapidly growing ecosystem of large language
[00:30] models. So I would like to partition the talk
[00:33] into two parts. In the first part, I would like
[00:36] to tell you about how we train GPT assistance.
[00:39] And then in the second part, we are going to take a look at how we can use
[00:42] these assistance effectively for your applications.
[00:46] So first let's take a look at the emerging recipe for how to train these assistants and
[00:50] keep in mind that this is all very new and still rapidly evolving, but so far the recipe
[00:54] looks something like this.
[00:55] Now this is kind of a complicated slide, so I'm going to go through it piece by piece.
[01:00] But roughly speaking we have four major stages, pre-training, supervised fine-tuning,
[01:05] reward modeling, reinforcement learning, and they follow each other serially.
[01:10] Now in each stage we have a data set that powers that stage.
[01:14] We have an algorithm that, for our purposes,
[01:16] will be an objective for training the neural network.
[01:22] And then we have a resulting model.
[01:24] And then there are some nodes on the bottom.
[01:25] So the first stage we're going to start with
[01:27] is the pre-training stage.
[01:28] Now, this stage is kind of special in this diagram.
[01:31] And this diagram is not to scale,
[01:33] because this stage is where all of the computational work
[01:35] basically happens.
[01:36] This is 99% of the training compute time and also flops.
[01:42] And so this is where we are dealing
[01:44] with internet-scale data sets with thousands of GPUs
[01:47] in the supercomputer and also months of training potentially.
[01:51] The other three stages are fine-tuning stages
[01:53] that are much more along the lines of small few number
[01:56] of GPUs and hours or days.
[01:59] So let's take a look at the pre-training stage
[02:00] to achieve a base model.
[02:04] First, we're going to gather a large amount of data.
[02:07] Here's an example of what we call a data mixture that
[02:10] comes from this paper that was released by Meta,
[02:14] where they released this Lama-based model.
[02:16] Now you can see roughly the kinds of data sets
[02:18] that enter into these collections.
[02:20] So we have Common Crawl, which is just a web scrape,
[02:22] C4, which is also Common Crawl,
[02:25] and then some high quality data sets as well.
[02:27] So for example, GitHub, Wikipedia,
[02:29] Books, Archive, Stack Exchange, and so on.
[02:31] These are all mixed up together,
[02:33] and then they are sampled according
[02:34] to some given proportions,
[02:36] And that forms the training set for the neural net for the GPT.
[02:41] Now, before we can actually train on this data,
[02:43] we need to go through one more pre-processing step,
[02:45] and that is tokenization.
[02:46] And this is basically a translation
[02:48] of the raw text that we scrape from the internet
[02:50] into sequences of integers, because that's
[02:54] the native representation over which GPTs function.
[02:57] Now, this is a lossless kind of translation
[03:00] between pieces of text and tokens and integers.
[03:03] And there are a number of algorithms for this stage,
[03:05] Typically, for example, you could use something like byte there encoding, which iteratively
[03:09] merges little text chunks and groups them into tokens.
[03:13] And so here I'm showing some example chunks of these tokens, and then this is the raw integer
[03:18] sequence that will actually feed into a transformer.
[03:22] Now here I'm showing two sort of like examples for hyper-primers that govern this stage.
[03:28] So GPT-4, we did not release too much information about how it was trained and so on, so I'm
[03:32] I'm using GPT-3's numbers, but GPT-3 is, of course,
[03:35] a little bit old by now, about three years ago.
[03:37] But Lama is a fairly recent model for meta.
[03:40] So these are roughly the orders of magnitude
[03:42] that we're dealing with when we're doing pre-training.
[03:45] The vocabulary size is usually a couple 10,000 tokens.
[03:48] The context length is usually something like 2,000,
[03:50] 4,000, or nowadays even 100,000,
[03:53] and this governs the maximum number of integers
[03:56] that the GPT will look at
[03:57] when it's trying to predict the next integer
[03:59] in a sequence.
[04:00] You can see that roughly the number of parameters is, say, 65 billion for Lama.
[04:06] Now even though Lama has only 65B parameters compared to GPT-3's 175 billion parameters,
[04:11] Lama is a significantly more powerful model, and intuitively that's because the model is
[04:16] trained for significantly longer.
[04:18] In this case, 1.4 trillion tokens instead of just 300 billion tokens.
[04:21] So you shouldn't judge the power of a model just by the number of parameters that
[04:25] it contains.
[04:26] Below, I'm showing some tables of rough hyperparameters that typically go into specifying the transformer
[04:33] neural network, so the number of heads, the dimension size, number of layers, and so on.
[04:37] And on the bottom, I'm showing some training hyperparameters.
[04:41] So for example, to train the 65B model, Meta used 2,000 GPUs, roughly 21 days of training,
[04:50] and roughly several million dollars.
[04:52] So that's the rough orders of magnitude
[04:54] that you should have in mind for the pre-training stage.
[04:59] Now when we're actually pre-training what happens,
[05:01] roughly speaking, we are going to take our tokens
[05:03] and we're going to lay them out into data batches.
[05:06] So we have these arrays that will feed into the transformer
[05:09] and these arrays are B, the batch size
[05:11] and these are all independent examples stacked up in rows
[05:15] and B by T, T being the maximum context length.
[05:18] So in my picture I only have 10 the context length.
[05:21] So this could be 2000, 4000, et cetera.
[05:23] So these are extremely long rows.
[05:25] And what we do is we take these documents
[05:26] and we pack them into rows, and we
[05:28] delimit them with these special end of text tokens,
[05:31] basically telling the transformer
[05:32] where a new document begins.
[05:35] And so here I have a few examples of documents,
[05:38] and then I've stretched them out into this input.
[05:42] Now, we're going to feed all of these numbers
[05:44] into Transformer.
[05:46] And let me just focus on a single particular cell,
[05:49] but the same thing will happen at every cell
[05:51] in this diagram.
[05:52] So let's look at the green cell.
[05:54] The green cell is going to take a look
[05:56] at all of the tokens before it, so all of the tokens in yellow.
[06:00] And we're going to feed that entire context
[06:03] into the transformer neural network.
[06:05] And the transformer is going to try
[06:07] to predict the next token in a sequence, in this case,
[06:09] in red.
[06:10] Now, the transformer, I don't have too much time
[06:12] to, unfortunately, go into the full details
[06:13] of this neural network architecture.
[06:15] It's just a large blob of neural net stuff
[06:18] for our purposes.
[06:19] And it's got several 10 billion parameters typically
[06:21] or something like that.
[06:22] And of course, as we tune these parameters,
[06:24] you're getting slightly different predicted distributions
[06:26] for every single one of these cells.
[06:29] And so for example, if our vocabulary size is 50,257
[06:33] tokens, then we're going to have that many numbers
[06:36] because we need to specify a probability distribution
[06:39] for what comes next.
[06:40] So basically we have a probability for whatever may follow.
[06:43] Now in this specific example for this specific cell,
[06:45] 513 will come next.
[06:47] And so we can use this as a source of supervision
[06:49] to update our transformers weights.
[06:51] And so we're applying this basically on every single cell
[06:54] in the parallel, and we keep swapping batches,
[06:56] and we're trying to get the transformer
[06:58] to make the correct predictions over what
[06:59] token comes next in a sequence.
[07:01] So let me show you more concretely what this looks like
[07:04] when you train one of these models.
[07:05] This is actually coming from New York Times,
[07:08] and they trained a small GPT on Shakespeare.
[07:11] And so here's a small snippet of Shakespeare,
[07:12] and they trained a GPT on it.
[07:14] Now in the beginning at initialization,
[07:17] the GPT starts with completely random weights.
[07:19] So you're just getting completely random outputs as well.
[07:22] But over time, as you train the GPT longer and longer,
[07:26] you are getting more and more coherent and consistent
[07:29] sort of samples from the model.
[07:31] And the way you sample from it, of course,
[07:32] is you predict what comes next.
[07:35] You sample from that distribution,
[07:36] and you keep feeding that back into the process.
[07:39] And you can basically sample large sequences.
[07:42] And so by the end, you see that the transformer
[07:43] has learned about words, and where to put spaces,
[07:46] and where to put commas, and so on.
[07:48] And so we're making more and more consistent predictions
[07:50] over time.
[07:51] These are the kinds of plots that you're looking at
[07:53] when you're doing model pre-training.
[07:54] Effectively, we're looking at the loss function over time
[07:57] as you train.
[07:58] And low loss means that our transformer
[08:00] is predicting the correct, is giving a higher probability
[08:03] to get the correct next integer in a sequence.
[08:07] Now, what are we going to do with this model
[08:09] once we've trained it after a month?
[08:11] Well, the first thing that we noticed, the field,
[08:14] is that these models, basically,
[08:16] in the process of language modeling
[08:18] learn very powerful general representations,
[08:21] and it's possible to very efficiently fine tune them
[08:23] for any arbitrary downstream task
[08:25] you might be interested in.
[08:26] So as an example, if you're interested
[08:27] in sentiment classification,
[08:29] the approach used to be that you collect
[08:32] a bunch of positives and negatives
[08:33] and then you train some kind of an NLP model for that,
[08:37] but the new approach is ignore sentiment classification,
[08:40] go off and do large language model pre-training,
[08:43] train a large transformer,
[08:44] and then you can only, you may only have a few examples
[08:47] and you can very efficiently fine tune your model
[08:49] for that task.
[08:51] And so this works very well in practice.
[08:53] And the reason for this is that basically
[08:55] the transformer is forced to multitask a huge amount
[08:58] of tasks in the language modeling task
[09:00] because just in terms of predicting the next token,
[09:03] it's forced to understand a lot about the structure
[09:05] of the text and all the different concepts therein.
[09:10] So that was GPT-1.
[09:11] Now around the time of GPT-2,
[09:12] people noticed that actually even better than fine-tuning, you can actually prompt these
[09:16] models very effectively.
[09:17] So these are language models, and they want to complete documents.
[09:20] So you can actually trick them into performing tasks just by arranging these fake documents.
[09:25] So in this example, for example, we have some passage, and then we sort of like do QA,
[09:30] QA, QA.
[09:31] This is called a few-shot prompt, and then we do Q. And then as the transformer
[09:34] is trying to complete the document, it's actually answering our question.
[09:37] And so this is an example of prompt engineering a base model, making it believe that
[09:41] it's sort of imitating a document and getting it to perform a task.
[09:45] And so this picked off, I think, the era of, I would say, prompting over fine-tuning and
[09:50] seeing that this actually can work extremely well on a lot of problems even without training
[09:54] any neural networks, fine-tuning, and so on.
[09:57] Now since then, we've seen an entire evolutionary tree of base models that everyone has trained.
[10:03] Not all of these models are available.
[10:05] For example, the GPT-4 base model was never released.
[10:08] The GPT-4 model that you might be interacting with over API is not a base model, it's an
[10:12] assistant model, and we're going to cover how to get those in a bit.
[10:15] GPT-3 base model is available via the API under the name DaVinci, and GPT-2 base model
[10:21] is available even as weights on our GitHub repo.
[10:24] But currently the best available base model probably is the Lama series from Meta, although
[10:30] it is not commercially licensed.
[10:33] Now one thing to point out is base models are not systems.
[10:36] They don't want to make answers to your questions.
[10:41] They just want to complete documents.
[10:43] So if you tell them write a poem about the bread and cheese, it will just answer questions
[10:48] with more questions.
[10:49] It's just completing what it thinks is a document.
[10:51] However, you can prompt them in a specific way for base models that is more likely
[10:57] to work.
[10:58] So as an example, here's a poem about bread and cheese, and in that case it
[11:00] will autocomplete correctly.
[11:03] You can even trick base models into being assistants.
[11:06] And the way you would do this is you would create like a specific few shot prompt that
[11:10] makes it look like there's some kind of a document between a human and assistant and
[11:13] they're exchanging sort of information.
[11:16] And then at the bottom you sort of put your query at the end and the base model will
[11:21] sort of like condition itself into being like a helpful assistant and kind of answer.
[11:27] But this is not very reliable and doesn't work super well in practice, although
[11:29] it can be done.
[11:31] So instead, we have a different path
[11:32] to make actual GPT assistance, not just base model,
[11:35] document completers.
[11:37] And so that takes us into supervised fine tuning.
[11:39] So in the supervised fine tuning stage,
[11:41] we are going to collect small but high quality data sets.
[11:45] And in this case, we're going to ask human contractors
[11:47] to gather data of the form prompt and ideal response.
[11:52] And we're going to collect lots of these, typically
[11:54] tens of thousands or something like that.
[11:56] And then we're going to still do language modeling
[11:58] on this data.
[11:59] So nothing changed algorithmically.
[12:01] We're just swapping out a training set.
[12:02] So it used to be internet documents,
[12:04] which is a high-quantity, low-quantity,
[12:07] for basically QA prompt response data.
[12:11] And that is low-quantity, high-quality.
[12:14] So we still do language modeling,
[12:15] and then after training we get an SFD model.
[12:18] And you can actually deploy these models
[12:20] and they are actual assistants
[12:21] and they work to some extent.
[12:23] Let me show you what an example demonstration
[12:24] might look like.
[12:25] So here's something that a human contractor
[12:27] might come up with.
[12:28] Here's some random prompt.
[12:29] Can you write a short introduction
[12:31] about the relevance of the term monopsony
[12:33] or something like that?
[12:34] And then the contractor also writes out an ideal response.
[12:37] And when they write out these responses,
[12:38] they are following extensive labeling documentations.
[12:41] And they are being asked to be helpful, truthful, and harmless.
[12:45] And those labeling instructions here,
[12:48] you probably can't read it, neither can I.
[12:50] But they're long, and this is just
[12:52] people following instructions and trying
[12:53] to complete these prompts.
[12:55] So that's what the dataset looks like.
[12:57] And you can train these models.
[12:58] and this works to some extent.
[13:00] Now, you can actually continue the pipeline from here on
[13:03] and go into RLHF, Reinforcement Learning from Human Feedback,
[13:07] that consists of both reward modeling
[13:09] and reinforcement learning.
[13:10] So let me cover that, and then I'll come back
[13:12] to why you may wanna go through the extra steps
[13:14] and how that compares to just SFD models.
[13:16] So in the reward modeling step,
[13:18] what we're going to do is we're now going
[13:19] to shift our data collection to be
[13:21] of the form of comparisons.
[13:23] So here's an example of what our dataset will look like.
[13:25] I have the same prompt, identical prompt on the top,
[13:28] which is asking the assistant to write a program or a function
[13:32] that checks if a given string is a palindrome.
[13:35] And then what we do is we take the SFT model,
[13:38] which we've already trained,
[13:39] and we create multiple completions.
[13:41] So in this case, we have three completions
[13:42] that the model has created.
[13:44] And then we ask people to rank these completions.
[13:47] So if you stare at this for a while,
[13:49] and by the way, these are very difficult things to do
[13:50] to compare some of these predictions,
[13:52] and this can take people even hours
[13:54] for single prompt completion pairs.
[13:58] But let's say we decided that one of these
[14:00] is much better than the others and so on.
[14:01] So we ranked them.
[14:03] Then we can follow that with something
[14:04] that looks very much kind of like a binary classification
[14:07] on all the possible pairs between these completions.
[14:10] So what we do now is we lay out our prompt in rows,
[14:13] and the prompts is identical across all three rows here.
[14:16] So it's all the same prompt,
[14:17] but the completion is very,
[14:19] and so the yellow tokens are coming from the SFD model.
[14:22] Then what we do is we append another special reward
[14:25] readout token at the end,
[14:27] And we basically only supervise the transformer
[14:29] at this single green token.
[14:31] And the transformer will predict some reward
[14:34] for how good that completion is for that prompt.
[14:38] And so basically it makes a guess
[14:40] about the quality of each completion.
[14:42] And then once it makes a guess for every one of them,
[14:44] we also have the ground truth,
[14:46] which is telling us the ranking of them.
[14:48] And so we can actually enforce that some of these
[14:50] numbers should be much higher than others and so on.
[14:52] We formulate this into a loss function
[14:54] and we train our model to make reward predictions
[14:56] that are consistent with the ground truth
[14:58] coming from the comparisons from all these contractors.
[15:01] So that's how we train our reward model.
[15:02] And that allows us to score
[15:04] how good a completion is for a prompt.
[15:07] Once we have a reward model,
[15:09] we can't deploy this because this is not very useful
[15:12] as an assistant by itself,
[15:13] but it's very useful for the reinforcement learning stage
[15:16] that follows now.
[15:17] Because we have a reward model,
[15:18] we can score the quality of any arbitrary completion
[15:21] for any given prompt.
[15:23] So what we do during reinforcement learning
[15:24] is we basically get, again, a large collection of prompts,
[15:27] and now we do reinforcement learning
[15:29] with respect to the reward model.
[15:30] So here's what that looks like.
[15:32] We take a single prompt, we lay it out in rows,
[15:36] and now we use the SFD model,
[15:37] we use basically the model we'd like to train,
[15:39] which is initialized at SFD model
[15:41] to create some completions in yellow.
[15:43] And then we append the reward token again,
[15:46] and we read off the reward,
[15:48] according to the reward model,
[15:49] which is now kept fixed.
[15:50] It doesn't change anymore.
[15:52] And now the reward model tells us
[15:54] a quality of every single completion for these prompts.
[15:57] And so what we can do is we can now just basically apply
[15:59] the same language modeling loss function,
[16:01] but we're currently training on the yellow tokens,
[16:04] and we are weighing the language modeling objective
[16:08] by the rewards indicated by the reward model.
[16:11] So as an example, in a first row,
[16:13] the reward model said that this is
[16:15] a fairly high scoring completion,
[16:17] and so all of the tokens that we happened to sample
[16:20] on the first row are going to get reinforced,
[16:22] and they're going to get higher probabilities for the future.
[16:25] Conversely, on the second row, the reward model really did not
[16:28] like this completion, negative 1.2.
[16:30] And so therefore, every single token
[16:32] that we sampled in that second row
[16:33] is going to get a slightly higher probability for the future.
[16:36] And we do this over and over on many prompts,
[16:38] on many batches.
[16:39] And basically, we get a policy which creates yellow tokens
[16:42] here, and basically all of the completions here
[16:46] will score high according to the reward model that we
[16:48] trained in the previous stage.
[16:51] So that's how we train, that's what the RLHF pipeline is.
[16:55] Now, and then at the end, you get a model
[16:57] that you could deploy.
[16:58] And so as an example, ChatGPT is an RLHF model.
[17:02] But some other models that you might come across,
[17:04] like for example, the Kuna 13b and so on,
[17:06] these are SFD models.
[17:08] So we have base models, SFD models, and RLHF models,
[17:11] and that's kind of like the state of things there.
[17:14] Now, why would you want to do RLHF?
[17:17] So one answer that is kind of not that exciting
[17:19] is that it just works better.
[17:20] So this comes from the InstructGPT paper.
[17:23] According to these experiments a while ago now,
[17:25] these PPO models are RLHF,
[17:28] and we see that they are basically just preferred
[17:30] in a lot of comparisons when we give them to humans.
[17:33] So humans just prefer basically tokens
[17:36] that come from RLHF models compared to SFT models,
[17:39] compared to base model that is prompted to be an assistant.
[17:42] And so it just works better.
[17:44] But you might ask why?
[17:46] Why does it work better?
[17:47] And I don't think that there's a single,
[17:48] like amazing answer that the community
[17:50] has really agreed on.
[17:51] But I will just offer one reason potentially.
[17:55] And it has to do with the asymmetry
[17:57] between how easy computationally it
[17:59] is to compare versus generate.
[18:02] So let's take an example of generating a haiku.
[18:05] Suppose I ask a model to write a haiku about paper clips.
[18:08] If you're a contractor trying to give train data,
[18:10] then imagine being a contractor collecting basically
[18:12] data for the SFD stage.
[18:14] How are you supposed to create a nice haiku
[18:16] for a paper clip?
[18:16] You might just not be very good at that.
[18:18] But if I give you a few examples of haikus,
[18:20] you might be able to appreciate some of these haikus
[18:22] a lot more than others.
[18:24] And so judging which one of these is good
[18:25] is much easier task.
[18:27] And so basically this asymmetry makes it
[18:29] so that comparisons are a better way
[18:32] to potentially leverage yourself as a human
[18:34] and your judgment to create a slightly better model.
[18:38] Now our LHF models are not strictly
[18:41] an improvement on the base models in some cases.
[18:43] So in particular we'd notice for example
[18:45] that they lose some entropy.
[18:46] So that means that they give more PT results.
[18:49] They can output lower variations,
[18:52] like they can output samples with lower variation
[18:55] than the base model.
[18:56] So base model has lots of entropy
[18:57] and will give lots of diverse outputs.
[19:00] So for example, one kind of place
[19:02] where I still prefer to use a base model
[19:05] is in a setup where you basically have n things
[19:10] and you want to generate more things like it.
[19:13] And so here is an example that I just cooked up.
[19:16] I want to generate cool Pokemon names.
[19:18] I gave it seven Pokemon names, and I asked the base model to complete the document,
[19:22] and it gave me a lot more Pokemon names.
[19:24] These are fictitious.
[19:25] I tried to look them up.
[19:27] I don't believe they're actual Pokemons, and this is the kind of task that I think
[19:30] base model would be good at, because it still has lots of entropy, and will give
[19:33] you lots of diverse, cool kind of more things that look like whatever you give it before.
[19:40] So this is what, this is the number, having said all that, these are kind of like
[19:44] the Assistant models that are probably available to you at this point.
[19:47] There's a team at Berkeley that ranked a lot of the available assistant models and gave
[19:51] them basically ELO ratings.
[19:53] So currently some of the best models, of course, are GPT4 by far, I would say, followed by
[19:57] Claude, GPT3.5, and then a number of models, some of these might be available as weights
[20:02] like the Kuna, Koala, et cetera.
[20:05] And the first three rows here are all RLHF models, and all of the other models
[20:10] to my knowledge are SFD models, I believe.
[20:15] Okay.
[20:16] So that's how we train these models on a high level.
[20:19] Now I'm going to switch gears, and let's look at how we can best apply a GPT-assistant model
[20:25] to your problems.
[20:26] Now I would like to work in a setting of a concrete example.
[20:30] So let's work with a concrete example here.
[20:33] Let's say that you are working on an article or a blog post, and you're going to write
[20:36] this sentence at the end.
[20:39] California's population is 53 times that of Alaska.
[20:41] So for some reason, you want to compare the populations of these two states.
[20:45] Think about the rich internal monologue and tool use and how much work actually goes computationally
[20:50] in your brain to generate this one final sentence.
[20:53] So here's maybe what that could look like in your brain.
[20:56] For this next step, let me compare these two populations.
[21:02] First I'm going to obviously need to get both of these populations.
[21:05] Now I know that I probably don't know these populations off the top of my head.
[21:09] So I'm kind of like aware of what I know or don't know of my self-knowledge.
[21:13] So I go, I do some tool use, and I go to Wikipedia, and I look up California's population
[21:18] and Alaska's population.
[21:20] Now I know that I should divide the two, but again, I know that dividing 39.2 by 0.74 is
[21:25] very unlikely to succeed.
[21:27] That's not the kind of thing that I can do in my head.
[21:29] And so therefore, I'm going to rely on a calculator.
[21:32] So I'm going to use a calculator, punch it in, and see that the output is roughly
[21:35] 53.
[21:37] And then maybe I do some reflection and sanity checks in my brain.
[21:40] So does 53 make sense?
[21:42] Well, that's quite a large fraction, but California has the most popular state, so maybe that
[21:46] looks okay.
[21:48] So then I have all the information I might need, and now I get to the sort of creative
[21:51] portion of writing.
[21:53] So I might start to write something like California has 53x times greater, and then
[21:57] I think to myself, that's actually like really awkward phrasing.
[22:00] So let me actually delete that, and let me try again.
[22:03] And so as I'm writing, I have this separate process almost inspecting what I'm writing
[22:08] and judging whether it looks good or not.
[22:11] And then maybe I delete, and maybe I reframe it, and then maybe I'm happy with what comes
[22:14] out.
[22:15] So basically, long story short, a ton happens under the hood in terms of your internal monologue
[22:20] when you create sentences like this.
[22:22] But what does a sentence like this look like when we are training a GPT on it?
[22:27] From GPT's perspective, this is just a sequence of tokens.
[22:30] So a GPT, when it's reading or generating these tokens, it just goes chunk, chunk,
[22:35] chunk, chunk, chunk.
[22:36] And each chunk is roughly the same amount of computational work for each token.
[22:40] And these transformers are not very shallow networks, they have about 80 layers of reasoning,
[22:45] but 80 is still not like too much.
[22:47] And so this transformer is going to do its best to imitate, but of course the process
[22:53] here looks very, very different from the process that you took.
[22:56] So in particular, in our final artifacts, in the data set that we create and then
[23:00] eventually feed to LLMs, all of that internal dialogue is completely stripped.
[23:06] And unlike you, the GPT will look at every single token and spend the same amount of
[23:10] compute on every one of them.
[23:12] And so you can't expect it to actually like, well, you can't expect it to do too much work
[23:17] per token.
[23:19] So and also in particular, basically these transformers are just like token simulators.
[23:23] So they don't know what they don't know, like they just imitate the next token.
[23:28] They don't know what they're good at or not good at.
[23:29] They just tried their best to imitate the next token.
[23:32] They don't reflect in the loop.
[23:34] They don't sanity check anything.
[23:35] they don't correct their mistakes along the way by default.
[23:38] They just sample token sequences.
[23:41] They don't have separate inner monologue streams
[23:43] in their head, right?
[23:43] They're evaluating what's happening.
[23:45] Now, they do have some sort of cognitive advantages,
[23:48] I would say, and that is that they do actually
[23:50] have very large fact-based knowledge
[23:52] across a vast number of areas
[23:54] because they have, say, several 10 billion parameters.
[23:57] So that's a lot of storage for a lot of facts.
[24:00] But, and they also, I think, have a relatively large
[24:03] and perfect working memory.
[24:04] So whatever fits into the context window
[24:08] is immediately available to the transformer
[24:10] through its internal self-attention mechanism.
[24:12] And so it's kind of like perfect memory,
[24:15] but it's got a finite size.
[24:16] But the transformer has a very direct access to it.
[24:18] And so it can like losslessly remember anything
[24:21] that is inside its context window.
[24:24] So that's kind of how I would compare those two.
[24:25] And the reason I bring all of this up
[24:27] is because I think to a large extent,
[24:29] prompting is just making up for this sort
[24:32] cognitive difference between these two kind of architectures like our brains
[24:37] here and LLM brains you can look at it that way almost so here's one thing that
[24:43] people found for example works pretty well in practice especially if your tasks
[24:46] require reasoning you can't expect the transformer to make two to do too much
[24:50] reasoning per token and so you have to really spread out the reasoning
[24:54] across more and more tokens so for example you can't give the
[24:57] transformer a very complicated question and expected to get the answer in a
[25:00] single token. There's just not enough time for it. These transformers need tokens to
[25:04] think, quote, unquote, I like to say sometimes. And so this is some of the things that work
[25:08] well. You may, for example, have a few shot prompt that shows the transformer that it
[25:12] should, like, show its work when it's answering the question. And if you give a few examples,
[25:17] the transformer will imitate that template, and it will just end up working out better
[25:22] in terms of its evaluation. Additionally, you can elicit this kind of behavior from
[25:26] the transformer by saying let's think step by step because this conditioned the transformer
[25:31] into sort of like showing its work.
[25:33] And because it kind of snaps into a mode of showing its work, it's going to do less computational
[25:38] work per token, and so it's more likely to succeed as a result because it's making slower
[25:44] reasoning over time.
[25:46] Here's another example.
[25:47] This one is called self-consistency.
[25:50] We saw that we had the ability to start writing, and then if it didn't work out,
[25:54] I can try again, and I can try multiple times and maybe select the one that worked best.
[26:00] So in these kinds of approaches, you may sample not just once, but you may sample multiple
[26:04] times and then have some process for finding the ones that are good and then keeping just
[26:09] those samples or doing a majority vote or something like that.
[26:12] So basically these transformers in the process, as they predict the next token,
[26:16] just like you, they can get unlucky and they could sample a not a very good token
[26:20] and they can go down sort of like a blind alley
[26:22] in terms of reasoning.
[26:24] And so, unlike you, they cannot recover from that.
[26:27] They are stuck with every single token they sample,
[26:29] and so they will continue the sequence
[26:31] even if they even know that this sequence
[26:33] is not gonna work out.
[26:34] So give them the ability to look back, inspect,
[26:37] or try to basically sample around it.
[26:41] Here's one technique also.
[26:42] You could, it turns out that actually,
[26:44] LLMs, like they know when they've screwed up.
[26:47] So as an example.
[26:49] Say you ask the model to generate a poem that does not rhyme.
[26:53] And it might give you a poem, but it actually rhymes.
[26:56] But it turns out that especially for the bigger models
[26:57] like GPT-4, you can just ask it, did you meet the assignment?
[27:01] And actually, GPT-4 knows very well
[27:03] that it did not meet the assignment.
[27:04] It just kind of got unlucky in its sampling.
[27:06] And so it will tell you, no, I didn't actually
[27:08] meet the assignment.
[27:09] Let me try again.
[27:11] But without you prompting it, it doesn't know
[27:15] to revisit and so on.
[27:18] So you have to make up for that in your prompts.
[27:20] You have to get it to check.
[27:22] If you don't ask it to check, it's not going to check by
[27:23] itself, it's just a token simulator.
[27:29] I think more generally a lot of these techniques fall into
[27:31] the bucket of what I would say, recreating our system 2.
[27:34] So you might be familiar with the system 1, system 2
[27:36] thinking for humans.
[27:38] System 1 is a fast, automatic process.
[27:40] And I think kind of corresponds to like an LLM
[27:42] just sampling tokens.
[27:43] And system 2 is the slower, deliberate, planning sort of
[27:47] part of your brain.
[27:49] And so this is a paper actually from just last week
[27:51] because this space is pretty quickly evolving.
[27:53] It's called Tree of Thought.
[27:55] And in Tree of Thought, the authors of this paper
[27:58] propose maintaining multiple completions
[28:00] for any given prompt.
[28:02] And then they are also scoring them along the way
[28:05] and keeping the ones that are going well, if that
[28:07] makes sense.
[28:08] And so a lot of people are really
[28:10] playing around with prompt engineering
[28:13] to basically bring back some of these abilities
[28:16] that we sort of have in our brain for LLMs.
[28:19] Now, one thing I would like to note here
[28:21] is that this is not just a prompt.
[28:22] This is actually prompts that are together
[28:25] used with some Python glue code because you don't,
[28:28] you actually have to maintain multiple prompts
[28:30] and you also have to do some tree search algorithm here
[28:32] to like figure out which prompt to expand, et cetera.
[28:35] So it's a symbiosis of Python glue code
[28:37] and individual prompts that are called in a Y loop
[28:40] or in a bigger algorithm.
[28:42] I also think that there's a really cool parallel
[28:44] here to AlphaGo.
[28:45] AlphaGo has a policy for placing the next stone
[28:47] when it plays go.
[28:49] And this policy was trained originally by imitating humans.
[28:52] But in addition to this policy, it also does
[28:55] multi-carrelar tree search.
[28:56] And basically, it will play out a number of possibilities
[28:58] in its head and evaluate all of them
[29:00] and only keep the ones that work well.
[29:01] And so I think this is kind of an equivalent of AlphaGo
[29:05] but for text, if that makes sense.
[29:08] So just like tree of thought, I think more generally
[29:11] people are starting to really explore
[29:13] more general techniques of not just the simple question answer prompts, but something that
[29:18] looks a lot more like Python glue code stringing together many prompts.
[29:22] So on the right, I have an example from this paper called React, where they structure
[29:26] the answer to a prompt as a sequence of thought, action, observation, thought, action, observation,
[29:34] and it's a full rollout, kind of a thinking process to answer the query.
[29:38] And in these actions, the model is also allowed to tool use.
[29:42] On the left, I have an example of auto-GPT, and now auto-GPT, by the way, is a project
[29:48] that I think got a lot of hype recently, but I think I still find it kind of inspirationally
[29:54] interesting.
[29:55] It's a project that allows an LLM to keep task list and continue to recursively break
[30:01] down tasks, and I don't think this currently works very well, and I would not advise
[30:04] people to use it in practical applications.
[30:07] I just think it's something to generally take inspiration from in terms of where
[30:09] this is going, I think, over time.
[30:13] So that's kind of like giving our model system to thinking.
[30:16] The next thing that I find kind of interesting is this following sort of, I would say, almost
[30:21] psychological quirk of LLMs is that LLMs don't want to succeed.
[30:26] They want to imitate.
[30:28] You want to succeed, and you should ask for it.
[30:31] So what I mean by that is when transformers are trained, they have training sets,
[30:36] And there can be an entire spectrum of performance qualities in their training data.
[30:41] So for example, there could be some kind of a prompt for some physics question or something
[30:44] like that.
[30:45] And there could be a student solution that is completely wrong, but there can also
[30:48] be an expert answer that is extremely right.
[30:51] And transformers can't tell the difference between like low, I mean, they know about
[30:55] low quality solutions and high quality solutions, but by default, they want to imitate all
[30:59] of it because they're just trained on language modeling.
[31:02] And so at test time, you actually have to ask for a good performance.
[31:06] So in this example, in this paper, they tried various prompts, and let's think step-by-step
[31:12] was very powerful because it's sort of spread out the reasoning over many tokens.
[31:15] But what worked even better is let's work this out in a step-by-step way to be sure we
[31:19] have the right answer.
[31:21] And so it's kind of like conditioning on getting a right answer, and this actually
[31:24] makes the transformer work better because the transformer doesn't have to now hedge
[31:28] its probability mass on low-quality solutions, as ridiculous as that sounds.
[31:33] And so basically, feel free to ask for a strong solution, say something like, you are a leading
[31:38] expert on this topic, pretend you have IQ 120, et cetera.
[31:42] But don't try to ask for too much IQ, because if you ask for an IQ of like 400, you might
[31:46] be out of data distribution.
[31:48] Or even worse, you could be in data distribution for some sci-fi stuff, and it will start
[31:53] to take on some sci-fi role-playing or something like that.
[31:57] So you have to find the right amount of IQ, I think it's got some U-shaped curve there.
[32:03] Next up, as we saw, when we are trying to solve problems, we know what we are good at
[32:08] and what we're not good at, and we lean on tools computationally.
[32:12] You want to do the same potentially with your LLMs.
[32:15] So in particular, we may want to give them calculators, code interpreters, and so on,
[32:22] the ability to do search, and there's a lot of techniques for doing that.
[32:27] One thing to keep in mind, again, is that these transformers by default may not know
[32:31] what they don't know.
[32:33] So you may even want to tell the transformer in a prompt, you are not very good at mental
[32:36] arithmetic.
[32:37] Whenever you need to do very large number addition, multiplication or whatever, instead use
[32:41] this calculator.
[32:42] Here's how you use the calculator.
[32:43] Use this token combination, et cetera, et cetera.
[32:46] So you have to actually spell it out, because the model by default doesn't know
[32:49] what it's good at or not good at necessarily,
[32:51] just like you and I might be.
[32:55] Next up, I think something that is very interesting
[32:57] is we went from a world that was retrieval-only,
[33:01] all the way, the pendulum has swung to the other extreme
[33:03] where it's memory-only in LLMs.
[33:06] But actually there's this entire space in between
[33:08] of these retrieval augmented models
[33:10] and this works extremely well in practice.
[33:13] As I mentioned, the context window of a transformer
[33:15] is it's working memory.
[33:17] If you can load the working memory
[33:18] with any information that is relevant to the task,
[33:21] the model will work extremely well
[33:23] because it can immediately access all that memory.
[33:26] And so I think a lot of people are really interested
[33:28] in basically retrieval augmented generation.
[33:33] And on the bottom I have like an example of Lama index
[33:35] which is one sort of data connector
[33:37] to lots of different types of data
[33:38] and you can index all of that data
[33:42] and you can make it accessible to LLMs.
[33:44] And the emerging recipe there is
[33:46] you take relevant documents,
[33:47] you split them up into chunks, you embed all of them,
[33:50] and you basically get embedding vectors
[33:52] that represent that data.
[33:53] You store that in the vector store,
[33:55] and then at test time, you make some kind of a query
[33:57] to your vector store, and you fetch chunks
[33:59] that might be relevant to your task,
[34:01] and you stuff them into the prompt,
[34:03] and then you generate.
[34:04] So this can work quite well in practice.
[34:06] So this is, I think, similar to when you and I
[34:08] solve problems, you can do everything from your memory,
[34:11] and transformers have very large and extensive memory,
[34:13] but also it really helps to reference
[34:16] some primary documents.
[34:17] So whenever you find yourself going back to a textbook
[34:20] to find something, or whenever you find yourself going back
[34:22] to documentation of a library to look something up,
[34:24] the transformers definitely want to do that too.
[34:27] You have some memory over how some documentation
[34:31] of a library works, but it's much better to look it up.
[34:33] So the same applies here.
[34:37] Next, I wanted to briefly talk about constraint prompting.
[34:39] I also find this very interesting.
[34:42] This is basically techniques for forcing a certain template
[34:48] in the outputs of LLMs.
[34:50] So guidance is one example from Microsoft, actually.
[34:53] And here we are enforcing that the output from the LLM
[34:56] will be JSON.
[34:57] And this will actually guarantee
[34:59] that the output will take on this form
[35:01] because they go in and they mess
[35:02] with the probabilities of all the different tokens that
[35:04] come out of the transformer, and they clamp those tokens.
[35:07] And then the transformer is only
[35:08] filling in the blanks here.
[35:09] And then you can enforce additional restrictions
[35:11] on what could go into those blanks.
[35:13] So this might be really helpful,
[35:14] and I think this kind of constraint sampling
[35:16] is also extremely interesting.
[35:20] I also wanted to say a few words about fine-tuning.
[35:22] It is the case that you can get really far
[35:24] with prompt engineering,
[35:26] but it's also possible to think about fine-tuning
[35:28] your models.
[35:29] Now, fine-tuning models means that you are actually
[35:31] going to change the weights of the model.
[35:34] It is becoming a lot more accessible
[35:35] to do this in practice,
[35:37] and that's because of a number of techniques
[35:39] that have been developed and have libraries
[35:41] for very recently.
[35:43] So for example, parameter-efficient fine-tuning techniques
[35:45] like Laura, make sure that you're only training
[35:48] small sparse pieces of your model.
[35:51] So most of the model is kept clamped at the base model,
[35:53] and some pieces of it are allowed to change,
[35:56] and this still works pretty well empirically,
[35:58] and makes it much cheaper to sort of tune
[36:00] only small pieces of your model.
[36:03] It also means that because most of your model is clamped,
[36:05] you can use very low precision inference
[36:07] for computing those parts,
[36:09] because they are not gonna be updated
[36:10] by gradient descent,
[36:11] And so that makes everything a lot more efficient as well.
[36:14] And in addition, we have a number of open sourced
[36:16] high-quality-based models.
[36:17] Currently, as I mentioned, I think Lama is quite nice,
[36:20] although it is not commercially licensed,
[36:22] I believe right now.
[36:24] Something to keep in mind is that basically,
[36:26] fine-tuning is a lot more technically involved.
[36:29] It requires a lot more, I think,
[36:30] technical expertise to do right.
[36:32] It requires human data contractors for data sets
[36:35] and or synthetic data pipelines
[36:37] that can be pretty complicated.
[36:38] This will definitely slow down
[36:40] your iteration cycle by a lot. And I would say on a high level, SFD is achievable because
[36:45] it is just your continuing language modeling task. It's relatively straightforward. But
[36:50] RLHF, I would say, is very much research territory and is even much harder to get to work. And
[36:56] so I would probably not advise that someone just tries to roll their own RLHF implementation.
[37:00] These things are pretty unstable, very difficult to train, not something that is I think
[37:04] very beginner-friendly right now. And it's also potentially likely also to change
[37:09] pretty rapidly still.
[37:12] So I think these are my sort of default recommendations right now.
[37:15] I would break up your task into two major parts.
[37:18] Number one, achieve your top performance, and number two, optimize your performance in
[37:22] that order.
[37:24] Number one, the best performance will currently come from GPD4 model.
[37:27] It is the most capable model by far.
[37:30] Use prompts that are very detailed.
[37:32] They have lots of task contents, relevant information and instructions.
[37:36] along the lines of what would you tell a task contractor if they can't email you back,
[37:40] but then also keep in mind that a task contractor is a human and they have inner monologue and
[37:44] they're very clever, et cetera, LLMs do not possess those qualities.
[37:48] So make sure to think through the psychology of the LLM almost and cater prompts to that.
[37:55] Retrieve and add any relevant context and information to these prompts.
[38:00] Basically refer to a lot of the prompt engineering techniques.
[38:03] Some of them I've highlighted in the slides above, but also this is a very large space
[38:07] and I would just advise you to look for prompt engineering techniques online.
[38:11] There's a lot to cover there.
[38:14] Experiment with few-shot examples.
[38:15] What this refers to is you don't just want to tell, you want to show whenever it's possible.
[38:20] So give it examples of everything that helps you really understand what you mean if
[38:23] you can.
[38:26] Experiment with tools and plugins to offload a task that are difficult for LLMs natively
[38:31] And then think about not just a single prompt and answer, think about potential chains and
[38:35] reflection and how you glue them together and how you could potentially make multiple samples
[38:39] and so on.
[38:40] Finally, if you think you've squeezed out prompt engineering, which I think you should
[38:44] stick with for a while, look at some potentially fine-tuning a model to your application
[38:51] but expect this to be a lot more slower and involved.
[38:54] And then there's an expert fragile research zone here and I would say that is RLHF
[38:58] which currently does work a bit better than SFT
[39:01] if you can get it to work,
[39:02] but again, this is pretty involved, I would say.
[39:05] And to optimize your costs,
[39:06] try to explore lower capacity models
[39:09] or shorter prompts and so on.
[39:13] I also wanted to say a few words about the use cases
[39:15] in which I think LLMs are currently well suited for.
[39:18] So in particular,
[39:19] note that there's a large number of limitations
[39:21] to LLMs today,
[39:22] and so I would keep that definitely in mind
[39:25] for all your applications.
[39:26] Models, and this, by the way,
[39:27] could be an entire talk,
[39:28] So I don't have time to cover it in full detail.
[39:30] Models may be biased.
[39:32] They may fabricate hallucinate information.
[39:34] They may have reasoning errors.
[39:35] They may struggle in entire classes of applications.
[39:38] They have knowledge cutoffs, so they might not know
[39:41] any information above, say, September 2021.
[39:44] They are susceptible to a large range of attacks
[39:46] which are sort of like coming out on Twitter daily,
[39:48] including prompt injection, jailbreak attacks,
[39:51] data poisoning attacks, and so on.
[39:53] So my recommendation right now is use LLMs
[39:55] in low stakes applications,
[39:57] combine them with always with human oversight,
[40:00] use them as a source of inspiration and suggestions
[40:03] and think co-pilots instead of completely autonomous agents
[40:05] that are just like performing a task somewhere.
[40:08] It's just not clear that the models are there right now.
[40:12] So I wanted to close by saying that GPT-4
[40:14] is an amazing artifact.
[40:15] I'm very thankful that it exists and it's beautiful.
[40:18] It has a ton of knowledge across so many areas.
[40:20] It can do math, code, and so on.
[40:23] And in addition, there's this thriving ecosystem
[40:25] of everything else that is being built
[40:27] and incorporate it into the ecosystem.
[40:29] Some of these things I've talked about.
[40:32] And all of this power is accessible at your fingertips.
[40:35] So here's everything that's needed in terms of code
[40:38] to ask GPT-4 a question, to prompt it and get a response.
[40:42] In this case, I said, can you say something
[40:45] to inspire the audience of Microsoft Build 2023?
[40:48] And I just punched this into Python
[40:49] and verbatim, GPT-4 said the following.
[40:54] And by the way, I did not know
[40:55] that they used this trick in the keynote.
[40:57] So I thought I was being clever, but it is really good at this.
[41:02] It says, ladies and gentlemen, innovators and trailblazers
[41:05] of Microsoft Build 2023, welcome
[41:07] to the gathering of brilliant minds like no other.
[41:10] You are the architects of the future,
[41:11] the visionaries molding the digital realm in which
[41:14] humanity thrives.
[41:15] Embrace the limitless possibilities of technologies
[41:18] and let your ideas soar as high as your imagination.
[41:20] Together, let's create a more connected, remarkable,
[41:23] an inclusive world for generations to come,
[41:25] get ready to unleash your creativity,
[41:27] canvass the unknown, and turn dreams into reality.
[41:30] Your journey begins today.
[41:33] Thank you.