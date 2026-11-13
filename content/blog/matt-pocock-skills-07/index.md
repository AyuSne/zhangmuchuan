---
title: "解构 Matt Pocock 的 Skills（八）：换一个 Agent 审查，就真的能看出问题吗？"
date: 2026-11-11
description: "分析独立上下文、双轴审查和审查范围各自的作用与局限。"
tags: [AI, Agent]
slug: matt-pocock-skills-07
draft: false
series: [Matt Pocock Skills]
series_weight: 8
---

> 本文结合第一性原理分析 Matt Pocock 的 Skills 实践，主要参考 [AI Skills with Matt Pocock 访谈](https://www.youtube.com/watch?v=4DhcSPkEbwI)和 [Skills 项目所引用版本](https://github.com/mattpocock/skills/tree/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d)。

### 引子：全对的规范与做错的系统——“确认偏误”的工程破局

在现代软件交付的流水线中，审查（Code Review）始终被视作防御系统缺陷的最后一道闸门。

然而进入大模型编程时代后，很多团队在落地自动代码审查时，常常陷入一种哭笑不得的境地：

> 一位开发者让编写代码的 Agent 在同一个会话里审查自己的产出。Agent 输出了一大篇头头是道的自评：“架构设计优雅、变量命名规范、已严格遵循 DRY 原则。”
>
> 但实际上，代码中隐藏着一个严重的逻辑断裂：用户在工单里明确要求“取消续费后保留到期前权益”，而代码却在取消当下立即将用户状态置为失效。编写者完全沉浸在自己先前的实现假设中，对这个方向性错误视若无睹。

一位开源社区读者对此给出了极其尖锐的评价：
> **“让同一个上下文审查自己写的代码，根本不叫代码审查；那只是披着斜杠命令外衣的确认偏误（Confirmation Bias with a slash command）。”** [来源：`code-review` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)

为了打破这种自欺，Matt Pocock 的 [`/code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 确立了一套经典范式：**强制派发两个完全独立的子 Agent（Sub-agents），在全新的上下文窗口中，分别沿着“编码规范（Standards）”与“需求规格（Spec）”两条正交轴线，对 Git 提交差异进行独立审计。**

这个设计看起来非常严密。但在技术深水区，我们必须追问几个更本质的问题：
- 为什么规范轴与规格轴必须物理隔离，绝对禁止综合打分？
- 换了一个全新的 Agent 会话，是否就意味着它真的拥有了独立的判决能力？如果两个 Agent 底层使用的是同一个基座模型，甚至阅读的是同一份存在歧义的文档，所谓“独立审查”的认知物理上界到底在哪里？
- 为什么实战中代码审查极易陷入“越修越错、永不收敛”的死循环？

本文将作为整个 Matt Pocock Skills 解构系列的终章，用我们既有的信息论、恒温器闭环与 $(P, M, H)$ 协同框架，**系统剖析**大模型自动化代码审查的工程内核与边界底线。

---

### 一、双轴正交架构：为什么绝不把“规范”与“需求”混为一谈？

在传统的人工代码审查中，最常见的人性弱点是“注意力偏移”：审查者往往盯着缩进是否整齐、命名是否符合驼峰命名法挑刺半天，却对整段代码是否跑偏了原始业务目标毫无察觉。

而在大模型的世界里，这种认知偏差被进一步放大：如果让同一个 Agent 同时审查“代码风格”与“业务需求”，模型极易在多任务提示词下顾此失彼。

针对这一顽疾，Matt Pocock 在 [`code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 中构筑了核心防御机制：**双轴正交审查（Dual-Axis Review）**。

![同一份改动分别对照需求和项目规范](images/code-review-two-axes.png)

#### 1. 两把完全独立的尺子
- **Standards 轴（关注“造得对不对”——Is it built right?）**：
  - 核心依据：当前仓库明确记载的规范文件（如 `CODING_STANDARDS.md`、`CONTRIBUTING.md`）。
  - 通用基线：Martin Fowler 在《重构》第三章中定义的 12 项经典代码异味（Smell Baseline），包括神秘命名（Mysterious Name）、重复代码（Duplicated Code）、特性依恋（Feature Envy）、数据泥团（Data Clumps）、基本类型偏执（Primitive Obsession）、发散式变化（Divergent Change）、霰弹式修改（Shotgun Surgery）等。
  - 判定准则：**仓库明文标准具备绝对否决权**；代码异味属于带有语境启发性质的裁决参考（Judgement calls），绝不无端推翻仓库已有规范。
- **Spec 轴（关注“造的是不是对的东西”——Is it the right thing?）**：
  - 核心依据：任务来源工单、Issue 描述或关联的规格说明书（Spec）。
  - 判定范围：严格排查**规格要求的缺失（Missing）**、**未经要求的范围蔓延（Scope Creep）**，以及**表面看似完成但实际语义跑偏的错误实现（Wrong implementation）**。

#### 2. 拒绝折中排序（No Re-ranking）的控制论必然
在审查报告汇总阶段，`code-review` 树立了一条不可逾越的规则：
> **严禁将 Standards 轴与 Spec 轴的审查结果合并打分或折中排序！报告必须在两个独立标题下原汁原味地并列呈现，每一轴只输出该轴内部最严重的问题。** [来源：`code-review` 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md)

为什么控制论上坚决反对加权打分？
因为两轴在系统目标空间中是完全正交的：
- 一段代码可以 100% 遵守项目所有设计模式与语法规范，但业务方向彻底搞反（**Standards 满分，Spec 零分**）；
- 另一段代码可以丝毫不差地解决复杂的边缘业务逻辑，但内部结构腐化、充斥着霰弹式修改（**Spec 满分，Standards 不及格**）。

一旦系统试图计算一个“综合加权分”，表面上的高分就会成为致命缺陷的遮羞布。正交隔离汇报，强迫人类架构师或自动化门禁同时正视两个维度的真实状态，彻底杜绝隐性妥协。

---

### 二、打破自评幻觉与模型相关性偏置：从定理五到定理六

把两个审查任务分配给独立的子 Agent，究竟在物理上改变了什么？

#### 1. 定理五：独立上下文对过程残骸的物理清洗
回到[《数学基石篇》](/zhangmuchuan/blog/agent-math-foundations/)揭示的黑屋认知模型：

$$
E \longrightarrow C \longrightarrow R
$$

根据数据处理不等式（DPI）：

$$
I(E; R) \le I(E; C)
$$

在《数学基石篇》定理五中，我们形式化证明了“自我审查”的信息论无效性：设代码在物理环境中的真实状态为 $Z$，实现者拥有的上下文为 $C_t$。若模型仅基于该上下文生成自评输出 $R_{\text{自评}}$，在马尔可夫链 $Z \longrightarrow C_t \longrightarrow R_{\text{自评}}$ 条件下：

$$
I(Z; R_{\text{自评}} \mid C_t) = 0
$$

这证明：**在同一个会话里，实现者 Agent 无论自言自语反思多少轮，其关于代码真实质量的信息增量在数学上严格归零。** 它的上下文已经被先前的试错历史、Debug 垃圾信息和初始假设所占满（即《第六篇》所指的高摩擦过程残骸 Process Debris）。

独立子 Agent 的首要价值，在于**物理重置上下文窗口**：审查员以干净的白板状态进场，只摄入确定性的 Git Diff 与权威规则库，在极高的信噪比下重新对代码建立注意力分配。

#### 2. 定理六：同一基座模型的同源盲区
然而，许多团队走到了另一个极端：以为只要把代码扔给另一个 Agent 审查，就万事大吉了。

这种乐观忽视了《数学基石篇》定理六所判决的深层物理约束——**同源盲区（Shared Blindspot）**。

设实现 Agent 为 $M_1$，审查 Agent 为 $M_2$。在绝大多数工程实践中，$M_1$ 与 $M_2$ 运行在完全相同的基座大模型（如 Claude 3.5 Sonnet 或 GPT-4o）之上。它们共享完全相同的预训练先验权重、完全相同的模式偏好，以及完全相同的人类反馈对齐偏置。

更关键的是，如果上游交给两者的需求文档本身存在一处模糊表述（例如 Spec 里漏写了“取消后是否退款”，两个 Agent 都会依据训练语料中的通用惯例，自发默认“不退款是行业标配”，从而双双对代码里未做退款保护的隐患视而不见），那么两个 Agent 极大概率会激活完全一致的默认常识补全：

$$
M_1(\text{Spec}) \implies \hat{Z} \quad \text{且} \quad M_2(\text{Spec}) \implies \hat{Z}
$$

代入定理六的形式化方程：

$$
I\big(Z; R_{\text{审查}} \;\big|\; \hat{Z}(C_t), C_t\big) = 0
$$

**当实现者与审查者共享同一处认知偏置或同一份有缺陷的前馈时，换一个会话并不能凭空制造出世界上原本不存在的外部证据。** 审查员会由衷地觉得实现代码“完全符合自己的理解”，两个 Agent 在看似严密的握手中共同陷入系统性的逻辑一致误判。

#### 3. 审查发现是假说（Hypothesis），不是证据（Evidence）
正是因为深刻洞察到大模型的同源盲区，Matt Pocock 在工程说明中立下了一条极其清醒的原则：
> **子 Agent 输出的审查发现，本质上只是一组待证的语义假说（Hypothesis），绝非无可争议的物理证据（Evidence）！** [来源：`code-review` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)

为了防止模型捕风捉影或产生审查幻觉，`/code-review` 强制立规：
- Standards 轴的每一处报障，必须明确引用仓库规则文件的确切条款，或者引用 Fowler 12 项异味的具象代码片段；
- Spec 轴的每一处质疑，必须明确引用 Spec 规格文档的对应行号原文。

**不带精准出处的审查意见一律视为无效噪音。** 这一铁律将模型的模糊直觉，强行约束为可以被人类与自动化验证工具逐一核验的溯源线索。

---

### 三、审查死循环与终止条件：霍华德信息净价值的形式化判定

在多 Agent 自主协同进入深水区后，最让架构师头疼的工程故障，是**审查与修复的非收敛死循环（Infinite Review Loop）**。

社区复盘中记录过多起典型的非收敛失控场景：
> 开发者启用了自动审查并让 Agent 自动修复。
> 第一轮审查提了 3 个异味点；Agent 进场修复，改动了 50 行代码；
> 第二轮审查重新进场，发现新改的代码存在另外 2 个变量命名不够精准的问题；Agent 再次修改；
> 第三轮审查由于 Standards 轴的主观判定（Judgement calls）出现波动，推翻了第二轮的修改建议，要求改回原样……
> 甚至在某些极端开源 Harness 中，由于子 Agent 提示词未禁止递归派发，子 Agent 在审查时再次唤醒审查技能，递归膨胀出超过 50 个 Agent 进程导致系统崩溃（见 Issue #573 / PR #1186）。 [来源：`code-review` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)

审查到底应该在什么时候停下来？

我们必须调动[《第二篇：控制权的收放艺术》](/zhangmuchuan/blog/agent-control/)中的**霍华德信息价值（VoI）净收益方程**来进行形式化判定：

$$
V(a \mid C_t) = \operatorname{VoI}(a \mid C_t) - \lambda \operatorname{Cost}(a)
$$

其中：
- $a$ 是发起新一轮审查与修复的行动；
- $\operatorname{VoI}(a \mid C_t)$ 是这次审查对消除系统潜在缺陷、改善决策效用的预期收益；
- $\operatorname{Cost}(a)$ 是消耗的 Token 算力、等待延迟，以及修改代码可能引入回归缺陷的潜在风险成本；
- $\lambda$ 是风险与成本的折算权重。

```
【审查轮次与信息净价值衰减曲线】
收益/成本
  ▲
  │  高 VoI (抓出未实现的致命需求)
  │  ───────┐
  │         │
  │         │   边际收益递减 (微调命名/主观偏好)
  │         └───► VoI 趋近于 0
  │──────────────────────────────────────────► 审查轮次 (Round)
  │               ▲
  │               │   成本与回归风险飙升: Cost >> 0
  │               └──────────────────────────►
  ▼
```

代入方程推演，审查轮次与信息净价值展现出极其清晰的演化规律：
1. **第一轮审查（高信息净价值）**：重点排查 Spec 缺失与严重的架构硬违规。此时消除的是高危系统风险，$\operatorname{VoI} \gg \operatorname{Cost}$，净收益极高；
2. **多轮递进之后（边际收益归零，风险反超）**：当严重的硬性违规均已清除，残留的意见全面滑向 Standards 轴的主观审美偏好（如“这个函数提炼成两行是否更好”、“那个变量名能否更优雅”）。此时，$\operatorname{VoI} \to 0$；而频繁改动代码引入新 Bug 的风险与算力消耗 $\operatorname{Cost} \gg 0$。

此时：

$$
V(a \mid C_t) < 0
$$

继续推进审查，系统的净期望价值已经为负！

因此，工程上必须建立确定性的**审查终止准则（Stopping Criteria）**：
- **硬性违规清零即止**：凡是有 Spec 原文违背或明确仓库规范冲突的，必须修复；
- **主观启发式意见单轮收敛**：对于 Fowler 代码异味等纯主观建议，只提供线索清单供人类或下阶段重构参考，绝不作为阻断交付的硬性门禁；
- **禁止无节制循环**：单张工单的自动审查以一轮为限，严禁陷入“审查 $\to$ 自动修复 $\to$ 再次自动审查”的未封闭死循环。

---

### 四、$(P, M, H)$ 协同裁判席：大模型审查的边界与人机分工

解构到这里，自动代码审查在软件工程全生命周期中的坐标已经彻底清晰。

回到我们在《数学基石篇》与《第三篇》中一以贯之的 **$(P, M, H)$ 铁三角协作框架**：

```
【(P, M, H) 现代代码审查裁判席】
                   ┌────────────────────────────────────────┐
                   │          人类架构师 (H)                │
                   │  (商业意图仲裁 / 重大架构取舍 / 终审放行)  │
                   └──────────────────┬─────────────────────┘
                                      │
                     ┌────────────────┴────────────────┐
                     ▼                                 ▼
      ┌─────────────────────────────┐   ┌─────────────────────────────┐
      │      程序确定性工具 (P)      │   │       语义审查模型 (M)      │
      │   (编译器/静态类型/测试套件) │   │ (双轴审查: 抓遗漏 / 嗅异味)  │
      │   【提供客观存在的物理事实】 │   │   【提供带有引文的待证假说】 │
      └─────────────────────────────┘   └─────────────────────────────┘
```

大模型自动审查从来不是为了取代其他工具，而是填补传统静态工具与人类精力之间的语义鸿沟：
1. **程序工具 $P$（编译器、Linter、类型检查、单元测试）**：
   - 职责：提供**客观确凿的物理事实（Hard Evidence）**。
   - 规则：凡是能够通过 ESLint、TypeScript 编译器或自动化单测发现的问题，绝不浪费大模型审查算力去排查。
2. **大模型审查员 $M$（基于双轴正交架构的子 Agent）**：
   - 职责：提供**具备溯源引文的语义假说（Hypothesis）**。
   - 规则：它不负责终审裁决，而是像一位警觉的侦查员，快速在 Diff 与 Spec 之间寻找潜在的需求违背和架构腐化迹象。
3. **人类架构师 $H$（最终决策者）**：
   - 职责：提供**价值仲裁与底线担保（Final Arbitration）**。
   - 规则：面对 $P$ 的事实与 $M$ 的假说，人类负责对真实业务意图进行最终背书，拍板合并，完成工程闭环。

---

### 结语：独立，是为了在不同坐标系里审视真相

回顾 Matt Pocock 的整个 Agent Skills 体系，从需求相变结晶的 [`to-spec`](/zhangmuchuan/blog/matt-pocock-skills-04/)，到纵向切片与依赖前沿的 [`to-tickets`](/zhangmuchuan/blog/matt-pocock-skills-05/)，再到微观代码自证的 [`tdd`](/zhangmuchuan/blog/matt-pocock-skills-06/) 与原子交接的 [`implement`](/zhangmuchuan/blog/matt-pocock-skills-implement/)，最终在 [`code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 处完成闭环。

我们清晰地看到了一条贯穿始终的第一性原理红线：**整个工程体系所做的一切复杂设计，本质上都在与大模型固有的认知盲区、注意力衰减和确认偏误做坚决的斗争。**

换一个 Agent 审查，并不能神奇地变出它未曾知晓的物理事实；但为它搭建独立的上下文沙箱、赋予正交的审视尺度、剥离实现者的试错偏见，却能将复杂系统关于缺陷的不确定性，压缩到极其狭窄的范围。

在 AI 辅助乃至自主编程的历史进程中，真正的专业主义，从来不是对全自动魔法的盲目崇拜，而是用数学的冷峻度量其边界，用控制论的严密驯服其长程，在人机协同的矩阵中，构建起坚如磐石的现代软件工程大厦。

---

### 参考资料

- [数学基石篇](/zhangmuchuan/blog/agent-math-foundations/)；[第一篇：架构的必然演进](/zhangmuchuan/blog/agent-loop/)；[第二篇：控制权的收放艺术](/zhangmuchuan/blog/agent-control/)；[第三篇：驯服长程循环](/zhangmuchuan/blog/agent-harness/)；[第六篇：穿越时间的 Context](/zhangmuchuan/blog/agent-memory/)。
- [解构 Matt Pocock 的 Skills（六）：测试先亮红灯，Agent 就真的知道自己做对了吗（新稿）](/zhangmuchuan/blog/matt-pocock-skills-06/)；[解构 Matt Pocock 的 Skills（七）：测试通过以后，Agent 怎样把工作真正交出去](/zhangmuchuan/blog/matt-pocock-skills-implement/)。
- [code-review 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md)与[code-review 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)。
- [implement 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement/SKILL.md)与[implement 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/implement.md)。
- [Matt Pocock 访谈记录](https://www.youtube.com/watch?v=4DhcSPkEbwI)。
