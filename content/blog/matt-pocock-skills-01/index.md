---
title: "解构 Matt Pocock 的 Skills（一）：给跨会话 Agent 建一张项目地图"
date: 2026-11-11
description: "从跨会话信息接力出发，解构 Matt Pocock 的项目地图、任务分流和领域文档。"
tags: [AI, Agent]
slug: matt-pocock-skills-01
draft: false
series: [Matt Pocock Skills]
series_weight: 1
---

> 本文结合智能体第一性原理，解构 Matt Pocock 的 Skills 实践；主要参考 [AI Skills with Matt Pocock 播客](https://www.youtube.com/watch?v=4DhcSPkEbwI)及 [Skills 项目（本文所用版本）](https://github.com/mattpocock/skills/tree/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d)。

---

### 引言：《记忆碎片》式开发与 150k 智能区高墙

在克里斯托弗·诺兰的经典悬疑电影《记忆碎片》（*Memento*）中，男主角 Leonard 患有一种罕见的顺行性遗忘症：他的长期记忆永远停留在过去，任何新产生的记忆都无法维持超过几分钟。
每天清晨醒来，他不记得昨天抓到了什么线索，不记得谁是可以信任的朋友，甚至不记得自己身处何方。
为了在这片记忆废墟中追凶，他被迫建立了一套极度冷酷的生存工程：把最关键的目标用刺青刻在皮肉上，把关键人物与地点拍成带注释的宝丽来相片，把未竟的线索整齐塞在风衣口袋里。

大语言模型驱动的 Coding Agent，在物理现实中与 Leonard 遭遇了**完全相同的顺行性遗忘**：

我们在《第一篇》与《第六篇》中反复论证过：模型的本质是一个无状态的算力核心。当一次会话结束、连接关闭、显存释放，刚刚跑完的上下文窗口（Context）工作台瞬间蒸发。大模型的参数权重 $\theta$ 在物理上绝对冻结。
**无论前一天你和它把系统架构推演得多么精妙，当下一次会话启动时，它面对的依然是一张没有任何昨天记忆的纯白稿纸。**

面对这种失忆，许多团队的第一反应是：“那就把昨天的全部聊天记录和项目历史全倒灌进系统提示词，或者挂一个向量数据库！”

但现实工程很快会撞上一堵冷酷的物理高墙——**150k Token 智能区（Smart Zone）定律**。

资深 AI 工程师 Dex Hunter-Halsey 曾提出一个被一线实践反复验证的洞察：
无论基础模型对外宣称自己的上下文窗口是 100 万还是 200 万 Token，其最高水准的推理与决策“智能区”，**在物理上往往被局限在最初的 150k Token 左右**。
超过这个阈值，塞入 Context 的每一个 Token 都在大声争夺自注意力权重（Self-Attention）。上下文中的声音越多，核心指令的信噪比衰减越严重。模型在长程依赖的迷雾中开始丢三落四、产生误读，迅速滑入错误频发的“迟钝区”。

```
Context 窗口规模：
[  0k ~ 150k  ] ───> 【黄金智能区 (Smart Zone)】：信噪比高，逻辑推演锋利，严格遵循指令
[ 150k ~ 1000k ] ───> 【注意力衰减区 (Dumb Zone)】：Token 争夺权重，幻觉丛生，上下文残骸严重
```

然而，一个真实的现代工业级软件开发任务，往往涉及数十万行代码、多轮架构权衡与数天的跨周期推进，总消耗往往达数百万 Token。**它在物理上绝不可能塞进单一的 Context 窗口内解决。**

人类资深工程师面对一个混乱庞大的代码库，可以靠肉身连续碰壁几个月，在生物大脑中硬熬出对代码的直觉与经验；
但 Agent 不能。它每次上线都是一个全新入职、带着顶级通用智商、却对本项目一无所知的新员工。

TypeScript 领域权威专家 Matt Pocock 在接受 The Pragmatic Engineer 播客深度访谈（谈及其风靡开源界、超 30 万 Star 的 [Skills 库](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/README.md) 哲学）时，给出了一个极富穿透力的定性：
> **“我们是在进行《记忆碎片》式开发（Memento-driven Development）。正因为 Agent 每天早晨醒来都会彻底失忆，我们才必须将代码库优化成对一个完全失忆的新人极端友好的工坊。”**

如果 Agent 无法保存会话内的脑突触记忆，那么项目的所有长期状态就必须**物理外化**。
Matt 在其技能库中设计的第一个工程动作——[`setup-matt-pocock-skills`](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/setup-matt-pocock-skills/SKILL.md)，正是为了给这位每天失忆的工匠，在走进工坊的第 0 步，递上一张精炼、保真且带指针的项目地图。

---

### 一、 拒绝“流程全包型黑盒”：为什么初始化只立三根路标？

在当前的智能体开发工具生态中，存在着一股危险的“全包型（All-in-one）”风潮。
诸如 GSD（Get Shit Done）、BMAD、Spec-Kit 等框架，往往试图接管整个开发流程：在项目里塞入极其繁琐的步骤模板，强制 Agent 按照预设的 Python 状态机一步一步向下走。

Matt 在其项目说明 [`README.md`](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/README.md) 开篇便旗帜鲜明地与这种做法划清界限：
> **“Approaches like GSD, BMAD, and Spec-Kit try to help by owning the process. But while doing so, they take away your control and make bugs in the process hard to resolve.”**
> （那些试图‘接管流程’的方法，剥夺了工程师的控制权；一旦流程本身发生卡死或偏差，在重重黑盒之下极难调试与修复。）

Matt 坚持的设计哲学是：**Small, easy to adapt, and composable（小巧、极易修改、自由组合）**。
这一思想在它的初始化技能 [`setup-matt-pocock-skills`](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/setup-matt-pocock-skills/SKILL.md) 中体现得淋漓尽致。

当你把这套技能引入项目并运行 `/setup-matt-pocock-skills` 时，它不会大动干戈地自动生成几万字的虚假项目百科，也不会往代码库里植入笨重的自动化运行时。它所做的，仅仅是探索当前代码库现状，并在与维护者快速对账后，在项目的 `CLAUDE.md` 或 `AGENTS.md` 顶层，挂载三根极轻量的物理指针：

```markdown
## Agent skills

### Issue tracker
[简要说明任务在何处跟踪]. See `docs/agents/issue-tracker.md`.

### Triage labels
[简要说明标签词汇映射]. See `docs/agents/triage-labels.md`.

### Domain docs
[简要说明单上下文或多上下文布局]. See `docs/agents/domain.md`.
```

这三根指针分别指向三个极简的 Markdown 契约文件：
1. **`docs/agents/issue-tracker.md`（任务跟踪器指针）**：告诉 Agent 任务存放在何处（GitHub Issues、GitLab、还是本地 `.scratch/<feature>/` Markdown 文件），以及后续使用什么 CLI 工具（`gh`、`glab`）去读写；
2. **`docs/agents/triage-labels.md`（分流标签词汇表）**：定义任务在流转时所使用的状态标记，统一映射到五个标准角色；
3. **`docs/agents/domain.md`（领域文档布局）**：约定项目的领域术语表（`GLOSSARY.md`）和架构决策记录（`docs/adr/`）放在哪里，以及 Agent 读取它们时的行为公约。

表面上看，这不过是一次简单的脚手架配置。但如果代入我们在《数学基石篇》确立的核心基石——**信息完备性方程**：

$$
I_{\text{初始前馈}} + \sum_{k=1}^n \Delta I_{\text{反馈}, k} \ge I_{\text{目标}}
$$

其背后的系统动力学一目了然：
**这三项配置并非某种特定工具的私有偏好，而是将新任务启动时最急需的三笔外源前馈（$I_{\text{前馈}}$），精准锚定在物理环境中：**
* 任务目标与上下文差额存放在哪里？（Issue Tracker）
* 当前待办处于决策流向的哪一环？（Triage Labels）
* 项目独特的私有词汇与不可撤销的架构红线是什么？（Domain Docs）

新会话启动时，Agent 不需要预先将几千行文档一口气全吞进肚子里，而是顺着 `AGENTS.md` 顶层的这三行轻量索引，在需要攻关具体环节时，才精准将对应片区的上下文按需换入（Paging）。

---

### 二、 Issue Tracker：把“还有什么没做完”持久化在领土上

我们在《第六篇》中剖析过未来决策真正需要、而未来环境又无法廉价恢复的“五类终极内容”，其中至关重要的一类是：**“还有什么没做完（前瞻承诺与未竟状态）”**。

代码库本身的 Git 提交记录和源码，是客观世界的**既成领土**。代码能极其忠实地告诉 Agent“当前系统由什么构成”，却**完全无法表达“系统缺失了什么”、“用户报告了什么 Bug”、“哪些需求还在讨论中”**。
这些关于“未竟目标”的信息，如果只留在昨天那个已经关闭的会话窗口里，就会随着显存释放彻底蒸发。

Matt 的体系强制要求先确定 Issue Tracker，其力学本质就在于：**把动态的工作状态从易失的内源思维中彻底抽离，持久化在外部物理看板上。**

但这里立刻引出一个致命的工程问题：
**如果一个复杂的生产 Bug 已经在 GitHub Issue 上讨论了 40 多条评论，夹杂着初期的错误排查、用户的临时补充截屏和维护者的多次否决，第二天换了一个全新的 Agent，它该如何阅读这条 Issue？**

如果让新 Agent 把这 40 多条闲聊与猜测全量读进 Context，它不仅要白白支付巨大的 Token 费用，而且极容易被早期已被推翻的错误猜测所误导，甚至重蹈覆辙。

为此，Matt 的 `triage`（分流与分拣）技能提供了一套极其精彩的工程转译动作：**编写 Agent Brief**。

---

### 三、 Agent Brief：承接“白班与夜班”的耐用性契约

在 Matt 的工作流设想中，人类与 Agent 之间存在着一种极其高效的异步节奏——**白班与夜班（Day Shift and Night Shift）**：
* **白班（人机协同对齐）**：人类维护者坐在屏幕前，与 Agent 展开深度讨论，澄清模糊需求，排除伪因果，完成高维度的系统规划；
* **夜班（AFK 无人值守执行）**：当需求被彻底固化后，人类离开键盘（Away From Keyboard）。调度器为后续任务启动一个干净、独立的子上下文窗口，让执行 Agent 独自打磨代码、运行测试套件，直到早晨交由人类验收。

连接“白班规划”与“夜班实施”的桥梁，就是由 `triage` 技能输出的标准化规格说明——**Agent Brief**。

#### 1. 工程实现全貌：输入、动作、产物与后续使用
为了确保这套机制不是空中楼阁，我们必须严格顺着它的真实工程调用链条走一遍：

1. **触发与读取（Gather Context）**：维护者在对话中发起 `/triage` 指令，指定查看某条具体问题（如 Issue #42）。`triage` 技能调用 `gh issue view 42 --comments` 抓取原始正文与全部历史讨论（若按配置使用本地 Markdown 看板，则读取 `.scratch/` 对应文件），并结合代码库尝试本地复现该 Bug；
2. **核实与对账（Verify & Grill）**：若关键复现步骤缺失，Agent 将状态置为等待用户补充；若需求范围模糊，现场调用 `grilling` 技能与维护者逐项核对边界；
3. **写入产物（Post Agent Brief）**：一旦方案在现场彻底收敛，Agent **绝不另起炉灶新建 Issue，而是直接在当前原始 Issue 下方，调用 CLI 追加发布一条结构化的 Markdown 评论**！
   这条评论顶部带有强制免责标识：
   ```markdown
   > *This was generated by AI during triage.*
   ```
   随后，技能调用 `gh issue edit 42 --add-label "ready-for-agent"` 将任务打上就绪标签；
4. **后续消费（Downstream Consumption）**：夜班的实施 Agent 启动后，先通过 `gh issue list --label ready-for-agent` 检索候选清单。接手任务时，它**首先读取这条高密度的 Agent Brief 评论作为实施前馈**，无需重新阅读之前的数十轮漫长拉扯；如果对某个历史动机产生怀疑，它依然可以向上翻阅原 Issue 的第一手报错日志与用户截图。

#### 2. Agent Brief 的设计铁律：耐用性压倒精确度（Durability over Precision）
仔细研读 Matt 编写的 [`AGENT-BRIEF.md`](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/triage/AGENT-BRIEF.md) 规范，里面包含了一条极具穿透力、反直觉的软件工程铁律：

> **“Durability over precision: The issue may sit in `ready-for-agent` for days or weeks. The codebase will change in the meantime. Don't reference file paths; don't reference line numbers.”**
> （耐用性重于精确度：这条 Issue 可能会在看板里静置数天甚至数周。在此期间，代码库随时会被其他提交重命名或重构。**绝不要在 Brief 里引用具体的文件路径，绝不要引用具体的代码行号！**）

绝大多数平庸的 AI 工具，都热衷于让模型在任务说明里写下诸如：“*请打开 `src/parser/math.ts` 的第 142 行，在 switch 语句中加一个分支*”。
这种说明看似无比精确，实则极度脆弱。只要中间穿插了一次代码重构或文件移动，这条任务说明瞬间沦为废纸，后续 Agent 照本宣科必然报错。

**Agent Brief 追求的是行为性契约（Behavioral Contract），而非过程性琐碎指令（Procedural Instruction）。**

一个标准的 Agent Brief 评论形态如下（注：Matt Pocock 在官方规范中以“技能描述截断 Bug”与“`--json` 输出 PR 补齐”为例；此处我们结合前端技术博客中常见的移动端 LaTeX 矩阵公式溢出场景，展示一份严格遵循其规范的演示案例）：

```markdown
> *This was generated by AI during triage.*

## Agent Brief

**Category:** bug
**Summary:** 手机视口下宽公式溢出截断，导致右侧内容不可见

**Current behavior:**
当移动端视口宽度小于 480px 且文章包含长 LaTeX 矩阵公式时，公式容器产生硬截断（overflow: hidden），
读者无法滚动查阅超出屏幕右边界的推导内容。

**Desired behavior:**
在保持桌面端渲染排版完全不变的前提下，移动端公式容器应自适应包裹，
并在内容超出视口时提供平滑的水平滚动条（overflow-x: auto），允许手指左右滑动。

**Key interfaces:**
- 负责文章正文渲染的公式容器组件（聚焦其 CSS overflow 与 max-width 边界处理）
- 移动端视口媒体查询样式（保证响应式断点在手机端正确激活）

**Acceptance criteria:**
- [ ] 在 375px 移动端模拟视口下，超出宽度的公式呈现水平滚动条，内容可完整滑动查看
- [ ] 桌面端（视口 > 768px）原有渲染样式与段落行高严格保持像素级不变
- [ ] 自动化测试套件通过，无新增 CSS 控制台警告

**Out of scope:**
- 严禁重构文章排版引擎的底层解析器
- 暂不处理代码块（Code Fence）的溢出逻辑，本次仅限公式容器
```

审视这份 Brief 的结构：
* **当前行为 vs 期望行为**：定义了物理世界的客观偏差；
* **关键接口（Key Interfaces）**：指定关注的核心抽象类型或配置形态，却不锁死在某个具体文件路径，允许实施 Agent 在最新代码库中动态寻找定位；
* **独立可测试的验收条件（Acceptance Criteria）**：给执行者明确的“停止条件”，避免循环空转；
* **显式画出非目标边界（Out of Scope）**：我们在《第二篇》讲过，防止大模型在没有上下文约束时过度发挥、肆意改动无关代码（Gold-plating）。

它将白天人机交互产生的有效反馈 $\Delta I_{\text{准备阶段}}$，高度凝练为下一次夜班任务的**实施前馈（$I_{\text{实施前馈}}$）**——这正是我们在《数学基石篇》中确立的阶段切分推论（$I_{\text{实施前馈}} = I_{\text{初始前馈}} + \sum_{k=1}^\tau \Delta I_{\text{准备阶段}, k}$）在工业流水线上的真实兑现。白班通过连续盘问帮助人类澄清并锁定了目标 $I_{\text{目标}}$，而将 Brief 追加在原 Issue 之后，则彻底对冲了会话交接时的信息损耗，同时杜绝了细节过期带来的脆弱性。

---

### 四、 Triage Labels 状态机：用最小比特撬动下一步决策

如果一个项目积累了上百条 Issue，新会话启动的 Agent 难道要先把每条 Issue 的内容和评论全读一遍，再来挑哪个能做吗？
如果这么做，150k 的黄金智能区在找任务的阶段就会被彻底耗尽。

Matt 的 `triage` 体系定义了五种核心状态角色，并由 `docs/agents/triage-labels.md` 提供映射支持：

```
                 ┌──────────────┐
                 │ needs-triage │ <───────────────┐ (提报者回复)
                 └──────┬───────┘                 │
                        │                         │
         ┌──────────────┼──────────────┬──────────┴───┐
         ▼              ▼              ▼              ▼
   ┌────────────┐ ┌─────────────┐ ┌─────────────┐ ┌─────────┐
   │ needs-info │ │ready-for-   │ │ready-for-   │ │ wontfix │
   │            │ │   agent     │ │   human     │ │         │
   └────────────┘ └─────────────┘ └─────────────┘ └─────────┘
         │              │              │              │
    (等待输入)     (夜班AFK实施)    (人机高危审批)    (沉淀知识库)
```

1. **`needs-triage`（等待分拣）**：新进入环境的未定性状态，需要维护者介入评估；
2. **`needs-info`（等待信息）**：复现步骤不足或条件模糊。此时 Agent 会留下结构化模板（记录“目前已探明了什么”、“还缺提报者补充什么”），避免提报者回复后大家又从零猜起；一旦提报者留言回复，状态自动回流至 `needs-triage`；
3. **`ready-for-agent`（可交由 Agent 独立实施）**：**实施队列的绿色通行证**。该状态由 Agent Brief 严格守护，意味着目标与验收条件已经完备，夜班 AFK Agent 可以闭着眼睛安全接手；
4. **`ready-for-human`（必须由人类处理）**：涉及主观商业审美决策、高危资金与生产权限、或极度微妙的人性权衡，Agent 明确标记自身无法胜任并主动让出方向盘；
5. **`wontfix`（明确不做）**：决定不予实施。如果是重复功能，直接指出已有代码位置；如果是被否决的功能建议，则将其决策理由沉淀至 `.out-of-scope/*.md` 知识库，防止未来重复提报（注：Matt 规范明确规定已实现代码或 Bug 驳回坚决不入该库，保持知识库极高纯度）。

（注：这套状态机同样无缝适用于外部 Pull Request；在 Matt 的定义中，**PR 本质上就是“附带了代码差量的 Issue”**，两者遵循完全相同的角色与流转逻辑。）

从信息论审视，**一枚标签的本质就是一个极低信息熵、高信噪比的状态信号**。
它在工作台的最外侧构筑了一道严密的路由防火墙：后续 Agent 仅需通过 `gh issue list --label ready-for-agent` 执行一次 O(1) 的离散过滤，就能将数十万字无关的历史闲聊阻挡在工作台之外，确保只有确定可执行的目标信息进入宝贵的 Context RAM。

---

### 五、 Domain Docs 与通用语言：击穿大模型的啰嗦与私有语义鸿沟

现在来看初始化配置中的第三项：`docs/agents/domain.md` 所指引的领域文档体系——`GLOSSARY.md`（项目术语表）与 `docs/adr/`（架构决策记录）。

很多工程师会问：大模型本身已经读过海量语料，连最复杂的泛型体操和分布式算法都能倒背如流，为什么在一个几千行的小项目里，还需要给它专门写一份术语表？

Matt 在其实践中遭遇了一个极其痛苦、却极其普遍的模型失败模式：**大模型的啰嗦病与私有语义隔阂（The Verbosity Trap）**。

#### 1. 为什么大模型会变得极其啰嗦？
以 OpenAI 或 Anthropic 的顶尖强模型（如 Claude Opus）为例，它们的内源语言推演能力极度强大。
然而，当一个 Agent 被突然扔进一个特定的垂直项目时，项目内部不可避免地存在大量私有的黑话与业务约定。
大模型为了搞清楚这些词汇，在缺乏定义的情况下，只能凭借通用先验去盲目猜测。

**结果就是：它往往需要花费 20 到 30 个单词，去迂回解释一个在项目中本来一句话就能定性的事实。**
Matt 在开发其课程管理系统 `course-video-manager` 时举过一个生动的真实案例：

> **没有术语表时的模型表达**：
> *“系统现在遇到了一个异常：当课程某个章节内部的某一个教学片段被正式‘实体化’写入本地文件系统目录结构时，其外层的章节与所属课程也必须相应地在物理磁盘上同步创建对应条目……”*
>
> **建立领域术语后的模型表达**：
> *“系统在发生 **级联具象化（materialization cascade）** 时产生了冲突。”*

Matt 敏锐地洞察到：这正是现代软件工程奠基人 Eric Evans 在《领域驱动设计》（DDD）中强调的核心灵魂——**通用语言（Ubiquitous Language）**。

大模型在通识语料上训练得再好，也无法凭空猜出你在某个具体仓库里对“首页”、“发布”或“级联具象化”赋予的特有内涵。
当你在 `GLOSSARY.md` 中为项目确立了通用语言：
1. **击穿沟通带宽税**：人类与 Agent、Agent 与 Agent 之间可以用极简的高维词汇对话，思维链中的无效推演（Token 消耗）呈数量级下降，直接为 150k Smart Zone 腾出宝贵的注意力和算力空间；
2. **代码实体的命名收敛**：代码库中的函数名、变量名、测试用例与业务术语高度咬合，Agent 后续只需通过最简单的 grep 工具，就能沿着术语瞬间定位到核心函数；
3. **唤醒深层模型先验**：一个好的领域专有名词（如 Cascade、Triage、Snapshot），能够直接激活大模型参数矩阵中对于特定经典软件设计模式的深层先验，让代码生成更加严整。

#### 2. `grill-with-docs`：在现场盘问中即时结晶，拒绝死百科
很多团队尝试维护术语表，最终都沦为形式主义弃坑，原因在于：**人类工程师根本不可能脱离具体开发场景，坐在那里凭空编出一本包罗万象的辞海。**

Matt 的解法极其务实——在实战中使用 [`grill-with-docs`](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/grill-with-docs/SKILL.md) 技能。
`grill-with-docs` 实际上是将高强度盘问（`grilling`）与领域建模（`domain-modeling`）组合在一起：
当你在与 Agent 讨论一个具体功能时，一旦 Agent 发现你用了一个模糊或冲突的词，它立刻停下追问：*“你刚才说的‘账户’，究竟是指付费客户（Customer）还是登录操作员（User）？”*
**当场辩清边界的一瞬间，Agent 顺手调用工具，直接将这个术语原地写入 `GLOSSARY.md`！**

知识不是事前预设的僵死教条，而是在每次人机交互的碰撞中**即时结晶（Inline Update）**出来的副产品。

#### 3. 架构决策记录（ADR）：三条严苛的归档门禁
对于 `docs/adr/`，Matt 的规范同样展现出极其冷峻的工程克制。[`domain-modeling`](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/domain-modeling/SKILL.md) 明确规定，**只有同时满足以下三条硬性门禁时，才允许撰写 ADR**：
1. **难以逆转（Hard to reverse）**：推翻这个决定的边际成本非常高昂（如选定底层数据库或核心并发模型）；
2. **脱离背景令人困惑（Surprising without context）**：未来的接手者或新 Agent 看到这段代码，会本能地惊呼“为什么当初要写成这种奇葩结构？”；
3. **真实经历过权衡取舍（The result of a real trade-off）**：当时确实存在方案 A 和方案 B，我们是因为某个具体理由选择了 A 而废弃了 B。

如果任何一条不满足，坚决不写。正如我们在《第六篇》所指出的：**代码库记载了“是什么”，而 ADR 补齐了“为什么不是另一个”。** 缺少了这笔记录，未来的失忆 Agent 在面对相同路口时，极易自作聪明地把前人早就踩过坑的被否决方案重新实现一遍。

---

### 六、 整理层与源头保真：为什么这套轻量地图能穿越时间？

把 Matt Pocock 的这套体系完整解构下来，我们会发现它与我们在《第六篇》中基于 Anthropic 最新研究所推导出的认知力学，呈现出惊人的一致性：

我们在信息论中反复强调过：**整理层与底层源材料承担着完全不同的力学职能。**

| 层级 | 物理代表 | 核心工程职能 | 信息论特征 |
| :--- | :--- | :--- | :--- |
| **客观源材料层**<br>*(Single Source of Truth)* | 原始 Issue 讨论、未篡改的报错截图、Git 历史提交、真实测试退出码 | **绝对保真与溯源对账**。原汁原味，杜绝未经检验的人工主观阉割 | 容量大，保真度 100%，但全量翻查代价高昂 |
| **高密度整理层**<br>*(The Navigation Map)* | `AGENTS.md` 顶层索引、Agent Brief 评论、`GLOSSARY.md`、ADR | **低阻力导航与敏捷行动**。将高频共识、行为契约与模块指针收拢在工作台前 | 高信噪比，在第 0 步垫高起跳点，保护 150k 智能区 |

正如 Anthropic 在其记忆研究（针对 Stainless 语料库 35 万份文档、约 4.2 亿 Token）中所给出的铁证：
单纯依赖底层关键词暴搜，准确率仅为 **53%**；单纯依赖上层 Wiki 摘要，准确率为 **48%**；
而**当 Agent 顺着 Wiki 导航图锁定概念指针、再针对性搜索底层原件时，准确率直接跃升至 61%，且每道题平均节省了约 20,000 个推理 Token！**

市面上的独立 Memory 框架之所以走向死胡同，是因为它们妄图在中间搞一套黑盒机制，把源材料草率压缩成不可溯源的死结论，最终导致工业废水倒灌工作台；
而 Matt Pocock 的 Skills 库之所以能在工业实战中爆发生命力，是因为它在工程一线完美兑现了上述力学分工，**完全尊重计算机与模型的物理现实**：

1. **地图绝不替代领土**：`docs/agents/` 里的配置文件极其轻量，它只给 Agent 指明去哪里调阅 GitHub、去哪里查阅术语，而不是把所有历史数据强行抄写一遍；
2. **整理绝不抹杀源头**：Agent Brief 作为评论追加在原 Issue 之后，原有的几十条真实讨论与报错截屏依然完好躺在上方，随时供未来 Agent 进行下潜对账；
3. **契约保持极高耐用性**：以行为边界取代具体行号，使得规划成果能够坦然跨越数周的时间跨度，在代码演化中屹立不倒。

---

### 结语：为“失忆者”建造一座清晰的工坊

回顾这场对跨会话 Agent 的解构：
大模型在物理时间上的“顺行性失忆”和在空间尺寸上的“150k 智能区衰减”，并不是系统可以通过念咒或者套壳魔法抹除的缺陷，而是现代生成式模型的内生力学边界。

既然模型注定是每天早晨醒来就失去记忆的 Leonard，那么软件工程的责任，就绝不是假装它拥有生物大脑，而是为这位每天按时到岗的顶级无状态工匠，打造一座井井有条的工坊：
* 在工坊门口（`AGENTS.md`），立起三张指向明确的路标；
* 在任务看板上（Issue Tracker），用耐用的 Agent Brief 交代清楚进退边界；
* 在公约墙上（`GLOSSARY.md` 与 ADR），用确定性的领域语言扫清理解迷雾。

当一个失忆的 Agent 走进这样的工坊，即使它的脑海中空无一物，它也能在第 0 步迅速抓起工具，严谨、可预测、充满底气地开始今天的劳作。

而当一项新任务刚刚进入工坊，但人类自身的真实意图依然模糊、甚至自己都说不清楚想要什么时，系统又该如何应对？
在下一篇中，我们将深入解构 Matt Pocock 最负盛名、最具侵略性的核心技能——**`grill-me` 与 `grilling` 机制，看智能体如何通过连环盘问，把摇摆不定的人类意图连根拔起。**

---

### 参考资料

本文从本系列的信息完备性方程阶段切分、跨任务信噪比衰减及整理层与源头保真理论出发，参考以下核心项目规范、工程代码与研究讨论：

- [Matt Pocock Skills 项目说明](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/README.md)（GitHub 超 30 万 Star 技能库官方文档，系统阐述了 Real Engineering 理念与 Coding Agent 四大死穴）
- [setup-matt-pocock-skills 规范](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/setup-matt-pocock-skills/SKILL.md)（工程初始化技能源码，定义了 Issue Tracker、Triage Labels 与 Domain Docs 的交互探测与落盘逻辑）
- [triage 技能规范](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/triage/SKILL.md)（任务状态机分流核心，规范了从评估、核实到派发 Agent 的全生命周期）
- [Writing Agent Briefs 原文](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/triage/AGENT-BRIEF.md)（详细披露了 Durability over Precision 设计哲学与标准化 Brief 契约模版）
- [domain-modeling 规范](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/domain-modeling/SKILL.md)（领域驱动建模与 ADR 三大准入准出红线）
- [grill-with-docs 技能规范](https://github.com/mattpocock/skills/blob/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d/skills/engineering/grill-with-docs/SKILL.md)（高强度人机盘问与领域文档即时结晶机制）
- [AI Skills with Matt Pocock 播客访谈](https://www.youtube.com/watch?v=4DhcSPkEbwI)（The Pragmatic Engineer 播客深度访谈，深入探讨了 Memento 式开发、Dex Hunter-Halsey 的 150k Smart Zone、Eric Evans 的 DDD 通用语言实践及 AFK 执行模式）
- [The components of agent memory](https://www.anthropic.com/research/components-of-agent-memory)（Anthropic 官方研究博文，提供了 Wiki 整理层与原文搜索协同的定量实验基准）
- [记忆是环境的补集，Agent 没有壁垒](https://mp.weixin.qq.com/s/NpxvOj4_kj73Guu0C1wP_g)（老冯云数，剖析客观环境与智能体记忆边界的经典推导）
