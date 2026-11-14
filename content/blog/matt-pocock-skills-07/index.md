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

### 引子：同一个会话里，审查为什么总是变成“自我表扬”？

用编码 Agent 久了，很多人都有过这种啼笑皆非的体验——先举一个常见假设场景：

> Agent 刚在对话里帮你写完一整套取消会员订阅的逻辑。为了图省事，你顺手在同一个窗口里发了一句：“请再帮我严格审查一遍刚写的代码。”
>
> 几秒钟后，它输出了一段结构工整、语气诚恳的审查总结：“模块化清晰，函数拆分合理，异常处理完备，已遵循项目命名约定。”
>
> 可你自己低头一看实现，核心业务却直接写反了：工单要求取消后保留到期前权益，代码却在取消那一刻把状态设成了立即失效。前面几轮写代码时它就已经这么理解了，到这一步“自查”，它只不过换了一种更像架构师的腔调，把自己刚才的想法又夸了一遍。

在 [`code-review` 说明文档](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)里，有一位读者把这件事总结得特别损、也特别准：

> **“同一个上下文审查自己，不叫代码审查；那只是披着斜杠命令外衣的确认偏误（Confirmation Bias with a slash command）。”** [来源：`code-review` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)

为了跳出这种“自己给自己发奖状”的怪圈，Matt Pocock 的 [`/code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 选择了另外一套做法：把自查拆开，每次必须从一个新的独立视角出发，同时派两个互不见面的子 Agent，沿着**编码规范（Standards）**和**需求规格（Spec）**两条轴线，分别检查从某个固定基点到 `HEAD` 之间的代码差异。

这套设计看上去规整得多。但真正放到实际工程里，几个更深的问题很快就会冒出来：
- 为什么“规范”和“需求”一定要掰成两半、连打个综合总分都不允许？
- 只要换了一个干净的新 Agent 会话，它就一定能把隐藏的错看出来吗？哪些错哪怕换十个新窗口也照样看不出来？
- 为什么自动审查配自动修复，跑着跑着经常变成越改越乱的死循环？

作为这个系列的最后一篇，我们用信息论、期望信息净价值方程，以及我们在[《第三篇》](/zhangmuchuan/blog/agent-harness/)建立的 **$(P, M, H)$ 协同框架**，把自动代码审查能做什么、不能做什么一次说透。

---

### 一、为什么要把“规范”和“需求”拆成两把尺子，还不许合并打分？

如果先回到[《数学基石篇》](/zhangmuchuan/blog/agent-math-foundations/)与[《第二篇：控制权的收放艺术》](/zhangmuchuan/blog/agent-control/)，就会发现把所有审查任务全塞进同一个大模型提示词里，同时犯了三条第一性原理大忌：

1. **同一窗口内的注意力竞争**：模型要在单一上下文 $C_t$ 里同时检索“仓库格式规范”和“业务逻辑需求”，两条线索互相争夺有限的有效注意力容量，容易因为局部命名或缩进瑕疵而漏掉深层需求偏差；
2. **用高成本、带随机方差的 $M$ 替代零方差、近零成本的 $P$**：像缩进、未使用变量、类型错误这类确定性规则，本就属于计算成本 $\operatorname{Cost}(P) \ll \operatorname{Cost}(M)$ 且方差 $\operatorname{Var}(P) = 0$ 的确定性 Harness 程序检查范围，根本不该浪费语言模型去肉眼审查；
3. **两个正交目标空间禁止标量折叠**：代码写得规不规范（$Z_{\text{规范}}$）和需求有没有实现完整（$Z_{\text{需求}}$）属于两个**正交目标维度**，强行合并打一个总分，就会用“代码干净”的得分遮蔽“做错功能”的致命偏差。

人类做代码审查时也常犯同样的毛病：看到缩进歪了、变量名不好听，很容易抓着风格挑半天刺，却忘了核对功能到底有没有做对。

生活里有个很直观的对账场景：一家餐厅请督导员抽查出餐质量，实际上有两件彼此独立的事要盯——**第一，后厨卫生和摆盘规矩守没守住；第二，菜有没有按客人点的单做对、上对桌。**

想象两种截然不同的翻车现场：
- 第一种：厨师刀工一流、蔬菜切得整整齐齐、盘子擦得锃亮、灶台消过毒一尘不染（$Z_{\text{规范}}$ 满分）；可客人点的明明是清蒸鲈鱼，他端上来一盘红烧肉（$Z_{\text{需求}}$ 零分）。
- 第二种：端上桌的确实是一条火候完美、不放香菜的清蒸鲈鱼（$Z_{\text{需求}}$ 满分）；但推开后厨门一看，生肉和熟菜混在同一张案板上切，抹布黑得发亮（$Z_{\text{规范}}$ 不及格）。

你会把这两项按五五开平均成一个“综合 80 分，准予过关”吗？当然不会。干净的盘子抵消不了上错菜，上对菜也抵消不了后厨卫生违规。

这正是 [`code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 采用**双轴独立审查（Dual-Axis Review）**的原因：

![同一份改动分别对照需求和项目规范](images/code-review-two-axes.png)

1. **Standards 轴（问“造得对不对”）**：由一个独立子 Agent 负责。它先去翻当前仓库里明文写下的规范（比如 `CODING_STANDARDS.md`、`CONTRIBUTING.md`），再在底下垫一套 Martin Fowler《重构》第三章里的 12 项代码异味清单（比如神秘命名、重复代码、特征依恋、霰弹式修改等）作为通用参考。但规范划了一道很清楚的优先线：**仓库自己的明文规矩永远压倒通用异味清单；如果仓库文档明确认可某种写法，哪怕像异味也得闭嘴；并且所有异味都只是“带着语境的判断线索”，不是硬违规；至于 Linter 和编译器已经能抓出来的格式或类型问题（属于零方差确定性检查 $P$ 的职责），一律跳过不审。**
2. **Spec 轴（问“造的是不是对的东西”）**：由另一个完全隔离的子 Agent 负责。它去读原始的 Issue、Ticket 或 Spec（按提交信息里的 Issue 引用 $\to$ 用户传入的路径 $\to$ `docs/`、`specs/`、`.scratch/` 匹配 $\to$ 直接问用户这个顺序找）。专门查三件事：需求漏做了没有（Missing）、做了没让做的多余功能（Scope Creep），以及表面做了但理解跑偏的实现（Wrong implementation）。而且，按**信息不能在无外部基准输入时凭空推导（定理二无外部证据欠决定性与定理六同源反推失效的同一根约束）**的边界：**如果确实找不到任何 Spec，这条轴就直接停掉，报告“无可用 Spec”，绝不允许对着代码反向猜需求。**
3. **汇总时严禁合并重排（No Re-ranking）**：两个子 Agent 互相看不见对方的推理过程；最后汇总报告时，必须分别在 `## Standards` 和 `## Spec` 两个独立标题下各自输出，末尾也只分别给出“每一轴各自最严重的一条问题”，绝对不允许把两轴揉进一张榜单排总分。

此外，这套审查流水线还暴露出一条容易被忽略的 **Harness 路由与命名空间隔离问题**（见 [`code-review` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)）：Claude Code 自己也内置了一个叫 `/code-review` 的技能，但它干的是“在 Diff 里找空指针、竞态条件、边界 Bug”，而不是对照你的 Spec 和仓库规范做双轴审计。两个同名技能装在同一个调度入口 $P$ 下就会发生路由遮蔽——要么通过插件前缀隔离命名空间，要么删掉内置技能、或者把本地副本改名。

---

### 二、换一个新会话，就真的打破盲区了吗？（从定理五到定理六）

把审查交给两个刚启动的新子 Agent，在信息论上究竟赚到了什么，又还有什么是它突破不了的天花板？

先看它确实赚到的那一笔，对应[《数学基石篇》](/zhangmuchuan/blog/agent-math-foundations/)里的**定理五（脑内纯复盘增量归零定理）**：设代码在真实环境下的真实质量为 $Z$，实现者模型当前持有的内部上下文为 $C_t$。在没有任何独立于 $C_t$ 的外部验证输入时，它顺着旧上下文直接产出的自我点评 $R_{\text{自评}}$ 满足马尔可夫链：

$$
Z \longrightarrow C_t \longrightarrow R_{\text{自评}}
$$

由条件独立性立刻得到：

$$
I(Z; R_{\text{自评}} \mid C_t) = 0
$$

当写代码的 Agent 在原来的上下文 $C_t$ 里自我复盘时，没有任何独立于 $C_t$ 的新信息源进来，它的自我点评对确认代码真实质量 $Z$ 增量为零。不仅如此，正如[《第六篇：穿越时间的 Context》](/zhangmuchuan/blog/agent-memory/)所分析的，这间屋子里早就堆满了刚才调试时的试错残骸、先入为主的辩护理由和已经发散掉的草稿。

把审查工作挪进一个全新的子 Agent 窗口，物理效果相当于把那间乱糟糟的工作台全部换掉：审查员以一张干净的白板进场，面前只摆着客观的 `git diff` 文本、仓库规范文件和 Spec 原文。**这样做的真实收获，是洗掉了实现者的过程残骸和历史包袱，让注意力以高信噪比重新扫一遍事实。**

但是——千万别以为只要“换了一个新窗口”，审查就彻底独立、万无一失了。

这就撞上了《数学基石篇》里的**定理六（同源盲区）**。在本系列此前的分析里，我们对定理六成立的本质条件做过一次非常关键的校准：**同源盲区真正依赖的条件，并不限于“是不是同一个模型、是不是同一个上下文窗口”，而在于双方是不是共享了同一个错误假设 $\hat{Z}$！**

用日常场景来感受这个边界再清楚不过：
- 你在厨房灶台前连续炒了一个小时菜，满屋子油烟早把鼻子熏麻了，这时候你自己尝一口汤，根本尝不出是咸了还是淡了——这叫**过程污染（定理五）**。你把刚进店上班、味蕾还干干净净的同事叫过来帮你尝一口，确实一下子就能尝出是不是多放了一勺盐。
- 可是，如果**客人点菜那张菜单上本来就漏印了“严重花生过敏”这行字，而且你和这位刚上班的同事又都是跟着同一个师父学艺、习惯“做宫保鸡丁必须抓一把花生米才算地道”**——新来的同事尝了一口，照样会由衷地对你竖起大拇指：“火候正宗，一点毛病没有！”

这就是**共同条件分布下的同源采样失败**。回到数学表达上：设这一类隐性需求遗漏对应真实盲区 $Z_{\text{盲区}}$，实现者 $M_1$ 与审查员 $M_2$ 在同源训练先验与同一份有遗漏的 Spec 条件下分别独立采样，不约而同地基于条件分布 $P(\hat{Z} \mid \text{Spec})$ 落进了同一个有偏差的默认假设 $\hat{Z}$；而审查员黑屋里只读得到上下文 $C_{\text{审查}} = (\text{Spec}, \text{Diff})$，真实盲区、这份共同偏差与最终审查报告 $R_{\text{审查}}$ 之间构成马尔可夫链：

$$
Z_{\text{盲区}} \longrightarrow (\hat{Z}, C_{\text{审查}}) \longrightarrow R_{\text{审查}}
$$

于是，在共同先验偏差 $\hat{Z}$ 和干净上下文 $C_{\text{审查}}$ 给定之后，审查员对暴露这部分共同盲区的新增信息量严格归零：

$$
I\big(Z_{\text{盲区}}; R_{\text{审查}} \;\big|\; \hat{Z}, C_{\text{审查}}\big) = 0
$$

这就是为什么前一篇讲 `to-spec` 和 `grilling` 时一再强调要在动手前找人类把模糊需求盘清，也是为什么不能把“换个 Agent 审一遍”当成可以替代独立测试和人工核验的万能保险。

---

### 三、审查意见只是“线索假说”，不是已经落锤的事实

就算独立上下文成功抓出了一堆毛病，接下来怎么用这份审查报告，也有一道很深的坑：大模型写出来的审查结论，**看上去总是语气笃定、条例分明，但里面完全可能夹着编造的行号、看岔的函数名或者夸大的后果。**

在[《第三篇》](/zhangmuchuan/blog/agent-harness/)里，我们一直在区分两种身份截然不同的信息：**客观事实（Evidence）**和**模型推演出的假说（Hypothesis）**。编译器报的第 42 行语法错误、测试退出码返回 `1`，是客观事实；而模型扫完一段 Diff 后说“这段逻辑可能在高并发下导致数据不一致”，哪怕说得再像那么回事，本质上也只是一条待核实的**语义假说**。

Matt Pocock 在 [`code-review` 说明文档](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)里把这件事讲得非常坦白：
- **“Sub-agent output is a hypothesis, not evidence.”（子 Agent 的输出只是假说，不是证据。）**
- 技能汇总两个子 Agent 的报告时，并不会自己去源码里把每一条指控核验一遍才放出来，所以报告完全可能引错位置或者虚报影响。
- 虽然这个机制帮某团队抓出了普通文字总结审查漏掉的十几处破坏性改动（*a dozen breaking changes*），但用的人必须自己顺着引文去原文件核对，绝不能看见一条意见就闭着眼改。

这就像去医院拍胸片做初筛：放射科辅助筛查系统在片子上标了一个红框，提示“左肺第 3 肋旁疑似有阴影，请重点复查（附上切片层数和坐标）”。这个提示极其有用，能帮医生省掉大量漏看风险；但没有任何一位外科医生会只凭初筛提示就直接拉病人进手术室开刀，他必须自己调出原片、结合化验单亲自核实。

所以 [`code-review/SKILL.md`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 对输出格式立了一道硬约束：**不带精准出处的意见一概不算数。** Standards 轴指出的每一条问题，必须附上仓库规范文件名与具体条款，或者具体代码异味名称加上对应的代码片段（hunk）；Spec 轴指出的每一条问题，必须逐字贴出对应的 Spec 原文行。出处写清楚了，人类或后续验证流程才有一条可追查、可证伪的核对线索。

顺带提一个 [`code-review` 说明文档](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)里公开承认、截至当时仍未修复的运行时 Bug：**两个子 Agent 的提示词里没有禁止自己再次调用技能或派发新 Agent**。社区有用户多次复现过，审查子 Agent 在执行过程中又自己唤醒 `/code-review` 递归裂变，一口气生成了**超过 50 个子 Agent 进程**！按[《第三篇》](/zhangmuchuan/blog/agent-harness/)的工程边界，提示词里的口头嘱咐永远只是低确定性的软约束；要防止子 Agent 无限裂变，最终必须交给确定性 Harness 程序 $P$ 在运行期对递归深度和并发上限做硬熔断，而不是指望模型自己克制。目前的应急修法是在两个子 Agent 的指令末尾手动加上一句“禁止再调用 `/code-review` 或派发额外子 Agent，直接完成本次审查”。如果要在无人值守流程里跑它，必须盯紧进程和派发深度限制。

---

### 四、为什么自动审查接自动修复，容易滚成永不收敛的死循环？

用上自动审查后，很多人的下一个念头顺理成章：既然它能查出毛病，那我写个循环让它“查出问题 $\to$ 自动修复 $\to$ 再查一遍”，直到报“零问题”再停下，岂不是全自动完美交付？

现实中恰恰相反，这是最容易烧光额度、甚至把好代码改坏的一条路。[`code-review` 说明文档](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)里直接引了一位用户的现场经历：

> “`/code-review` 和 `/improve-code-architecture` 每次运行都能找出一堆新毛病。我就照着改，改完再跑，跑完再改，无穷无尽。” [来源：`code-review` 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)

文档随后给出了一句非常清醒的判断：**这个技能没有任何收敛保证（There is no convergence guarantee）**，千万不要试图把它跑到“干干净净、一条意见都没有”为止，因为那一天永远不会来。

为什么会这样？拿[《第二篇：控制权的收放艺术》](/zhangmuchuan/blog/agent-control/)里的**期望信息净价值方程（方程二）**来算一笔账就明白：

$$
V(a \mid C_t) = \operatorname{VoI}(a) - \lambda \operatorname{Cost}(a) \equiv \Delta I_{\text{反馈}}(a) - \lambda \operatorname{Cost}(a)
$$

把这里面的变量对齐到“再跑一轮审查与修复”这个动作 $a$ 上：
- $C_t$ 是当前审查轮次掌握的全部上下文信息；
- $\operatorname{VoI}(a) \equiv \Delta I_{\text{反馈}}(a)$ 是动作 $a$ 预期能为“合并或打回代码”这项核心决策带来的信息价值——它取决于审查结果能否真正改变最优决策（$\frac{\partial a^*}{\partial O} \neq 0$）；
- $\operatorname{Cost}(a)$ 是动作代价，不仅包括消耗的 Token 费用和等待时间，**更包括“每次改代码都有可能把原本已经写对的地方改出新 Bug”的回归成本**；$\lambda > 0$ 是单位代价的权重系数。

这就像你请了两位美术顾问，轮流帮你审一张马上要印刷的活动海报：
- **第一轮（$\operatorname{VoI} \gg \lambda \operatorname{Cost}$）**：顾问一眼扫出两处硬伤——“联系电话少写了一位”、“活动日期写成了去年”。这直接把决策从“误以为可以印”改成“必须立刻打回修正”（$\frac{\partial a^*}{\partial O} \neq 0$），$\operatorname{VoI}$ 极大，直接避免印一万张废纸。
- **第二轮、第三轮之后（$\operatorname{VoI} \to 0$，但 $\operatorname{Cost}$ 上升）**：硬伤全清干净了，剩下的意见全部滑向主观审美偏好。第二轮顾问 A 说：“我觉得主标题往左挪两毫米更有呼吸感。”你改完送去第三轮，顾问 B 却说：“其实还是居中对齐显得稳重，顺便把副标题调细一号吧。”

每多改一轮，都要重新排版打样（算力与时间成本），更麻烦的是，来回挪版面时一不小心把原本改对的电话号码又蹭掉一位（引入回归缺陷的风险）；而对“客户能不能打通电话报名参加活动”这项决策来说，这些微调不会改变“海报已可用”的判断（$\frac{\partial a^*}{\partial O} \approx 0$），多出来的有效信息价值 $\operatorname{VoI}(a)$ 已经趋近于零。

按《数学基石篇》的停机准则，一旦当前所有可选动作的最大期望净价值跌破零：

$$
\max_{a \in \mathcal{A}} V(a \mid C_t) \le 0
$$

系统就应该果断停手并交给人拍板。而把 `Issues == 0` 设成自动重跑审查的唯一停机条件，等价于把 $\max_a V(a \mid C_t) \le 0$ 整条停止线撕掉，强迫系统停留在 $V(a \mid C_t) < 0$ 的负收益区继续空转。

再加上每一次修复本身都会往 Diff 里塞入新代码，而 `Standards` 轴里那 12 条代码异味本来就是带着随机波动的主观判断（Judgement calls），新代码一进去，审查员立刻又能挑出新的“可能命名不够直白”或“这段也许能再拆一下”。于是整个系统就被锁死在反复修改却永不收敛的震荡里。

所以，把 [`code-review`](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md) 放进我们在[《第三篇》](/zhangmuchuan/blog/agent-harness/)建立的 **$(P, M, H)$ 三维协同裁判席**里，它的位置和停止线非常清楚：

1. **程序 $P$（编译器、类型检查、Linter、只读测试套件）**：站在最前面，零成本、零方差地拦截所有客观硬事实。能用 $P$ 测出来的，绝不花钱让模型去猜。
2. **语义模型 $M$（双轴独立子 Agent）**：做一轮高信噪比的扫描，输出一份**带着精确出处（规则名/代码片段/Spec 原文行）的待证假说清单**。硬违规（漏了 Spec、违背明文规范）修复后做定点复核即可，主观异味线索供人参考，不拿来死磕到零。
3. **人类 $H$（开发者/架构师）**：站在最后面，对照 $P$ 的事实和 $M$ 给出的引文线索拍板取舍，确认业务意图没有被同源偏误歪曲，并承担最终合并的责任。

---

### 结语：把八篇文章串成同一根线

从第一篇拆解 `wayfinder` 的项目地图开始，到 `grill-me` 逼出隐性需求、`to-spec` 把探索结果压成带接缝的规格、再到本组四篇——`to-tickets` 纵向切单、`tdd` 守住红绿边界、`implement` / `implement-spec` 管好并发与交接、最后到 `code-review` 双轴核验收尾——回头看这套完整的开源技能库，真正有意思的地方并不在于那几个斜杠命令怎么写。

恰恰在于每一个看着琐碎的工程规矩背后，几乎都能看到同一套第一性原理的影子：
- 模型坐在看不到外部真相的黑屋里，所以要切纵向切片、跑红灯测试、拿 Diff 而不是凭记忆自查；
- 上下文里的过程残骸会拉低信噪比，所以要每票一会话、把讨论和实施分开、用独立上下文做审查；
- 同源假设会制造共同盲区，所以断言期望值要取自独立基线，Spec 要提前把歧义盘出来，审查意见也只能当线索由人拍板；
- 每次交互和改动都在花钱、也在引入新风险，所以要从 TDD 里砍掉微循环重构、拦住慢速浏览器测试、也在一轮审查清掉硬伤之后果断喊停。

工具链的名字过半年也许还会变，提示词的写法也还会随着模型升级一轮轮精简。但只要大模型还是在上下文窗口里做条件推断、需要通过外部环境拿到真反馈，这些围绕信息边界、控制闭环与验证独立性算出来的账，就一直算数。

---

### 参考资料

- [数学基石篇](/zhangmuchuan/blog/agent-math-foundations/)；[第一篇：架构的必然演进](/zhangmuchuan/blog/agent-loop/)；[第二篇：控制权的收放艺术](/zhangmuchuan/blog/agent-control/)；[第三篇：驯服长程循环](/zhangmuchuan/blog/agent-harness/)；[第六篇：穿越时间的 Context](/zhangmuchuan/blog/agent-memory/)。
- [解构 Matt Pocock 的 Skills（六）：测试先亮红灯，Agent 就真的知道自己做对了吗（新稿）](/zhangmuchuan/blog/matt-pocock-skills-06/)；[解构 Matt Pocock 的 Skills（七）：测试通过以后，Agent 怎样把工作真正交出去](/zhangmuchuan/blog/matt-pocock-skills-implement/)。
- [code-review 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/code-review/SKILL.md)与[code-review 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/code-review.md)。
- [implement 技能规范](https://github.com/mattpocock/skills/blob/4ae2317/skills/engineering/implement/SKILL.md)与[implement 说明](https://github.com/mattpocock/skills/blob/4ae2317/docs/engineering/implement.md)。
- [Matt Pocock 访谈记录](https://www.youtube.com/watch?v=4DhcSPkEbwI)。
