---
title: "解构 Matt Pocock 的 Skills（七）：测试通过以后，Agent 怎样把工作真正交出去？"
date: 2026-11-12
description: "分析实现、测试、审查与提交之间的证据交接。"
tags: [AI, Agent]
slug: matt-pocock-skills-implement
draft: false
series: [Matt Pocock Skills]
series_weight: 7
---

> 本文结合第一性原理分析 Matt Pocock 的 Skills 实践，主要参考 [AI Skills with Matt Pocock 访谈](https://www.youtube.com/watch?v=4DhcSPkEbwI)和 [Skills 项目所引用版本](https://github.com/mattpocock/skills/tree/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d)。

### 引子：全绿的代码与冻结的任务图——交付的“最后一公里”断裂

在 Agent 自主编程实践中，许多团队都遭遇过一种极其隐蔽的协同短路：

> 你为 Agent 指派了一张关键工单，要求实现“取消会员续费并保留当前周期权益”。
>
> Agent 严守规范：在约定的测试接缝上跑 TDD，局部单测亮起绿灯；在终端里跑通了项目的全量测试套件；最后，它输出了一句“任务完成，代码已提交到当前分支”。
>
> 然而，协同系统的齿轮并没有顺畅转动：
> 1. 下游等待依赖该模块的子 Agent 依然在拓扑前沿原地冻结，因为工单系统里的状态根本没有被更新，阻塞边始终没有解除；
> 2. 审查员 Agent 被呼叫进场，却直接报错退出，或者只留下了一句“未发现任何改动”，因为被审查的代码根本没有进入审查员能感知的 Git 范围；
> 3. 更致命的是，检查 Git 提交历史才发现，Agent 在全套测试全绿之后、执行提交之前的最后一秒，随手修改了两个类型注解与文案，而这段最终合入分支的代码，**从诞生起从未在任何测试套件里运行过哪怕一次**。

局部测试全部通过，甚至敲下了 `git commit`，代码就算真正“交出去”了吗？

在前面两篇中，我们分别解构了[宏观工单的任务切片](/zhangmuchuan/blog/matt-pocock-skills-05/)与[微观工单内部的 TDD 闭环](/zhangmuchuan/blog/matt-pocock-skills-06/)。本篇我们将视野推到单张工单的交付边界：深入解剖 Matt Pocock 的核心构建技能 [`/implement`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement/SKILL.md) 及其配套的调度体系 [`implement-spec`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement-spec/SKILL.md)，用信息论与分布式状态机彻底解构：**代码实体、验证元数据与任务拓扑状态，究竟怎样才能完成原子化的交付闭环？**

---

### 一、证据的时空四元组：严防“先验后改”的虚假安全感

要理解交付为何会失败，首先必须从第一性原理搞清楚：**一盏测试绿灯，到底在证明什么？**

在许多开发者的直觉里，“测试通过”是一个附着在代码文件上的静态布尔属性。但回到[《数学基石篇》](/zhangmuchuan/blog/agent-math-foundations/)与[《第三篇：驯服长程循环》](/zhangmuchuan/blog/agent-harness/)，测试运行不是形而上的概念，而是一次物理交互产生的**状态观测证据**。

每一份有效的验证证据，在物理世界中都严格绑定为一个不可分割的**时空四元组**：

$$
\text{Evidence} = \big(\text{Commit Hash},\; \text{Test Command},\; \text{Exit Code},\; \text{Environment}\big)
$$

这个四元组明确宣示：唯有在确定的环境配置下，针对特定 Git 提交哈希所指向的代码快照，执行特定的测试命令并返回零退出码，这笔测试证据才具备确定性的工程有效性。

而在 Agent 实际编码现场，最容易诱发风险的反模式是**验证与变异的解耦（Verification-Mutation Decoupling）**，即“先验后改”：

```
【先验后改的时空错位】
版本 A (Commit Hash: 1a2b) ──► [运行全量测试套件] ──► 🟢 全部通过 (得到证据元数据)
                                                               │
                                                               ▼ (时空断裂：代码再次变异)
版本 B (Commit Hash: 3c4d) ◄── [Agent 顺手调整代码/修复审查意见] ◄── 未经复测的微调改动
       │
       ▼ (未复跑测试直接提交)
[合并到主干分支] ──► 💥 生产环境编译报错 / 逻辑断裂
```

这就像你去医院做全套入职体检：周一上午在体检中心抽血化验，拿到了一份各项指标全部正常的健康报告；周二回到家，你随手喝下了一瓶配方不明的试剂；周三去公司报到时，你却直接把周一的体检单拍在 HR 桌上说“看，我身体完全达标”。这份周一的报告能证明你周三的健康吗？绝无可能。在你喝下试剂（代码发生变异）的瞬间，旧的体检证据与你当前的生理状态就已彻底解耦。

我们用《数学基石篇》的信息完备性方程来形式化度量这笔信息账：

$$
I(Z; C_n) = I(Z; C_0) + \sum_{k=1}^{n} I(Z; O_k \mid C_{k-1})
$$

设 $Z_B$ 为最终交付代码（版本 B）的真实正确性。由于版本 B 是在测试通过后私自修改的产物，它从未通过测试套件的物理执行，因此针对目标 $Z_B$，系统获得的有效外部状态观测项严格为零（$\sum I(Z_B; O_k \mid \dots) = 0$）。

在离散且极度敏感的图灵软件空间中，一个符号的颠倒或类型的微调即可导致运行态溃败。针对版本 A 所获得的观测证据 $O_A$，关于突变版本 B 的条件互信息瞬间归零：

$$
I(Z_B; O_A \mid C_A) \approx 0 \implies I(Z_B; C_n) \approx I(Z_B; C_0)
$$

此时模型对版本 B 的所谓“信心”，被完全打回了未经验证的内源先验 $I(Z_B; C_0)$。而根据《数学基石篇》**定理二（现实不可辨识性）**与**定理五（脑内自评无效）**，在缺乏外部物理探针反馈的情况下，模型的内部思维链对辨识代码在真实宿主机上的正确与崩溃无法提供任何信息增量。

**针对旧代码的绿灯，在信息论上对新代码的安全置信度为零。**

因此，一个可靠的 Agent 交付协议必须确立第一条工程铁律：**任何代码实体的变异（Mutation），必须强制触发验证证据链的重连（Re-verification）。** 唯有最终提交的哈希值与最终测试报告中的目标快照严格吻合，证据链才算真正闭环。

---

### 二、幽灵 Diff 与空审漏洞：工作区、暂存区与 HEAD 的物理鸿沟

在验证证据与代码实体对齐之后，交付链条上的下一道坎是**代码审查的接缝错位**。

在 Matt Pocock 的原生规范中，记录了一个在社区引发广泛讨论的经典工程陷阱：
- [`/implement`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement/SKILL.md) 技能定义的施工流程十分明确，由标准 5 步构成：
  `读工单敲定测试接缝` $\to$ `在约定接缝上驱动 TDD` $\to$ `高频类型检查与单测` $\to$ `跑全量测试套件收尾` $\to$ `调用 code-review 审查并最终提交`；
- 但与此同时，底层的 [`code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 技能在比对代码差异时，执行的基准指令是：
  ```bash
  git diff <fixed-point>...HEAD
  ```

这两份设计在拼装到一起时，瞬间撞出了一个致命的**审查盲区（比对真空）**：
**`git diff <fixed-point>...HEAD` 检查的是分支起点与当前最新提交 `HEAD` 之间的差异；它严格排除了工作区（Working Tree）与暂存区（Index）中尚未提交的文件改动！** [来源：`implement` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/implement.md)

```
【工作区未提交时的审查短路】
<fixed-point> (分支起点) ──────────────► HEAD (当前最新提交，指针完全未动!)
                                            │
                                            ▼
                              git diff <fixed-point>...HEAD
                                            │
                                            ▼
                                  【Empty Diff (空集合)】
                                            │
工作区 (Working Tree): 改动了 10 个文件 ───┴──► 审查员 Agent 完全看不见！
```

如果 Agent 在工作区里辛辛苦苦写了 500 行代码，但中途没有做过任何临时提交，那么当流程推进到 `code-review` 时，`HEAD` 指针依然停留在任务启动的原点。审查员拿到的 Diff 是一个空集合（Empty Diff）。

结合[《第一篇》](/zhangmuchuan/blog/agent-loop/)的黑屋模型：外部物理现实为 $E$，审查员摄入的上下文为 $C$。根据马尔可夫链 $E \to C \to R$，审查员模型绝不可能具备超距感知宿主机工作区磁盘的能力。如果未经提交的代码差异根本没有进入上下文 $C$：

$$
I(E_{\text{改动}}; C_{\text{审查}}) = 0 \implies I(E_{\text{改动}}; R_{\text{审查}}) = 0
$$

审查员面对一个空 Diff，要么直接报错终止，要么在缺失有效上下文的情况下给出“未发现任何问题”的伪阳性结论。这就是大模型协作中最典型的**空审漏洞（Ghost Diff）**。

解决这一接缝裂痕的工程方案非常清晰：
1. **暂存提交（Interim Commit）**：在调用审查前，必须先在工作分支上生成一个明确的快照提交，将改动推进至 `HEAD`，然后再发起比对；
2. **审查范围显式对齐**：使用能够明确覆盖工作区差异的检查机制，确保审查员摄入的上下文与即将交付的代码实体物理同构。

做审查的人，必须看到正在砌的砖，而不是昨天的空地。

---

### 三、单工作区并发踩踏 vs 独立工作树（Worktree）隔离

当任务规模扩大、需要多个 Agent 并发推进时，交付系统会面临另一场严峻考验：**多 Agent 在单工作区下的并发冲突**。

许多工程师在初尝 Agent 甜头后，很容易产生一个直觉：既然一个工单跑一个 `/implement` 这么快，那我为什么不在同一个项目目录里，同时开 5 个终端窗口，并发跑 5 个 `/implement`？

Matt Pocock 在工程复盘中记录了一个典型的并发踩踏事故：
> 某个团队在同一个 Git 本地检出目录中并发运行多个 `/implement` 会话。仅仅在一个下午，由于多个 Agent 共享同一个工作目录、同一个 Git 暂存区索引与同一个 `HEAD` 指针，会话之间发生了灾难性的踩踏——一个 Agent 执行的 `git commit --amend` 直接改写了另一个 Agent 刚刚提交的历史；暂存的改动在 `refs/stash` 中离奇蒸发；多个工单的代码被交叉提交到了错误的临时分支上。 [来源：`implement` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/implement.md)

```
【单工作目录下的多 Agent 并发踩踏事故】
Agent 1 (工单 A) ──┐
Agent 2 (工单 B) ──┼──► 共享同一个 Working Directory / .git/index / HEAD
Agent 3 (工单 C) ──┘        │
                            ├──► commit --amend 互相覆盖
                            ├──► stash 栈全局被清空
                            └──► 交叉污染，无法回滚
```

这就像让 5 位厨师在同一张案板、同一本手写菜单上同时炒 5 道菜：厨师 A 刚把切好的牛肉摆在案板角落，厨师 B 随手一抹抹布把酱汁全倒了上去；厨师 C 刚划掉一道菜，厨师 D 拿着笔在同一行涂改。最后整张案板一团狼藉，谁也分不清哪块肉是哪道菜的。

在操作系统与版本控制的底层，单份 Git 检出目录不是为并发写入而设计的。

为了彻底阻断这种物理踩踏，正统的调度技能 [`implement-spec`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement-spec/SKILL.md) 树立了工业级的并发标准：

#### 1. 独立工作树隔离（Git Worktree Isolation）
对于任务拓扑前沿上的每一个可执行工单，调度器绝不允许它们在主目录中混作一团，而是调用 `git worktree add`，为每一个子 Agent 派发一个**完全独立的物理文件工作树（Worktree）**以及专属于该任务的隔离特性分支。
这相当于为每位厨师直接分配一个带独立灶台、独立切菜板的封闭小厨房。每个 Agent 拥有自己独立的磁盘目录、独立的暂存区和独立的 `HEAD`。任何一个 Agent 的编译失败、调试报错或代码回滚，在物理上被完全隔离在自己的独立工作树沙箱内，绝不波及他人。

> **底层细节提醒**：需要注意的系统底层细节是，虽然 Worktree 彻底物理隔离了工作目录、Index 与 HEAD 指针，但在 Git 底层，`.git/refs/stash` 依然是整个仓库全局共享的。因此在多 Agent 协同规范中，除了工作树隔离外，还必须明令禁止 Agent 随意使用 `git stash` 跨步暂存，而必须采用**原子临时快照提交（Interim Commit）**来封存现场，防止隐蔽的 Stash 覆盖。

#### 2. 独立合并代理（Merger Subagent）负责集中合流
子 Agent 在自己的 Worktree 内部跑通 TDD、执行单测，并将集成分支最新代码合入本地确保 Fast-forward 后，**它没有权限直接向集成分支强推代码**。（*注：原案严禁在子 Agent 阶段提前调用 `code-review`，因为审查员若对照整张未做完的 Spec 审查单张工单，会将其他未完成项误判为缺失，引发长达数小时的灾难性修复死循环。*）

调度器会唤醒一个专门的合流子代理（Merger Subagent），由它统一把各分支逐一拉取并执行合并（Merge）。而在所有工单合入之后，调度器才在集成分支上统一触发全局 `code-review` 与跨工单集成测试，一旦发现冲突或隐式接口破坏，集中派发修复子代理拦截，保障主干分支永远处于确定性绿灯状态。

```
【正统工作树隔离与合流拓扑】
任务拓扑前沿 (Frontier)
      │
      ├─► 子 Agent 1 ──► [独立 Worktree A / 分支 feature-01] ──┐
      │                                                        │
      └─► 子 Agent 2 ──► [独立 Worktree B / 分支 feature-02] ──┴─► 【Merger 合并代理】 ──► 集成分支
                                                                        (集中审计与集成测试)
```

**并发开发的本质不是盲目抢跑，而是物理隔离下的有序合流。**

---

### 四、从代码孤岛到状态前沿：解除工单图的下游阻塞

当代码已经安全合入分支、全套测试绿灯长明，交付的最后一步往往最容易被忽视：**任务拓扑状态机的同步刷新**。

在 [`to-tickets`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/to-tickets/SKILL.md) 的架构设计中，所有工单被组织为一张严格的有向无环图（DAG）。下游工单是否具备施工条件，完全取决于其声明的阻塞边（`Blocked by`）是否全部处于解除状态。这组已无阻塞、可以立刻开工的任务集合，被称为**可执行前沿（Frontier）**。

![从实施、验证到后续会话接手](images/implement-feedback-handoff.png)

然而，在原版 `/implement` 的实现中存在一个刻意的设计留白：
> `/implement` 的生命周期严格终止于当前分支的代码提交。它**故意不自动勾选工单中的验收复选框（`- [ ]`），也故意不自动在 Tracker 上关闭当前工单**。 [来源：`implement` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/implement.md)

这种留白带来了不可忽视的系统断裂：如果代码已经推上分支，但没有任何人去更新工单系统的元数据，那么在调度系统的全局拓扑图上，这张工单依然显示为“进行中”。下游所有依赖它的工单，其阻塞状态永远无法解除，可执行前沿直接陷入物理停滞！

从[《第六篇：穿越时间的 Context》](/zhangmuchuan/blog/agent-memory/)的第一性原理来看，跨会话传递的核心是**结晶前馈的高保真交接**。新会话启动时，模型无法凭空猜出上一任 Agent 究竟在代码仓库里做了什么。

一个完整的交付协议，必须在提交代码的同时，原子化地完成四项元数据结晶的交接：

```text
【高保真交付结晶清单】
1. 提交哈希 (Commit Hash)：明确标注代码落库的确定性版本指纹；
2. 验证凭证 (Verification)：记录全量测试套件执行的命令、覆盖范围与通过时间戳；
3. 契约验收 (Criteria Reconciliation)：依据代码实测表现，逐项勾选确认工单验收项；
4. 状态流转 (State Transition)：解除当前节点的阻塞标记，将拓扑前沿推向下一站。
```

唯有当状态机流转完毕，前沿向前推进，下一个接手的 Agent 才能拿着一份信噪比极高的确定性前馈，在干净的工作台里启动。

---

### 结语：交出去的不只是代码，而是坚固的确定性

重新审视现代软件工程在 Agent 时代的演进，我们会发现一个根本性的视角迁移：

敲完最后一行代码、终端亮起绿灯，从来不代表工程的终结。代码只是系统演进的载体，而交付的真谛在于**确定性的无损传递**。

Matt Pocock 的工程实践与我们的理论推导共同揭示了交付的底层防御机制：
1. **用时空四元组锚定证据身份**，代码发生任何微小变异，必须坚决触发测试证据链的重连，消除“先验后改”带来的虚假安全感；
2. **用暂存快照填平 Diff 鸿沟**，阻断因未提交修改诱发的审查盲区，确保审查员视线与交付实体分毫不差；
3. **用独立 Worktree 筑起并发防火墙**，杜绝多 Agent 在单目录下的资源踩踏，依托集中合流代理守护集成质量；
4. **用状态拓扑打通交付最后一公里**，在落库代码的同时刷新前沿状态，将坚固的高保真前馈平滑传递给下一任接手者。

交出去的不只是一串 Git Commit 字符，而是一份具备数学可证伪性、物理可核验性、拓扑自洽性的完整工程成果。

而当代码已经跨过交付门槛、进入集中合流阶段，面对由不同 Agent、不同会话生成的复杂改动，我们又该如何换一个独立视角，对系统开展全方位的综合审查？

在下一篇中，我们将深入解构代码审查的双轴模型：换一个 Agent 重新审视，就真的能看出代码里的深层问题吗？

---

### 参考资料

- [数学基石篇](/zhangmuchuan/blog/agent-math-foundations/)；[第一篇：架构的必然演进](/zhangmuchuan/blog/agent-loop/)；[第二篇：控制权的收放艺术](/zhangmuchuan/blog/agent-control/)；[第三篇：驯服长程循环](/zhangmuchuan/blog/agent-harness/)；[第六篇：穿越时间的 Context](/zhangmuchuan/blog/agent-memory/)。
- [解构 Matt Pocock 的 Skills（五）：把任务切开之后，Agent 怎样更早看见自己做得对不对（新稿）](/zhangmuchuan/blog/matt-pocock-skills-05/)；[解构 Matt Pocock 的 Skills（六）：测试先亮红灯，Agent 就真的知道自己做对了吗（新稿）](/zhangmuchuan/blog/matt-pocock-skills-06/)。
- [implement 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement/SKILL.md)与[配套说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/implement.md)。
- [implement-spec 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement-spec/SKILL.md)与[code-review 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md)。
- [tdd 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/SKILL.md)与[to-tickets 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/to-tickets/SKILL.md)。
- 关于 implement 与测试反馈的讨论。
