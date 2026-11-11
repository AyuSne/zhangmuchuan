---
title: "Claude Code 团队如何做代码审查"
date: 2026-11-11
description: "当智能体以惊人规模产出代码时，你该如何做好代码审查？在 Claude Code 团队，在建立起高覆盖率和深度审查后，我们开始全力优化一个指标：在不增加回滚和线上故障的前提下，将人类审查时间压到最低。"
tags: ["AI", "Claude Code", "代码审查", "AI Agent"]
draft: false
---

> 原文：[How the Claude Code team does code review](https://claude.dev/blog/solving-code-review-at-anthropic/)；原作者：Addy Osmani、Morgan Westlee Lunt、Qing Wang；原文发表：2026-10-15

当智能体以惊人的速度大量生成代码时，你该如何做好代码审查（Code Review）？在 Claude Code 团队，当我们的测试覆盖率与自动化审查深度就绪之后，团队便开始全力优化一个指标：**在不增加代码回滚（Revert）与线上故障（Incident）的前提下，把人类投入的审查时间压到最低。**

我们之前曾提到过，Claude 编写了 [Claude Code](https://claude.com/product/claude-code) 自身约 90% 的代码。那么，面对如此庞大的产出规模，我们究竟是如何审查代码的？现在还有人会读代码吗？如果系统被改出了 Bug，到底由谁来兜底捕获？

本文将全面介绍 Claude Code 团队的代码审查流程及其演进历程。从今年 6 月到 9 月，合入 Claude Code 代码库的 Pull Request（PR）数量翻了一倍以上，而其中被迫回滚的比例却下降了 40% 以上。

我们并未取消审查。但我们确实把绝大多数阅读工作交给了机器，把人类有限的时间与注意力留给刀刃，并不惜重金投入，让撤销任何错误变得极其迅捷与轻松。

## 重新审视代码审查的意义

当智能体开始编写代码，代码变更的数量便会呈爆发式增长。在 Anthropic 的单体代码仓库（Monorepo）中，每日合入的代码变更从今年 5 月的约 [2,500 次猛增至 9 月的 30,000 多次](https://www.anthropic.com/engineering/redesigning-source-control)。

Claude Code 拥有自己独立的代码库，并未与主 Monorepo 放在一起，但也同样承受着巨大的交付压力。在如此疾速的发布节奏下，人工逐行审查代码即便并非不可能，也早已变得难以为继。

代码审查承担着两项使命：

1. 在代码发布上线之前发现并修复问题；
2. 在团队内部建立共识，促进大家对代码库的整体理解。

本文主要聚焦于第一项使命——发现并修复问题；而在文章结尾，我们将重新探讨第二项使命。

我们认为，“是否有真人通读了代码？”这并不是衡量代码质量的好指标。我们真正应该追问的是：“**这次变更可能出现什么差错？在自动化检查与人工介入之间，哪一种检查手段才是捕获该问题的最佳选择？**”

提出这个问题，也彻底颠覆了审查发生的**时间节点**。过去，审查就像是流程末端的一道关卡：写完代码，发起 PR，然后坐等同事抽空审阅。

而现在，审查在全程持续运行，更像是边打字边生效的拼写检查（Spellcheck）。绝大多数变更在提交给人类审阅之前，都已经被 Claude 审查并自动修复过至少一轮。这直接拦截了绝大多数常规错误，把团队宝贵的注意力解放出来，留给更高层次的架构考量与深入审视。

## 稀缺的资源：人类的时间与注意力

我们希望把人类的时间与注意力留给只有人类才能解决的问题，并确保自动化检查能够拦截其余所有差错。按照目前的代码变更速率，人类依然有海量工作需要完成，团队几乎每天都会遇到前所未见的新颖挑战。

审查的“人类时间成本”体现在两端：一端是人们花在审查上的时间，另一端则是人们用来排查修复劣质代码引发故障的时间。如果压缩了审查时间，却把时间倒扣在后期的故障救火上，那就毫无意义。

因此，我们的目标是：让 Claude Code 相关代码库（CLI 命令行工具、桌面端、Web 端以及移动端应用）中的绝大多数 PR，**在最多只有一位人工介入（且该介入者可以就是 PR 作者本人）的前提下顺利合入，同时回滚率和线上故障率绝不上涨**。为了精准度量人类时间投入，我们跟踪了每个 PR 的人工批准次数（中位数与 P95）、人工评论数以及 PR 等待人工响应的时长。回滚率与事故率就是坚实的护栏：一旦它们上升，就说明我们并没有节省人类时间，只不过是在拆东墙补西墙。

## 代码变更的生命周期

一次典型的变更，从工程师的笔记本电脑（或是 Slack 中的一次 Claude 交互会话）发起，会经历层层级联的代码审查流程。

从作者的本地开发机到最终交付用户，一次典型的 Claude Code 代码变更流程如下：

<svg aria-hidden="true" focusable="false" id="code-review-life-of-a-change-mobile" width="300" height="797" viewBox="2 0 300 797" xmlns="http://www.w3.org/2000/svg" style="max-width: 420px; margin-inline: auto; display: block;"><path d="M11 34.5 L11 671.5" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:currentColor"></path><circle cx="11" cy="34.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="34.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 34.5 L10.2 36.8 L14.2 32.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><circle cx="11" cy="147.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="147.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 147.5 L10.2 149.8 L14.2 145.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><circle cx="11" cy="210.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="210.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 210.5 L10.2 212.8 L14.2 208.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><circle cx="11" cy="290.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="290.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 290.5 L10.2 292.8 L14.2 288.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><circle cx="11" cy="353.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><polygon points="11,346.5 18,353.5 11,360.5 4,353.5" style="fill:currentColor"></polygon><circle cx="11" cy="449.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="449.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 449.5 L10.2 451.8 L14.2 447.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><circle cx="11" cy="545.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="545.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 545.5 L10.2 547.8 L14.2 543.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><circle cx="11" cy="608.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="608.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 608.5 L10.2 610.8 L14.2 606.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><circle cx="11" cy="671.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><path d="M16.6 673.5 A6 6 0 1 1 14.4 666.5" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><path d="M11.6 664.9 L14.6 666.5 L13.6 669.7" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><text x="32" y="14" font-size="12.75" font-weight="500" letter-spacing="0.08em" style="fill:currentColor">创建 PR 之前</text> <text x="32" y="39" font-size="14" font-weight="500" style="fill:currentColor">在本地完成双重验证</text> <text x="32" y="57" font-size="13" style="fill:currentColor">Claude 运行测试、构建与 Linter；</text> <text x="32" y="74" font-size="13" style="fill:currentColor">第二智能体在全新上下文审查 Diff</text> <text x="32" y="91" font-size="13" style="fill:currentColor">确保本地逻辑严密完备</text> <text x="32" y="127" font-size="12.75" font-weight="500" letter-spacing="0.08em" style="fill:currentColor">每个 PR 必经流程</text> <text x="32" y="152" font-size="14" font-weight="500" style="fill:currentColor">强制 CI 检查</text> <text x="32" y="170" font-size="13" style="fill:currentColor">代码规范、类型、跨平台测试与打包</text> <text x="32" y="187" font-size="13" style="fill:currentColor">任何红灯直接阻断合并</text> <text x="32" y="215" font-size="14" font-weight="500" style="fill:currentColor">Claude 代码审查</text> <text x="32" y="233" font-size="13" style="fill:currentColor">智能体并行找 Bug，多模型交叉投票</text> <text x="32" y="250" font-size="13" style="fill:currentColor">存留问题按严重程度排序后呈现</text> <text x="32" y="267" font-size="13" style="fill:currentColor">附带分类标签与具体代码行证据</text> <text x="32" y="295" font-size="14" font-weight="500" style="fill:currentColor">独立安全审查</text> <text x="32" y="313" font-size="13" style="fill:currentColor">专属安全扫描通道。遗留任何未决</text> <text x="32" y="330" font-size="13" style="fill:currentColor">问题都会直接阻断 PR 合并</text> <text x="32" y="358" font-size="14" font-weight="500" style="fill:currentColor">按风险分级审批</text> <text x="32" y="376" font-size="13" style="fill:currentColor">分类器定级：免人工、一人或两人</text> <text x="32" y="393" font-size="13" style="fill:currentColor">敏感路径必须由人类负责把关</text> <text x="32" y="429" font-size="12.75" font-weight="500" letter-spacing="0.08em" style="fill:currentColor">合并阶段</text> <text x="32" y="454" font-size="14" font-weight="500" style="fill:currentColor">合并队列 (Merge Queue)</text> <text x="32" y="472" font-size="13" style="fill:currentColor">基于最新的 main 主干代码与变更</text> <text x="32" y="489" font-size="13" style="fill:currentColor">完整重跑全量校验流程</text> <text x="32" y="525" font-size="12.75" font-weight="500" letter-spacing="0.08em" style="fill:currentColor">合并之后</text> <text x="32" y="550" font-size="14" font-weight="500" style="fill:currentColor">开关保护，内部员工先行试用</text> <text x="32" y="568" font-size="13" style="fill:currentColor">在推向全体外部用户之前，先由</text> <text x="32" y="585" font-size="13" style="fill:currentColor">Anthropic 内部高频实战运行</text> <text x="32" y="613" font-size="14" font-weight="500" style="fill:currentColor">渐进式分批发布</text> <text x="32" y="631" font-size="13" style="fill:currentColor">优先推送至 latest 尝鲜频道；</text> <text x="32" y="648" font-size="13" style="fill:currentColor">stable 稳定频道稍后平稳跟进</text> <text x="32" y="676" font-size="14" font-weight="500" style="fill:currentColor">持续观测、前向修复或秒级回滚</text> <text x="32" y="694" font-size="13" style="fill:currentColor">作者与 On-call 盯盘；开关秒级关闭，</text> <text x="32" y="711" font-size="13" style="fill:currentColor">故障版本立即执行 Git Revert</text> <circle cx="11" cy="738.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><circle cx="11" cy="738.5" r="6.5" fill="none" stroke-width="1" style="stroke:#888"></circle><path d="M8 738.5 L10.2 740.8 L14.2 736.3" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><text x="32" y="743" font-size="13" style="fill:currentColor">全自动化流程</text> <circle cx="11" cy="762.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><polygon points="11,755.5 18,762.5 11,769.5 4,762.5" style="fill:currentColor"></polygon><text x="32" y="767" font-size="13" style="fill:currentColor">人工决策（按风险定级）</text> <circle cx="11" cy="786.5" r="7" stroke-width="2" style="fill:Canvas;stroke:Canvas"></circle><path d="M16.6 788.5 A6 6 0 1 1 14.4 781.5" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><path d="M11.6 779.9 L14.6 781.5 L13.6 784.7" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:currentColor"></path><text x="32" y="791" font-size="13" style="fill:currentColor">故障兜底与恢复</text></svg>

**图 A** 整个链路绝大部分已实现自动化；人类的注意力精准投向风险所在之处。

## 层层防线：六级校验与秒级回滚

六道检查关卡，并在其下方配以快速回滚机制作为安全托底：

<svg aria-hidden="true" focusable="false" id="code-review-layers-mobile" width="300" height="304" viewBox="0 0 300 304" xmlns="http://www.w3.org/2000/svg" style="max-width: 420px; margin-inline: auto; display: block;"><text x="2" y="14" font-size="13" style="fill:currentColor">问题输入</text> <path d="M82 22 L82 278" fill="none" stroke-width="1" stroke-dasharray="3 3" style="stroke:currentColor"></path><path d="M24 22 L24 45" fill="none" stroke-width="1" stroke-dasharray="3 3" opacity=".55" style="stroke:currentColor"></path><path d="M140 22 L140 45" fill="none" stroke-width="1" stroke-dasharray="3 3" opacity=".55" style="stroke:currentColor"></path><path d="M40.6 55.5 L40.6 85" fill="none" stroke-width="1" stroke-dasharray="3 3" opacity=".55" style="stroke:currentColor"></path><path d="M126.2 95.5 L126.2 125" fill="none" stroke-width="1" stroke-dasharray="3 3" opacity=".55" style="stroke:currentColor"></path><path d="M54.4 135.5 L54.4 165" fill="none" stroke-width="1" stroke-dasharray="3 3" opacity=".55" style="stroke:currentColor"></path><path d="M116.5 175.5 L116.5 205" fill="none" stroke-width="1" stroke-dasharray="3 3" opacity=".55" style="stroke:currentColor"></path><path d="M35.1 215.5 L35.1 245" fill="none" stroke-width="1" stroke-dasharray="3 3" opacity=".55" style="stroke:currentColor"></path><polygon points="2,60 140,60 162,44 24,44" stroke-width="1" style="fill:currentColor;stroke:currentColor"></polygon><ellipse cx="82" cy="52" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><ellipse cx="40.6" cy="52" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><text x="174" y="56.5" font-size="13" style="fill:currentColor">本地双重验证</text> <polygon points="2,100 140,100 162,84 24,84" stroke-width="1" style="fill:currentColor;stroke:currentColor"></polygon><ellipse cx="82" cy="92" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><ellipse cx="126.2" cy="92" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><text x="174" y="96.5" font-size="13" style="fill:currentColor">强制 CI 检查</text> <polygon points="2,140 140,140 162,124 24,124" stroke-width="1" style="fill:currentColor;stroke:currentColor"></polygon><ellipse cx="82" cy="132" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><ellipse cx="54.4" cy="132" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><text x="174" y="136.5" font-size="13" style="fill:currentColor">Claude AI 审查</text> <polygon points="2,180 140,180 162,164 24,164" stroke-width="1" style="fill:currentColor;stroke:currentColor"></polygon><ellipse cx="82" cy="172" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><ellipse cx="116.5" cy="172" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><text x="174" y="176.5" font-size="13" style="fill:currentColor">独立安全审查</text> <polygon points="2,220 140,220 162,204 24,204" stroke-width="1" style="fill:currentColor;stroke:currentColor"></polygon><ellipse cx="82" cy="212" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><ellipse cx="35.1" cy="212" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><text x="174" y="216.5" font-size="13" style="fill:currentColor">人工风险审批</text> <polygon points="2,260 140,260 162,244 24,244" stroke-width="1" style="fill:currentColor;stroke:currentColor"></polygon><ellipse cx="82" cy="252" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><ellipse cx="131.7" cy="252" rx="10" ry="3.5" stroke-width="1" style="fill:Canvas;stroke:currentColor"></ellipse><text x="174" y="256.5" font-size="13" style="fill:currentColor">合并队列 + 开关</text> <path d="M82 48.5 L82 255.5" fill="none" stroke-width="1" stroke-dasharray="3 3" style="stroke:currentColor"></path><circle cx="24" cy="50" r="4.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="140" cy="50" r="4.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="40.6" cy="90" r="4.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="126.2" cy="130" r="4.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="54.4" cy="170" r="4.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="116.5" cy="210" r="4.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="35.1" cy="250" r="4.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><path d="M48 276 Q82 304 116 276" fill="none" stroke-width="1" style="stroke:currentColor"></path><circle cx="82" cy="286" r="5.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><text x="174" y="290.5" font-size="13" font-weight="500" style="fill:currentColor">秒级快速回滚</text></svg>

**图 B** 每一层防线都会拦截部分问题并漏掉其他问题。极少有差错能侥幸穿透全部六道关卡，而快速回滚则兜底处理其余意外。

### 1. 代码在任何人审阅之前，已在本地得到验证

如今，绝大部分代码审查早在 PR 正式创建之前就已经完成了。我们会给 Claude 提供可供其运行的具体校验手段——例如运行测试用例、执行构建、或者截屏与设计稿比对——并明确要求它出示实际运行结果，而不是光说一句“做好了”。接着，一个拥有干净、全新上下文的子智能体（Subagent）会去审查这份代码差异（Diff）。这两个工作习惯均源自我们的[最佳实践指南](https://code.claude.com/docs/en/best-practices)。

在正式发起 PR 之前，团队许多成员还会调用几个[内部专属技能（Skills）](https://claude.dev/blog/lessons-from-building-claude-code-how-we-use-skills/)：一个负责巡检潜在 Bug，一个负责精简 Diff 变更，还有一个从头到尾端到端校验业务逻辑。如果是 UI 变更，还会对照团队的设计规范进行核验。

Claude Code 的创造者 Boris Cherny 曾指出，给 Claude 提供验证其自身工作成果的途径，[可以说是取得优质产出最重要的一环](https://x.com/bcherny/status/2007179861115511237)。据他估计，这种验证手段能让最终产出质量提升两到三倍。他写道：“不同业务领域的验证方式各有不同。它可以简单到只跑一条 Bash 命令、运行一套测试套件，也可以是在真实浏览器或手机模拟器中对应用进行实测。”

**如果自动化审查智能体反复提出同类意见，我们就会从源头修复它：** 直接修改 Skill 逻辑、增加 Lint 规则，或者更新以下这类指引文件：

- `CLAUDE.md`：用于告知 Claude 整个项目的概貌——技术栈、代码约定、目标与非目标（Non-goals）。由于每次审查都会加载此文件，因此在大型代码库中我们保持其精简，并从这里链接指向其他专项文档。审查智能体还会特别指出破坏其中约定、或是导致某行指引过期的代码变更。
- `REVIEW.md`：由各模块的代码所有者（Code Owner）编写，用于告知审查智能体其负责的代码区域究竟什么才是核心关注点。我们会独立抽检审查智能体是否切实遵守了该指引。优秀的 `REVIEW.md` 通常非常精炼：它们会写明该代码库里的“失败”究竟指什么（对于文档库而言是“产生误导”，对于配置库而言是“路由错误”）；限制无关紧要的挑刺（Cap the nits）；列出可以跳过的忽略路径；并要求必须给出具体文件和代码行作为证据，杜绝凭空妄加猜测。此外，它们还会要求在审查摘要开头标注问题总数，并在确实没有需要修复的问题时坦诚直言。

### 2. 每个 Pull Request 都经历 AI 审查

每个 PR 在有人类查看之前，都会先接受一次 Claude 的审查。它会结合整个代码库的上下文以及 PR 陈述的意图来审视 Diff，并反思：这项变更是否真正解决了目标问题？是否契合现有架构？是否会破坏系统其他部分？

面对 Bug 修复类 PR，它会追查根本原因（Root Cause）。该功能的公开版本——[Claude Code 代码审查（Code Review for Claude Code）](https://code.claude.com/docs/en/code-review)目前已面向 Team 和 Enterprise 用户正式推出，而在本地运行 `/code-review` 则能执行轻量级审查。

当我们最初[上线研究预览版](https://claude.com/resources/articles/code-review)时，Anthropic 内部获得实质性审查意见的 PR 比例从 16% 猛增到 54%。大多数超过 1,000 行的 PR 都会被找出实质问题，而大多数小型 PR 则能干净利落地通过。管理员可为各个代码库配置审查级别：快速（Quick）、标准（Standard）或深度（Deep）。在那些漏掉一个 Bug 的代价远高于审查耗时的关键仓库中，“深度”审查绝对物有所值。

**审查发现的问题在呈现给人类之前，先由其他智能体交叉验证。** 系统会派出多个智能体同时并行排查 Bug；随后由另一组独立的智能体对每个找出的问题进行投票表决，只有当足够多的智能体一致确认该问题确实存在且属实时，它才会被正式发布出来。纯粹关于代码风格、临时诊断日志或边角清理的意见会被直接过滤抛弃。在正式采用这些过滤规则前，我们在自己的 PR 上进行了充分的 A/B 测试。最终筛选出的问题会按严重程度排序，以行内评论的形式展示；每个问题都会被打上“重要（Important）”、“细微挑刺（Nit）”或“历史遗留（Pre-existing）”标签，确保那些原本就存在于旧代码中的陈年旧账不会被算在当前 PR 作者头上。

**每条审查意见都必须得到回应。** 你要么动手修好它，要么在回复中阐明理由并关闭该讨论串（Thread）。通常，智能体会通宵接管并修复这些问题；第二天早晨作者回到电脑前时，PR 往往已经自动完成了新一轮的代码迭代。

### 3. 拥有硬性阻断权的安全审查

安全审查同样拥有自己独立的自动化轮次。只要 Bug 审查或安全审查中还存在任何尚未关闭的问题，PR 就绝不允许合并。作者必须要么修复该漏洞，要么写下简短说明关闭讨论串——这也是标记并消除误报（False Positive）的标准方式。

如果后续的代码提交修复了该问题，系统会自动解除标记。你也可以通过开源的安全审查 GitHub Action 或本地 `/security-review` 命令搭建完全相同的机制。具体配置可参阅 [Claude Code 自动化安全审查指南](https://support.claude.com/en/articles/11932705-automated-security-reviews-in-claude-code)。

### 4. 强制阻断的自动化流水线检查

这一层涵盖最常规的防线：代码规范检查（Lint）、类型检查、跨平台测试套件运行以及完整构建打包。（针对在此类庞大体量下如何拓展 CI 流水线容量，我们曾在此撰文：[智能体编码正在对 CI 带来严峻考验：Anthropic 如何拓展测试影响分析](https://claude.com/resources/articles/agentic-coding-is-straining-ci-heres-how-we-scaled-test-impact-analysis-at-anthropic)）。一个典型的 CLI 仓库 PR 在人类看第一眼之前，可能已经静默运行了几十项检查。PR 模板中会明确要求说明“该变更经过了怎样的测试”以及“发生问题时该如何撤销回滚”。Claude 可以代为填好这些内容，但最终必须由提出这项需求的人员签字确认。

### 5. 基于风险等级定级的人工审批

修改一篇开发文档与修改自动更新器（Auto-updater）所承受的风险天差地别，因而享受的审查规格也截然不同。

| 风险等级 | 典型范例 | 所需人工审批数 |
| --- | --- | --- |
| 低（Low） | 文档、文案、纯内部功能、受功能开关保护的纯增量改动 | 自动化审查与安全检查全绿后，**无需人工介入（0人）** |
| 中（Medium） | 普通产品功能变更，以及涉及缓存、自动更新器或系统提示词等敏感区域的修改 | **1 人** |
| 高（High） | 风险等级最高的核心代码，以及一小批明文规定始终需要两人复核的受控路径 | **2 人** |

**定级取决于“变更本身”，而非“谁是作者”。** 系统会通过分类模型通读本次代码变更并评估其风险等级；第二个分类器则会进一步甄别：即便该级别的规则允许免审，本次变更是否仍有特殊风险需要拉入额外的人工审阅？此外，某些特殊路径始终需要人工把关——所有被模块所有者标记为高危敏感的目录，以及任何 CI 工作流配置文件均属此类。

**只有受信作者才能走轻量审批通道。** 只有身处仓库“受信任作者白名单”（通常是所属模块的负责团队）中的成员，才能享受轻量或免审通道；其他人的变更一律需要额外的人工批准。此外，**智能体的“批准”永远不能等同于人类批准**。自动化审查可以放行低风险改动，但当规则要求必须有人类签字时，智能体无法越俎代庖。

**谁给智能体下指令，谁就要负全责。** 在由智能体编写的 PR 中，负责指挥该智能体的人类工程师会被计入所需审查人员配额之中，权责等同于亲自手写了这批代码。

**每一次批准严格绑定具体的 Commit。** 如果后续有系统无法担保的新 Commit 入库（例如智能体又推了一版代码，或者有人手动解了冲突），之前的批准即刻失效，必须重新审批。

### 6. 合并队列、特性开关与渐进式发布

合并队列（Merge Queue）会将当前变更预先合入主干（main）分支的最新代码，并对合并后的状态完整重跑所有检查。这样就彻底杜绝了“两个 PR 单独测试全都通过，合在一起却让 main 分支挂掉”的经典噩梦。新功能通常会置于特性开关（Feature Flag）之下，先交付给 Anthropic 内部员工日常高频使用，我们自身严苛的“吃狗粮”体验往往能在外部用户发觉之前提前暴露绝大多数退化（Regressions）。对外公开发布时，新版本会先推送至 `latest` 尝鲜频道，经过充分沉淀后再同步至 `stable` 稳定频道。

### 7. 敏捷侦测与秒级快速回滚

百密终有一疏，因此最后一道防线聚焦于“极速感知与止损”。特性开关无需重新走发布流水线即可一键秒关。Claude Code 团队设有每周轮值值班制度（On-call Rotation），在每次故障复盘（Incident Review）中，核心议题永远是：“系统现有的哪一层防线本应在上线前捕获该问题？”

目前，察觉异常合并仍然高度依赖 PR 作者本人、值班人员以及实时回滚与故障监控大盘。我们目前尚未引入“根据故障指标异动而自动收紧人工审批门槛”的自动化熔断机制；但团队工程师们普遍希望在将更多代码放行给“零人工审查（Zero-human merges）”之前，能把这套熔断护栏先搭建完备。

一位同事曾深刻指出：放慢交付速度确实能降低出错率，但那主要是因为你干的活变少了。我们宁愿选择变得更快——更快地发现问题，更快地修复问题。

## 持续进化：如何让审查智能体越变越强

我们的代码审查流程始终处在一个不断自我优化的良性闭环之中。

**每一宗线上故障，如今都沉淀为评测集（Eval）。** 团队收集了过去引发过线上故障的所有历史 PR，整理了它们的前向补丁与紧急回滚代码，并由熟悉该业务的资深工程师逐一核验确认每个 Bug 的成因及具体位置。审查智能体每天都会针对该评测集全量运行打分。

基于过往故障与回滚沉淀建立，每日自动运行：

<svg aria-hidden="true" focusable="false" id="code-review-incident-eval-mobile" width="300" height="306" viewBox="0 0 300 306" xmlns="http://www.w3.org/2000/svg" style="max-width: 420px; margin-inline: auto; display: block;"><text x="46" y="14" font-size="14" font-weight="500" style="fill:currentColor">线上故障或代码回滚</text> <text x="46" y="32" font-size="13" style="fill:#888">破坏了系统运行的代码变更</text> <text x="46" y="66" font-size="14" font-weight="500" style="fill:currentColor">资深工程师核实案例</text> <text x="46" y="84" font-size="13" style="fill:#888">熟悉代码的专家确认 Bug</text> <text x="46" y="118" font-size="14" font-weight="500" style="fill:currentColor">沉淀入评测集</text> <text x="46" y="136" font-size="13" style="fill:#888">每起故障新增一个评测 Case</text> <text x="46" y="170" font-size="14" font-weight="500" style="fill:currentColor">每日自动执行评测</text> <text x="46" y="188" font-size="13" style="fill:#888">对全量历史案例逐一打分</text> <text x="46" y="222" font-size="14" font-weight="500" style="fill:currentColor">综合评分是否提升？</text> <text x="46" y="240" font-size="13" style="fill:#888">提升则保留；反之果断废弃</text> <text x="46" y="274" font-size="14" font-weight="500" style="fill:currentColor">迭代调优审查智能体</text> <text x="46" y="292" font-size="13" style="fill:#888">优化提示词、工具或模型</text><path d="M30 19.5 L30 51.5" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:#888"></path><path d="M26.5 47.5 L30 51.5 L33.5 47.5" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:#888"></path><path d="M30 71.5 L30 103.5" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:#888"></path><path d="M26.5 99.5 L30 103.5 L33.5 99.5" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:#888"></path><path d="M30 123.5 L30 155.5" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:#888"></path><path d="M26.5 151.5 L30 155.5 L33.5 151.5" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:#888"></path><path d="M30 175.5 L30 207.5" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:#888"></path><path d="M26.5 203.5 L30 207.5 L33.5 203.5" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:#888"></path><path d="M30 227.5 L30 259.5" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:#888"></path><path d="M26.5 255.5 L30 259.5 L33.5 255.5" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:#888"></path><path d="M20 269.5 L8 269.5 L8 165.5 L20 165.5" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:#888"></path><path d="M16 162 L20 165.5 L16 169" fill="none" stroke-width="1" stroke-linejoin="round" stroke-linecap="round" style="stroke:#888"></path><circle cx="30" cy="9.5" r="5.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="30" cy="61.5" r="5.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="30" cy="113.5" r="5.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="30" cy="165.5" r="5.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="30" cy="217.5" r="5.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle><circle cx="30" cy="269.5" r="5.5" stroke-width="2" style="fill:currentColor;stroke:Canvas"></circle></svg>

**图 C** 评测集伴随每起故障不断扩充，对审查智能体的任何微调改动都会对照全量案例严格打分。

**我们通过观察开发者对审查意见的处置行为，来量化噪音。** 如果不在乎报出一堆非 Bug 的杂音，多找 Bug 是很容易做到的，因此我们必须建立针对噪音的制衡检查。我们根据开发者在 PR 上的处置反馈，对审查智能体留下的每条意见进行分类统计：开发者是动手修了、指出这是误判、澄清该行为是刻意设计的预期逻辑，还是认为根本无足轻重？我们还会把审查智能体扔到已知毫无问题的干净 PR 上运行，统计它有多少次提出了原本可能诱导开发者写出有害改动的错误建议。我们白纸黑字写明的优先级原则是：**首要任务是抓出真实的 Bug，次要任务才是削减审查轮数。**

**当代码作者是智能体时，噪音带来的代价反而更高。** 真人工程师可以在几秒钟内把一条鸡毛蒜皮的意见（Nit）挥手掠过；而智能体却会老老实实去改，这意味着又一次提交和新一轮审查。

**审查必须收敛（Convergence）。** 智能体作者与智能体审查者很容易陷入彼此不断挑刺与修改的无休止内耗死锁。曾有一个 CLI 仓库的 PR 在夜间经历了一百多次审查与修复死循环，直到第二天作者人工叫停。

当我们用 `git blame` 深入排查审查智能体反复纠缠的代码时，发现大约 59% 的代码早在审查的第一轮就已客观存在。智能体审查者几乎很少发现全新的 Bug，它只是在每一轮审查中翻出一些原本就存在的陈年旧代码继续挑刺。

而且我们自己还一度加剧了这种恶性循环：我们曾习惯于默认多跑几轮审查，因为每一轮总能挑出点新东西。在风险极高的大型改动中这或许值得，但绝不适用于每一个 PR。目前团队在跟踪召回率（Recall）的同时密切监控“通过审查所需轮数（Rounds-to-pass）”，并对复审机制进行了针对性重构：

- **设立轮数硬上限：** 经历 3 轮审查后，审查智能体会强制要求作者停下来，重新审视技术路线；
- **后续仅针对增量 Diff 审查：** 在最初几轮过后，不再全量扫描，严格仅审查新增的变更差异；
- **按“缺陷类别”整体指出：** 提示作者一次性修复该类别的所有同类实例，而不是按单行零敲碎打；
- **坚决不重复翻旧账：** 已经发布过的意见不再重复提出。

此外，审查智能体还会在夜间对现有存量代码库进行全局离线扫描，帮助我们在旧 Bug 蔓延到其他地方之前就地解决。

内部 Pull Request 在收敛机制治理前后的对比：

<svg aria-hidden="true" focusable="false" id="code-review-convergence-mobile" width="300" height="273" viewBox="0 0 300 273" xmlns="http://www.w3.org/2000/svg" style="max-width: 420px; margin-inline: auto; display: block;"><text x="2" y="14" font-size="13" font-weight="500" style="fill:currentColor">仅经一轮审查与修复即顺利通过</text> <rect x="2" y="26" width="149.5" height="14" style="fill:currentColor"></rect><text x="159.5" y="37" font-size="13" font-weight="400" style="fill:currentColor">65%</text> <rect x="2" y="46" width="179.4" height="14" style="fill:currentColor"></rect><text x="189.39999999999998" y="57" font-size="13" font-weight="500" style="fill:currentColor">78%</text> <path d="M2 76 L296 76" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:currentColor"></path><text x="2" y="96" font-size="13" font-weight="500" style="fill:currentColor">需要 5 轮及以上审查</text> <rect x="2" y="108" width="20.5" height="14" style="fill:currentColor"></rect><text x="30.47" y="119" font-size="13" font-weight="400" style="fill:currentColor">8.9%</text> <rect x="2" y="128" width="3.4" height="14" style="fill:currentColor"></rect><text x="13.45" y="139" font-size="13" font-weight="500" style="fill:currentColor">1.5%</text> <path d="M2 158 L296 158" fill="none" stroke-width="1" stroke-linejoin="round" style="stroke:currentColor"></path><text x="2" y="178" font-size="13" font-weight="500" style="fill:currentColor">平均通过审查所需轮数</text> <rect x="2" y="190" width="159.5" height="14" style="fill:currentColor"></rect><text x="169.5" y="201" font-size="13" font-weight="400" style="fill:currentColor">2.08</text> <rect x="2" y="210" width="101.2" height="14" style="fill:currentColor"></rect><text x="111.2" y="221" font-size="13" font-weight="500" style="fill:currentColor">1.32</text> <rect x="2" y="239" width="10" height="10" style="fill:currentColor"></rect><text x="18" y="248" font-size="13" style="fill:currentColor">治理前</text> <rect x="2" y="259" width="10" height="10" style="fill:currentColor"></rect><text x="18" y="268" font-size="13" style="fill:currentColor">收敛机制治理后</text></svg>

**图 D** 引入收敛优化后，内部 Pull Request 的平均审查轮数显著下降。

## 人类审查者该坚守何处

打断一位资深工程师的深度专注，只为了让他抓出一个普通的低级错误，其成本远高于运行一次自动化审查。团队中的工程师依然对以下关键事务全权负责：

- **决定到底做不做：** 把控业务方向、产品品味与需求范围。某支团队在宣布彻底破解了代码审查瓶颈后，依然保留了对团队外部提交变更的人工把关，就是为了有人能站在宏观角度灵魂拷问：“我们真的有必要做这个功能吗？”
- **审查高危核心代码：** 例如计费系统、自动更新程序以及核心 CI 工作流。
- **审视系统架构设计：** 把关那些会确立新范式并被其他开发者效仿借鉴的架构决策。
- **查验证据凭据：** 审阅测试用例输出、具体执行的命令及返回结果、截图证据以及审查智能体的结论。如果你说不清楚现有的自动化检查究竟会漏掉什么，那就要求进行一次严肃的人工深审，而不是盲目快速放行。
- **为最终结果兜底：** 无论代码是由谁敲出来的，每一次发布的变更最终都必须由具体的人类承担完全责任。

## 如何在团队内部共享业务上下文

代码审查的第二项核心使命，向来是增进团队对代码库的整体认知。通读队友提交的 Diff，历来是了解系统改动与架构拼接方式的核心途径。如果机器代劳了绝大部分阅读工作，大家该如何掌握代码库呢？

对此我们没有设立死板的正式流程。团队里没有任何一个人能在脑海中维持一套 Claude Code 完整无缺的心智模型，我们也不认为有谁需要做到这一点。当有人需要理解代码库的某个局部模块时，他们会直接让 Claude 为这个特定的代码切片编写一份专门的解说（Explainer）。只需几分钟，一份完全映射当前最新代码实况的解读便呈现在眼前。

![“如果机器代劳了绝大部分阅读，大家该如何掌握代码？”架构示意图](https://claude.dev/media/d4fafcbf3d2137bc64eb7f0707ba91809ff1ed4d098785e36d7422b3b07f6c40.png)

图注：“如果机器代劳了绝大部分阅读，大家该如何掌握代码？”左侧网格代表整个代码库，高亮部分为你需要理解的代码局部切片（如托管设置模块）；无人需要在大脑中记忆全部代码细节。只需向 Claude 提出针对该切片的具体问题（例如：“Claude Code 是如何检索托管设置的？”），Claude 就能在几分钟内生成反映当前最新代码实况的针对性解说；团队成员甚至还可以让 Claude 构建轻量级可视化交互组件进行直观教学。底部对比显示：逐行阅读琐碎的 Diff（如改动一行文案）几乎学不到任何知识，而在修改模块前获取一份专属解说则大有裨益。

团队中还有一些人走得更远，他们会要求 Claude [构建一个可视化微组件（HTML Artifact）](https://claude.dev/blog/using-claude-code-the-unreasonable-effectiveness-of-html/)，把那部分代码的逻辑关系直观地画出来，用每个人最适应的方式来学习与理解。

如果最终目标是高效利用人类宝贵的注意力，这种按需解说的方式比逐行死磕无聊琐碎的 Diff 要高明得多。审查一行文案变更几乎无法让你学到任何架构知识；但在你准备大改某个模块之前，让 Claude 为你出具一份专属解读，却能让你收获颇丰。此外，我们默认在 Slack 公开频道（Open channels）协作的团队文化也起到了关键作用——当别人正在构建某些模块时，你可以随时在公开视野中围观进展。

## “谁合的代码，谁负全责”

如果你合入了一项中小型变更，而系统随后出现了差错，按照团队惯例，通常由你负责把它摆平。几项核心工程机制保障了这种敏捷责任制不会走向失控与灾难：

- **变更粒度极小：** 每次改动都保持小巧，易于审查、易于调试、更易于一键回滚。
- **一切皆可撤销：** 功能开关、Git Revert 与分阶段灰度发布，能确保绝大多数错误在几分钟内被彻底撤销。
- **依据爆炸半径设定门槛：** 故障代价高昂的核心代码，自然会配置更多的人工把关和更严密的校验流水线。
- **异常退化快速显现：** 借助完备的遥测监控与内部团队的高强度日常试用，潜在缺陷能迅速浮出水面。
- **对事不对人，绝非问责惩戒：** 让你兜底修复是因为你对这次改动拥有最充分的上下文；故障复盘关注的永远是系统机制漏洞，而不是指责个人。

这种主导权也是全员共享的。团队绝大多数成员都在公开频道中展开日常工作，任何人都能看到他人正在构建什么、随时接管某个讨论串、或是指派一个 Claude 实例去填补某处空白；许多宝贵的反馈往往恰恰来自那些并非该模块代码负责人的工程师。这种极具透明度的开放文化，正是我们在无需对每一行代码死板设卡的前提下，依然能维持极高软件质量的制胜法宝。

## 当我们决定调转船头

智能体让开启一项新任务的边际成本变得微不足道，这也意味着许多写出来的代码其实根本不该合入。通常情况下，频道里有人会出面追问“为什么做这个”、指出此前团队既定的技术决议、或是提议一条更轻巧简捷的技术路径，于是 PR 作者便会果断关闭该 PR 或重新调整方案。

既然代码是在极短时间内由智能体飞速写完的，直接关闭 PR 并不会让人产生沉没成本的痛惜感。关键秘诀在于：**尽早在讨论串中提出不同的探索方向，而不是在一个已经彻底完工的 PR 上扔下一句冷冰冰的阻断性反对意见。**

## 如何将这套流程迁移应用到你的团队

如今，支持你在团队中落地这套模式的绝大多数拼图都已完备可用。

### 创建 Pull Request 之前

- **为你的智能体提供切实可跑的校验指令：** 将其清晰列在精炼的 `CLAUDE.md` 中，并配置能自动触发格式化（Formatter）和代码检查（Linter）的 Git Hooks。
- **在本地先行审查：** 在本地运行 `/code-review` 和 `/security-review`，或者启动一个拥有干净上下文的子智能体进行 Diff 复核。
- **引入 `REVIEW.md` 规范：** 将日常人工审查中反复被提及的意见，沉淀并转移到 `REVIEW.md` 文件中。

### 每个 Pull Request 的把关要求

- **设立硬性 CI 卡点：** 在 PR 模板中增加“如何测试（Testing）”、“风险评估（Risk）”以及“如何回滚（How to revert）”三大必填项。
- **部署 AI 审查工具：** 先在一个代码仓库试点部署 AI 审查（例如 Claude Code 的 Code Review 功能，或 Claude Code GitHub Action），对 `REVIEW.md` 进行数周调优打磨，随后推广到全组织。
- **接入自动化安全审查：** 要求在 PR 最终合入前，必须彻底解决或回复所有审查讨论串。
- **审查力度与风险精准匹配：** 对日常例行变更采用快速扫描（Quick），对漏网 Bug 代价沉重的核心区域采用深度审查（Deep）。
- **限制审查轮数：** 设立轮数上限；在前几轮过后，后续审查严格仅针对新增的增量 Diff 进行，杜绝翻陈年旧账。

### 审批阶段规则

- **白纸黑字明确风险分级：** 依据“代码变更本身”而非“代码作者”来划分风险等级；起步阶段宁严勿宽，随着实测数据积累逐步放宽。
- **轻量审批通道仅对受信任作者开放：** 将低门槛放行权限严格限定在受信团队名单内。
- **善用 CODEOWNERS 与分支保护：** 强制要求涉及认证、计费、CI 发布流水线及安装打包等关键模块的修改，必须有人类审批把关。
- **绝不允许机器人顶替人类审批：** 只要有新 Commit 推入，此前给出的批准一律自动作废，必须重新审批。

### 合并阶段与发布之后

- **构建安全发布护栏：** 结合合并队列（Merge Queue）、功能开关（Feature Flags）、内部员工先行试用（Dogfooding）、分阶段灰度发布以及一键快速回滚机制。
- **将故障转化为进化驱动力：** 将历次线上事故与回滚沉淀为基准评测集（Eval set），每当审查工具的 Prompt、工具集或基座模型发生变更时，跑全量用例重新打分。
- **精准度量人类时间成本：** 以代码回滚率与线上事故率作为核心守底指标，持续监控人类审查时间的节省效果。

## 未来的演进方向

在 Code Review 的[官方发布公告](https://claude.com/resources/articles/code-review)中曾强调，批准一个 Pull Request 依然是人类的专属决策权限；该产品输出的是分析结论，而非批准许可。但在 Anthropic 我们自己的代码仓库里，我们探索得更深远：模块所有者可以自主决定，哪些低风险变更能够完全基于自动化检查放行合入，而且这条边界始终在动态向前推进。

每当自动化审查漏掉某个差错时，我们都会复盘追问：基座模型在审查时究竟缺少了哪项关键上下文？随后便把解决方案沉淀进 `CLAUDE.md`、定制成专属 Skill、或是写成一项全新的校验规则。我们的核心目标始终未变：**单次代码变更耗费更少的人类时间，同时系统回滚率绝不高于以往。**

如果你的团队也开始允许智能体提交 Pull Request，我们非常渴望倾听你的声音：你们实现了哪些检查的自动化？哪些环节仍然不可或缺地需要人类坚守？以及你们觉得我们的实践中还有哪些可以改进的地方？

*在此特别致谢 Emma Webb、Michael Segner 与 Amie Rotherham 对本文提出的宝贵审阅意见。*
