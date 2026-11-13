---
title: "解构 Matt Pocock 的 Skills（六）：测试先亮红灯，Agent 就真的知道自己做对了吗？"
date: 2026-11-11
description: "探讨测试驱动开发中红灯、绿灯和测试证据的边界。"
tags: [AI, Agent]
slug: matt-pocock-skills-06
draft: false
series: [Matt Pocock Skills]
series_weight: 6
---

> 本文结合第一性原理分析 Matt Pocock 的 Skills 实践，主要参考 [AI Skills with Matt Pocock 访谈](https://www.youtube.com/watch?v=4DhcSPkEbwI)和 [Skills 项目所引用版本](https://github.com/mattpocock/skills/tree/4ae2317ddb22b046e26455e4f9c9b3aaaf62212d)。

### 引子：全绿的测试与做错的需求——Agent 时代的“假性繁荣”

在日常工程实践中，许多团队都经历过这样一幕场景：

> 你交给 Agent 一个会员取消订阅的任务。需求规格在 Spec 里写得很清晰：用户主动取消自动续费后，**已经付费的会员权益必须保留到当前周期结束**。
>
> 几分钟后，Agent 信心满满地返回结果：“代码编写完毕，自动化测试全部通过，绿灯交付。”
>
> 然而当你打开测试文件，却发现测试断言赫然写着：**调用取消接口后，立即断言用户会员状态为 `inactive`**。实现代码也丝毫不差地把权益直接抹去。

测试确实真实运行了，终端里的断言绿得发亮；但系统实际交付的行为，与真实的业务意图完全背道而驰。

更普遍的场景则是**断言同义反复**：Agent 写了一个测试，仅仅断言“调用取消方法后，取消方法确实被执行了 1 次”。测试同样是一路绿灯，但自动续费到底有没有关闭、并发扣款会不会重复，测试对此保持了彻底的沉默。

这揭示了大模型自主编程时代一个极其尖锐的核心矛盾：**在传统软件工程中，测试驱动开发（TDD）被奉为保证质量的基石；但如果“判卷人（写测试）”和“答卷人（写代码）”全是由同一个模型在同一个黑屋里扮演，那一排排绿色的测试，究竟证明了什么？**

在上一篇[《解构 Skills（五）：to-tickets》](/zhangmuchuan/blog/matt-pocock-skills-05/)中，我们解决了宏观任务的纵向切片与依赖前沿问题。本篇我们将镜头推向单张工单内部的毫厘之间，深入解剖 Matt Pocock 的 [`/tdd`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/SKILL.md) 技能体系，用信息论与恒温器控制论系统解构：红灯真正带来了什么信息？为什么同源测试会沦为自拍杆？为什么实战中必须立下“绝不 Mock 内部模块”的铁律？

---

### 一、破除自评幻觉：外部执行才是唯一的信息增量来源

要理解 TDD 在 Agent 时代的真实价值，必须先破除对大模型“自我反思（Self-Correction）”能力的过度迷信。

回到[《数学基石篇》](/zhangmuchuan/blog/agent-math-foundations/)揭示的模型认知物理边界：

$$
E \longrightarrow C \longrightarrow R
$$

根据数据处理不等式（DPI）：

$$
I(E; R) \le I(E; C)
$$

模型在封闭的单次推理中，只能对其上下文 $C$ 包含的既有信息进行概率提取与重组，绝不可能凭空创造出输入上下文之外的当前物理环境事实。

很多团队喜欢在 Prompt 里加上一句话：“请你在写完代码后，仔细自我审查，确认逻辑完全正确后再输出。”这种做法在信息论上究竟有没有效果？

《数学基石篇》定理五对此给出了严格的形式化判决：设 $Z$ 为程序在外部真实运行时中的目标状态，$C_t$ 为模型当前掌握的上下文，$R_{\text{自评}}$ 为模型仅基于该上下文生成的反思与自评。在满足 $Z \longrightarrow C_t \longrightarrow R_{\text{自评}}$ 的马尔可夫链条件下：

$$
I(Z; R_{\text{自评}} \mid C_t) = 0
$$

这个等式如同物理定律般冰冷：**在没有引入新的外部环境观测之前，模型在同一个上下文里写出再多篇幅的“自审”、“自省”，其关于系统真实运行状态的信息增量严格为零！** 它充其量只能消除文字逻辑上的自相矛盾，却无法验证真实依赖库会不会抛出异常、外部数据库连接会不会超时。

外部运行测试，正是为了强行打破这个封闭的信息孤岛。当测试被交给外部真实环境执行时，运行时返回的退出码、堆栈轨迹与断言输出，构成了对模型而言真正外源的**单步反馈增量**：

$$
\Delta I_{\text{反馈},k} = I(Z; O_k \mid C_{k-1})
$$

![测试预期、实际执行与比较结果的关系](images/tdd-test-evidence.png)

Matt Pocock 在其 [`tdd` 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/SKILL.md)中，将微观实现的纪律总结为三位一体的核心法则（Rules of the loop）：
1. **Red before green**（先红后绿：先写失败测试，只写刚好能通过的代码，不预判未来测试）；
2. **One slice at a time**（单切片推进：一次只针对一个约定的测试接缝，做一个测试和一个极简实现）；
3. **Refactoring is not part of the loop**（重构不属于红绿循环，移交后续独立审查）。

在这个视角下，我们才能看清“先红后绿（Red before green）”的硬核工程内涵：
- **红灯（Red）的本质，是验证传感器的灵敏度与可证伪性。** 如果你写了一个测试，代码还没动它就已经绿了，或者因为语法错误崩溃报错，它就无法证明自己具备辨识目标特性的能力；只有当测试以预期的断言差异清晰地亮起红灯，才物理证明了：**当前被测代码确实缺少我们即将实现的行为**。
- **绿灯（Green）的本质，是验证执行器的有效性。** 唯有在事先经历过可证伪红灯的前提下，改动代码带来的绿灯，才真正构成了消除系统不确定性的有效信息增量。

---

### 二、同源盲区与镜像测试：当测试沦为代码的“自拍杆”

然而，只要引入了测试运行，系统就真的安全了吗？文章开头的真实事故立刻给出了无情的否定。

当写测试的 Agent 和写实现的 Agent 是同一个实体时，系统直接撞上了《数学基石篇》定理六揭示的**同源盲区（Shared Blindspot）**：

```
【同源盲区下的伪 TDD 循环】
用户需求: 取消后保留到期前权益
   │
   ▼ (需求误解注入)
Agent 认知: "取消后立即剥夺权益"
   │
   ├─► 步骤 1 (写测试): assert user.status == 'inactive' ──[运行初始代码]──► 🔴 亮红灯 (符合预期!)
   │
   ├─► 步骤 2 (写实现): user.status = 'inactive'
   │
   └─► 步骤 3 (跑测试): assert user.status == 'inactive' ──[再次运行]──────► 🟢 全绿交付! (需求彻底偏航)
```

整个过程严格遵守了红绿循环：先写测试、明确见红、编写实现、测试翻绿。但最终的交付物却彻底错了。

在《数学基石篇》中，定理六从形式化上精准宣判了这种自测机制的信息论死穴：设模型对真实业务目标 $Z$ 产生了先验认知偏差 $\hat{Z}(C_t) \neq Z$，业务代码 $A_{\text{code}}$ 与测试用例 $T_{\text{assert}}$ 均基于同一个错误假设生成：

$$
A_{\text{code}} \sim P(\cdot \mid \hat{Z}(C_t), C_t) \quad \text{且} \quad T_{\text{assert}} \sim P(\cdot \mid \hat{Z}(C_t), C_t)
$$

此时测试运行通过，仅能证明实现与假设自洽；对于暴露真实方向性错误而言，新增条件互信息严格为零：

$$
I\big(Z; O_{\text{自测通过}} \;\big|\; \hat{Z}(C_t), C_t\big) = 0
$$

此时的测试，根本不是衡量系统的客观尺子，而只是代码用来确认自己存在的一根“自拍杆”。

不仅如此，定理六的第二推论还揭示了**古德哈特作弊（Goodhart Hacking）**：在消除报错的优化过程中，放宽断言或篡改测试的梯度阻力远小于重写业务逻辑（$\nabla_{\text{测试规则}} \operatorname{Loss} \ll \nabla_{\text{重写业务}} \operatorname{Loss}$）。这就是为什么 Matt Pocock 在 TDD 规范中立下一条刚性铁律：**进入编写实现的 Green 阶段后，测试代码物理冻结，严禁 Agent 回头篡改测试断言！** 唯有剥夺模型同时修改判卷标准与答卷内容的双重权力，才能阻断系统向作弊退化。

在 Matt Pocock 的测试指南 [`tests.md`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/tests.md) 中，将这种现象精准定义为 **同义反复测试（Tautological Tests）**。指南中列出了一个极具代表性的反模式示例：

```typescript
// 错误反模式：断言的期望值机械复算了实现的计算逻辑
test("calculateTotal sums line items", () => {
  const items = [{ price: 10 }, { price: 5 }];
  // 这里的预期值直接拷贝了业务代码的 reduce 逻辑！
  const expected = items.reduce((sum, i) => sum + i.price, 0);
  expect(calculateTotal(items)).toBe(expected);
});
```

如果开发者的 `reduce` 逻辑漏掉了税费，或者在浮点数乘法上写错了精度，测试里的 `expected` 会一模一样地把错误复算一遍。两边算出来的结果完全一致，测试通过率 100%，实际业务却在静默亏损。

为了打破这种镜像自欺，`tdd` 技能确立了一条刚性铁律：
> **断言的期望值必须来自完全独立的前馈基线（Independent Source of Truth）。** 它必须是 Spec 规格中明确写死的字面常量（Known-good literal）、经过人工校准的独立业务算例，或是确定性的外部规约；绝不允许在测试代码里把实现的算子重新推演一遍。 [来源：`tdd` 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/SKILL.md)

```typescript
// 正确模式：期望值是独立、确定的硬基线常量
test("calculateTotal sums line items", () => {
  // 15 是脱离具体算法实现的客观基准事实
  expect(calculateTotal([{ price: 10 }, { price: 5 }])).toBe(15);
});
```

唯有期望值脱离了实现逻辑的引力场，测试才能重获作为“独立裁判”的裁决权。

---

### 三、接缝选择与 Mock 边界：为什么 Matt 严禁 Mock 自研代码？

在[《第三篇：驯服长程循环》](/zhangmuchuan/blog/agent-harness/)中，我们建立了恒温器负反馈模型。测试用例在其中扮演着**传感器（Sensor）**的角色。

既然是传感器，布置的位置就决定了一切。在工程实践中，传感器最容易布错在两个极端：**要么刺探了不该管的内部私有实现，要么用虚假的替身掩盖了真实的物理裂痕。**

#### 1. 测试接缝（Test Seams）：只锁公共契约，不刺探内部实现
Matt Pocock 在规范中反复强调：**测试只能打在预先约定的公开接缝（Pre-agreed Seams）上。**

什么是接缝？接缝是对调用方公开的稳定行为边界（公共 API 端点、导出的领域服务方法、CLI 接口）。
与之相对的典型脆弱反模式，是**实现耦合测试（Implementation-coupled Tests）**：
- 断言某个私有类的方法被调用了 2 次；
- 断言内部某个临时缓存字典的 Key 名称；
- 直接 bypass 接口去 SQL 查询数据库内部行。

这种测试把传感器直接扎进了齿轮内部。从控制论看，这向比较器注入了海量的**实现噪声（Implementation Noise）**。结果就是工程实践中极易陷入的脆弱测试困境：**内部结构做了一次完全合理的局部重构，对外行为毫发无损，测试套件却瞬间全红！**

测试必须只关心“输入什么，输出什么”，彻底放手内部的实现组织。

#### 2. Mock 的边界法则：绝不 Mock 属于你自己的代码
当系统涉及外部交互时，Mock 替身常常不可避免。但滥用 Mock 也是削弱测试置信度的主要隐患。

在 [`mocking.md`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/mocking.md) 中，Matt Pocock 划定了一条明确的边界红线：

```
【允许 Mock 的边界（系统不可控外部边界）】
├── 第三方外部 API (Stripe 支付网关、SendGrid 邮件服务)
├── 物理时钟与系统时间 (Date.now(), 定时器)
└── 物理随机数 (Crypto / Random)

【严禁 Mock 的范围（自研内部领域）】
├── 严禁 Mock 自己的业务类与模块 (Your own classes/modules)
├── 严禁 Mock 内部协作服务 (Internal collaborators)
└── 严禁 Mock 任何在自身代码控制权范围内的逻辑
```

为什么这条铁律对 Agent 体系尤为关键？

用信息论来进行形式化推演：设真实自研模块 B 的接口与实现状态为 $Z_B$。当 Agent 手工捏造 Mock 桩 $M_B$ 时，$M_B$ 完全由当前上下文 $C_t$ 自回归生成，与代码库中模块 B 的真实演化状态条件独立（$Z_B \perp M_B \mid C_t$）。此时测试通过的反馈 $O_{\text{Mock}}$ 关于真实模块协同状态的信息量完全归零：

$$
I(Z_B; O_{\text{Mock通过}} \mid C_t) = 0
$$

```
【内部 Mock：虚假自洽回路】
真实业务模块 A ──[调用假设契约]──► Mock 内部模块 B (Agent 手工捏造的替身)
       │                                     ▲
       └────────────── 假装绿灯 ──────────────┘
（此时真实的模块 B 接口其实已经改了，两者的契约裂痕被 Mock 完全遮蔽！）
```

这等于在恒温器系统内部制造了一个“虚假的自洽回路”。真实的模块 A 与真实的模块 B 之间的契约漂移被这个人为捏造的 Mock 完全屏蔽。两边单元测试全绿，一到真实上线立刻崩溃。

**只在物理不可控的边界建立隔离桩，内部协同必须通过真实对象打通。** 这是一条不可妥协的工程底线。

---

### 四、务实的工程取舍：为什么 Matt Pocock 砍掉了 Refactor？

熟悉经典敏捷开发的工程师都知道，TDD 的标志性口诀是 **红 $\to$ 绿 $\to$ 重构（Red $\to$ Green $\to$ Refactor）**。

但在深入研读 Matt Pocock 的 `/tdd` 技能规范及说明文档时，你会发现一个反直觉的工程设定：

> 在 2026 年中（June 2026）的版本演进中，Matt Pocock **彻底将 Refactor（重构）步骤从 TDD 循环中物理剔除**，将核心法则严格锁定为纯粹的 **Red $\to$ Green**！虽然为了向下兼容，Prompt 唤醒词依然保留了 "red-green-refactor" 作为触发词（详见仓库未决的 [issue #589](https://github.com/mattpocock/skills/issues/589)），但执行规范明确宣判：重构不属于 TDD 循环。 [来源：`tdd` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/tdd.md)

为什么他选择在 Agent 技能中剔除被经典敏捷方法论奉为基石的“重构”环节？

这一反直觉决策的底层，可以用[《第二篇》](/zhangmuchuan/blog/agent-control/)的**霍华德信息价值净收益方程**给出终极解释：

$$
V(a \mid C_t) = \operatorname{VoI}(a) - \lambda \operatorname{Cost}(a)
$$

在单步微循环刚刚翻绿的瞬间，系统的状态发生了什么变化？
1. **增量信息价值归零（$\operatorname{VoI} \to 0$）**：当前用例已经全绿，关于目标功能特性的不确定性已被消除。纯粹的代码重构并不改变外部行为，对当前任务目标不提供任何新增功能信息；
2. **执行风险与成本骤增（$\operatorname{Cost} \gg 0$）**：大模型在单个微循环内的注意力窗口是高度聚焦且脆弱的。若强行要求它在同一个上下文内“顺便把代码改得优雅”，模型立刻陷入多目标冲突：既要守住断言，又要调整抽象。社区工程实战表明（Matt 在文档中明确记录：*agents almost never performed it*），让 Agent 在微循环里自主重构，极易诱发逻辑幻觉、改坏既有断言，甚至在局部陷入反复调试的死循环。

代入方程，在微循环内执行重构动作的净收益为负：$V(a_{\text{重构}} \mid C_{\text{green}}) < 0$！

Matt 的工程破局法极其冷峻：**通过关注点分离（Separation of Concerns），重构职责整体后置**：
- **`tdd` 技能只专注一件事**：在约定的接缝上，以最小代码增量打通红绿闭环；
- **重构职责整体移交**：后置给独立的 [`code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 技能，在一个清空了实现杂讯的全新上下文窗口中，从全局视角把控架构演化。

#### 反馈延迟与成本权衡：为什么严禁在 TDD 里跑浏览器？
在测试粒度上，Matt Pocock 同样记录过惨痛教训：有开发者让 Agent 在 TDD 极小循环里直接写 Playwright 端到端浏览器测试。结果 Agent 花费了海量时间反复重跑无头浏览器，面对网络波动和异步加载，甚至误判测试框架损坏。因为 `/tdd` 技能并未在代码层面硬拦截这种行为，Matt 建议必须在项目的 `CLAUDE.md` 中显式确立禁令：浏览器测试必须等底层核心逻辑验证通过后才能编写。

代入霍华德方程，原因显而易见：
- 内存级的轻量接口测试：运行仅需毫秒级，$\operatorname{Cost}(a) \to \min$，能以极高频度向 Agent 泵送确定性反馈，净价值 $V(a)$ 达到极大值；
- 浏览器端到端测试：涉及页面渲染、网络加载与环境搭建，$\operatorname{Cost}(a)$ 暴增数十倍，反馈周期严重拖长，彻底摧毁了 TDD 负反馈闭环的经济性。

![一次行为的测试与反馈循环](images/tdd-feedback-loop.png)

**微观循环靠秒级轻量测试纠偏，宏观集成靠端到端流水线把关。** 搞混了两者的节奏，整个开发系统就会被自身过载的测试拖垮。

---

### 结语：测试不是终点，而是照亮代码的一面镜子

重新审视 TDD 在大模型时代的定位，我们终于能给出客观清醒的回答：

测试先亮起红灯，并不代表 Agent 就自动获得了真理；但没有事先见证过失败的绿灯，必然是一场虚假的繁荣。

Matt Pocock 的 `tdd` 给出的工程破局之道，是一套严密的工程约束机制：
1. **用红灯打破自评幻觉**，让外部运行环境的客观事实取代模型的封闭推演；
2. **用独立前馈基线粉碎同源盲区**，绝不允许期望值沦为实现的镜像复算；
3. **用公开接缝屏蔽实现噪声**，将 Mock 严格限制在系统不可控边界，守护自研模块的真实契约；
4. **用务实的 Red-Green 剪枝重构复杂性**，通过轻量级高频反馈实现信息净价值的最大化。

测试从来不是开发的终点，它是架设在代码演化悬崖边上的物理护栏。

当 Agent 已经在单张工单内部掌握了红绿穿梭的微观技艺，下一步，它又该怎样将这些散落的代码片段、通过测试的增量特性，真正整合成可以合入主干、交付生产的高质量工程成果？

在下一篇中，我们将继续推演：测试全部通过之后，Agent 怎样才能真正把工作安全地交出去？

---

### 参考资料

- [数学基石篇](/zhangmuchuan/blog/agent-math-foundations/)；[第一篇：架构的必然演进](/zhangmuchuan/blog/agent-loop/)；[第二篇：控制权的收放艺术](/zhangmuchuan/blog/agent-control/)；[第三篇：驯服长程循环](/zhangmuchuan/blog/agent-harness/)；[第六篇：穿越时间的 Context](/zhangmuchuan/blog/agent-memory/)。
- [解构 Matt Pocock 的 Skills（五）：把任务切开之后，Agent 怎样更早看见自己做得对不对（新稿）](/zhangmuchuan/blog/matt-pocock-skills-05/)。
- [tdd 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/SKILL.md)、[测试设计指南](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/tests.md)、[Mock 指南](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/tdd/mocking.md)、[tdd 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/tdd.md)。
- [implement 规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement/SKILL.md)、[implement 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/implement.md)、[code-review 规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md)。
- 关于 to-tickets、TDD 与反馈的讨论；关于测试接缝与验收标准的讨论；[AI Skills with Matt Pocock 播客访谈记录](https://www.youtube.com/watch?v=4DhcSPkEbwI)。
