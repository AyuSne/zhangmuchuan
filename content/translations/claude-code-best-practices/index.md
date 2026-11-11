---
title: "Claude Code 最佳实践"
date: 2026-11-11
description: "充分释放 Claude Code 的潜能：告知模型它看不见的信息、为其提供可执行的校验回路，并把不可破例的规则变成刚性约束。"
tags: ["AI", "Claude Code", "最佳实践", "开发工具"]
draft: false
---

> 原文：[Best practices for Claude Code](https://code.claude.com/docs/en/best-practices)；原作者：Anthropic

Claude Code 的设计初衷是：在绝大多数情况下，你在全新会话中敲下的第一句普通提示词，无需任何前期配置，就能把事情办妥。

例如：

- 为了让命令安全运行而无需你每次手动点选同意，新的终端和 VS Code 会话默认以[自动模式（Auto mode）](https://code.claude.com/docs/en/permission-modes#eliminate-prompts-with-auto-mode)启动；独立的风险分类模型会在任何高危操作执行前进行审查把关。
- 为了在并行处理独立任务的同时保持主对话的整洁聚焦，Claude 会自动将任务分派给子智能体（Subagents），只有在确有必要时才向你同步汇报。
- 为了让你无需手动干预即可维持长时间会话，系统会在上下文窗口被填满之前，自动对当前对话进行压缩（Compaction）。

而本文则重点探讨：**当默认设置无法满足需求时，你该如何应对。** 这种情况通常发生在你的项目包含某些 Claude 单凭阅读代码无法察觉的隐性知识、刚性规则或外部边界时：

- 仅存在于某些人口口相传中的部署流程；
- 绝不能被随意读取的敏感文件；
- 只有全绿通过才算“真正搞定”的核心检查；
- 必须严格控制的成本与 Token 预算。

没有任何开箱即用的默认规则能未卜先知地洞悉你项目的这些独特性，因此，花少量精力完成针对性配置将为你带来极高的回报。

当一次交互会话未达到你的预期时，根本原因几乎总能归结为以下几点之一：

[让 Claude 无人值守自主运行](#让-claude-无人值守自主运行)一节将同样的四点原则拓展至无人值守场景；而[可以停止做的事](#可以停止做的事)一节则盘点了随着当前模型能力跃升而已变得不再必要的旧有习惯。

团队级别的全员配置指南可参阅独立专题：[为你的组织配置 Claude Code](https://code.claude.com/docs/en/admin-setup)。

## 确定性指令与非确定性指令

你向 Claude Code 下达的每一条指令，本质上都属于以下两类之一：

1. **非确定性指令（Non-deterministic）**：由你写下指令，由 Claude（基座模型本身）阅读理解。这可以体现在你的提示词（Prompt）、`CLAUDE.md` 文件或自定义技能（Skill）中。模型随后自行裁决如何运用这些信息。它通常会遵从你的要求，且当代模型无需过多铺垫就能精准理解你的真实意图；但系统**并不担保**它每一次都能百分之百丝毫不差地执行。在某些情况下，它依然可能自行决定略过某些步骤，或采取其他做法。
2. **确定性指令（Deterministic）**：由你配置规则，由 Claude Code（宿主运行框架 Harness）**强制执行**。这可以是一个钩子（Hook）、一条拒绝规则（Deny rule）或统一管控设置（Managed setting）。无论基座模型心里怎么想，Claude Code 都会每一次不折不扣地刚性执行该配置。

Claude Code 中的绝大多数控制能力都同时具备这两种形式：

| 维度 | 非确定性（由 Claude 自主裁决） | 确定性（由 Claude Code 强制执行） |
| --- | --- | --- |
| **做什么** | 你的提示词、`CLAUDE.md`、Claude 自行挑选调用的技能 | 钩子（Hooks），以及仅限你手动触发的专属技能 |
| **能接触什么** | 自动模式（Auto mode）下的风险分类模型 | 拒绝规则（Deny rules）、[严格模式](https://code.claude.com/docs/en/sandboxing#turn-off-the-retry-with-strict-sandbox-mode)下的沙箱、集中受控设置 |
| **何时算完成** | 索要执行证据、`/goal` 目标判定、`/code-review` 审查 | 自动化测试、类型检查、`Stop` 终止钩子、CI 流水线 |
| **花多少成本** | 思考力度等级（Effort level）、Claude 自身的推演节奏 | 配合 `-p` 使用的 `--max-turns` 或 [`--max-budget-usd`](https://code.claude.com/docs/en/cli-reference)、自定义[支出上限](https://code.claude.com/docs/en/costs) |
| **谁拥有一票否决权** | Claude 对自身产出所做的执行摘要 | 分支保护规则（Branch protection）、人工合并审批人 |

在绝大多数日常场景中，你应当充分信任并放手让 Claude 自主裁决。世间几乎所有编码规范都存在合理特例，而当前一代的模型极其擅长结合眼前具体的代码上下文，权衡某项约定是否契合当前场景。面对真实的鲜活代码，Claude 往往比你提前写好的死板规则更能做出精准的决断。

而**确定性指令**的用武之地，在于你必须确保某些行为**始终发生**（或绝不允许发生），完全不给模型的自由裁量留任何余地。这并不一定非得是什么惊天动地的大事。自动模式本身就已经默认[拦截了诸如直接推向生产环境或强推覆写同事工作等极端危险行为](https://code.claude.com/docs/en/permission-modes#what-the-classifier-blocks-by-default)。确定性规则更多用来约束那些针对你**具体项目**的特定诉求，哪怕再小众垂直也无妨：

- 绝对不要手动修改 `src/gen/` 目录下的自动生成客户端代码；
- 新建任何文件后，必须立刻运行脚本注入开源协议头（License header）。

你当然可以把这些要求作为单行文字写在 `CLAUDE.md` 或直接放在 Prompt 里，在绝大多数轮次中 Claude 确实都会照做。但无论你的用词语气多么严厉，在某次具体的交互中模型是否真的遵照执行，依然属于它自己的判断范畴。

**如果你发现自己在 `CLAUDE.md` 中反复给某行文字加粗加叹号，而 Claude 依然会偶尔漏掉它，这就是一个极其明确的信号：该规则应该移入 Hook 中刚性保障！** 反之亦然：如果你为了某些纯属个人偏好、允许灵活变通的事情写了 Hooks，不妨删掉它们，交由 Claude 自由裁量。

## 告知模型它看不见的信息

**只记录 Claude 无法通过阅读代码库直接获取的信息，或者那些它每轮会话都必须耗费大量时间重新探查的隐性知识。**

Claude 开启每项任务的第一步永远是阅读你的代码，而当前一代模型在这方面的表现**极其强悍**。它们能迅速梳理出你的文件目录结构、代码约定、测试框架以及现有组件的构建范式，其速度往往比你用文字向它交代还要快得多。这意味着：绝大多数你想随手写给它的指引，Claude 其实早就已经看在眼里了。

它真正无法获取的，是那些**从未白纸黑字写入代码库中的信息**：

- 团队在某次闭门会议中达成的一致决策；
- 只留在某位架构师脑海中的部署流程；
- 运行集成测试所必需配置的外部环境变量。

此外，还有一些信息虽然确实留在代码库里，但每次往往需要几分钟的深度挖掘才能找齐，导致 Claude 在每次新会话启动时都不得不重新翻箱倒柜排查一遍。

在向 Claude 写下任何指令之前，不妨先做这两道黄金自测题：

1. 它能单凭阅读现有代码得出这个结论吗？
2. 在实际任务中，它真的会主动去翻阅那部分代码吗？

如果两者的答案都是肯定的，那就果断省去这段描述。

### 给出具体的提示词

撰写具体明确的提示词（Prompt）之所以立竿见影，正是因为它直接向 Claude 注入了它此前未曾掌握的关键增量信息。如果你提前指明具体文件、详述问题表象，并从一开始就界定清晰“怎样才算彻底修好”，通常能省去后续多轮反复纠错的拉扯。

面对两种都合理的方案抉择时同样如此：Claude 无法从代码中猜出你的主观偏好，如果你对此有所要求，就务必在开局阶段直截了当地讲明。

| 不要这样写 | 试着这样写 |
| --- | --- |
| *“修复登录 Bug”* | *“用户反馈会话超时后重新登录会失败。请查看 `src/auth/` 下的 Token 刷新逻辑，写一个能复现该问题的失败测试用例，然后将其修好。”* |
| *“增加一个日历组件”* | *“参考 `HotDogWidget.php` 中的设计模式，构建一个支持选择月份与年份翻页的日历组件。不要引入任何新的第三方依赖库。”* |

如果你手上已经拥有 Claude 所需的物料，直接提供给它，而不是费口舌去描述：

- **文件**：输入 `@` 紧跟路径，直接将[文件内容内联引入](https://code.claude.com/docs/en/common-workflows#reference-files-and-directories)你的对话中；
- **图片**：直接在提示词中粘贴设计稿原型图或报错截图；
- **命令输出日志**：在终端通过管道传递给它，如 `cat error.log | claude -p "分析一下这里发生了什么"`。

诸如 `一步步思考（think step by step）` 或 `请务必彻底严谨（be thorough）` 这类字眼，在当前模型看来只是普通的对话文本，并非具有魔法的系统关键词。真正控制 Claude 思考深度与投入力度的核心把手是[思考力度设置（Effort level）](https://code.claude.com/docs/en/model-config#adjust-effort-level)（详见后文[调整基座模型与思考力度](#调整基座模型与思考力度)）。这类措辞最多只能在现有的 Effort 等级框架内对模型产生微调偏向，却无法强行突破当前的算力上限。

不过，有一句措辞目前依然非常管用：`放开手脚（be ambitious）`。由于 Claude 无法预知你心底究竟期望做到何种程度，它在理解需求时往往倾向于保守收敛，只交付满足要求的最小可用版本。当你希望它交付功能完备、边界处理周全且具备自然延伸能力的完整方案时，请直抒胸臆：

```text
根据这套原型设计构建设置页面。放开手脚：不仅要排好布局，还要补齐空状态与异常处理状态、打通保存数据流，并支持键盘快捷导航。
```

这种表达是在向 Claude 传达只有你才知晓的**业务范围（Scope）**，而不是在机械地命令它该如何思考。

而当你处于探索阶段而非修复具体问题时，写出一句模糊的提示词（如 `你觉得这个文件有哪些地方可以改进？`）也是完全合理的。唯一的取舍在于，你在后续推进过程中需要伴随进行更多的人工校准引导。

### 先与 Claude 开展头脑风暴

当你尚未完全想清楚自己究竟想要什么时，完全没有必要在下达指令前自己独自把一切细节全盘推演清楚。不妨直接让 Claude 反客为主对你进行深度访谈：

```text
我想为公开 API 增加接口限流能力，但目前还没有完全想透彻。请以技术访谈的形式不断向我提问，直到你能梳理出一份完整严密的技术规格说明书为止，然后将其写入 SPEC.md 中。
```

随后，Claude 会就那些你尚未敲定的细节抛出一系列针对性的多选题：究竟是基于用户维度还是基于 API Key 维度限流？超出限流阈值后的请求该如何处置？本次改造的非目标范围（Out of scope）有哪些？它会层层递进地追问，直到所有答案拼凑出一份完整严密的架构规范。

一旦 `SPEC.md` 生成完毕，**立刻另起一个全新的会话**并基于该文件开展功能开发。这样既能保证编码任务在纯净无污染的上下文空间中启动，又能拥有明确写定的验收标准（Definition of Done）。在后续流程中，这份文件也将成为代码审查智能体核验产出一致性的核心基准（参见[给模型提供可执行的检查回路](#给模型提供可执行的检查回路)）。

### 保持 CLAUDE.md 精炼克制

Claude Code 会将 [`CLAUDE.md`](https://code.claude.com/docs/en/memory) 自动加载到每一次会话中，这意味着该文件中的每一行文字，都会在**每一项任务**中分摊占用 Claude 宝贵的注意力资源，不论它是否与当前任务相关。正因如此，该文件最理想的定位是：**仅沉淀 Claude 无法直接从代码库中自主提炼的核心要点**：

- **如何在本项目中验证工作成果**：精确的测试、类型检查和代码规范检查命令，以及如何运行单体测试文件；
- **代码中容易产生误导的地方**：代码库中随处可见但新代码坚决不得效仿的陈旧老范式，或者看起来废弃但实际仍在生效的关键目录；
- **代码库中没有体现的技术决策**：团队选定的统一错误处理工具类、部署流转机制、哪些改动必须触发数据库迁移评审；
- **任何你已经被迫手动纠正过两次及以上的事情**。

一份经受住上述标准筛选的 `CLAUDE.md` 通常会非常精炼短小：

CLAUDE.md

```markdown
# 常用命令
- 依赖安装：pnpm install
- 运行单测试文件：pnpm vitest run path/to/file.test.ts
- 类型检查：pnpm tsc --noEmit

# 编码约定
- 统一使用 src/lib/errors.ts 中的错误处理辅助函数，严禁抛出原生纯字符串异常
- src/legacy/ 目录下的旧逻辑仍在生产运行，但新代码切勿照搬其架构范式

# 避坑提示
- 集成测试依赖环境变量 DATABASE_URL，详见 .env.example
```

在交互会话中，可以随时运行 [`/context all`](https://code.claude.com/docs/en/commands#all-commands) 命令，确认 Claude 是否已成功加载该文件。

请注意，上述类型检查一行仅指明了具体命令。Claude 需要知晓该命令，以便在编码过程中随时自主检查其产出。如果你希望 Claude Code 在任务收尾时**刚性强制**必须通过类型检查，这应当交由 [`Stop` 终止钩子](#利用-stop-钩子刚性校验)来兜底。在说明文件中写上一句类似 `完成前务必执行类型检查` 的软性要求，大部分时候能起效，但做不到百分之百万无一失。

你完全不需要从零手写这份文件：

- `/init` 命令能基于对当前代码库的全面解析，自动生成一份初始模板。随后的工作主要是做减法删减行数。[记忆配置指南](https://code.claude.com/docs/en/memory#write-effective-instructions)建议将总行数严格控制在 200 行以内。
- `/doctor` 能智能指出其中哪些内容是 Claude [早已能从代码中直接推导出来的](https://code.claude.com/docs/en/memory#my-claude-md-is-too-large)，并给出删减建议。
- `/doctor prompt-audit` 会自动标注出那些针对老旧模型编写的、指向已删除文件的、或彼此[存在矛盾冲突](https://code.claude.com/docs/en/memory#audit-your-instruction-files)的陈旧失效指令。

你的个人偏好请写入 `CLAUDE.local.md` 而非主文件中，并将该本地文件加入 `.gitignore`，避免误提交至远程仓库。

如果 Claude 反复无视某条写在 `CLAUDE.md` 里的规则，单纯加上“重要（IMPORTANT）”往往无济于事。这要么是因为文件已经臃肿到让该规则被信息洪流淹没，要么是因为这是一条绝不允许有例外的刚性规则——若是后者，它理应移入[钩子体系](#把不可破例的规则变成刚性约束)中进行强制管控。

### 按代码目录切分局部规则

如果某条规则只在代码库的特定模块中生效，请将其放入 [`.claude/rules/`](https://code.claude.com/docs/en/memory#path-specific-rules) 目录下，并通过 `paths:` 过滤器进行作用域限定，使其仅在 Claude 实际修改该区域代码时才动态加载。例如，以下这份 `.claude/rules/api.md` 仅针对 `src/api/` 下的 TypeScript 文件生效：

.claude/rules/api.md

```markdown
---
paths:
  - "src/api/**/*.ts"
---
- 必须使用 src/api/schemas/ 中的 zod schema 校验请求体，切勿手写检查逻辑
- 每一个新接口都必须在 openapi.yaml 中补全定义，否则 CI 流水线将报错拦截
```

### 将团队标准作业规程沉淀为技能（Skills）

更强大的基座模型知晓更多通用的软件工程原理，但它不可能知道**你们团队**究竟如何发版、线上事故应急手册（Runbook）怎么写、或者团队要求的 API 接口文档排版格式。这类团队特有的规程与知识最适合沉淀为[专属技能（Skill）](https://code.claude.com/docs/en/skills)：即保存在 `.claude/skills/<name>/SKILL.md` 的操作步骤或知识库。

相比于全量塞进 `CLAUDE.md`，技能在上下文消耗上要轻巧得多。对于允许 Claude 自主调用的技能，它在每轮会话中只会常驻感知该技能的名称与简要描述，只有当当前任务[真正触发其适用场景时](https://code.claude.com/docs/en/skills#skill-content-lifecycle)，才会按需加载全文。一份长篇大论的发版流程存放在技能中，绝不会像写在 `CLAUDE.md` 里那样无端拖累与发版毫不相干的日常 Bug 修复。

`CLAUDE.md` 的精简原则在技能中同样适用：**只写 Claude 靠自己查不到的核心增量。**

对于具备实际外部副作用的工作流（例如真正执行打 Tag 切分支的发版操作），务必加上 `disable-model-invocation: true` 声明。这样 Claude 就[无法擅自自主触发该技能](https://code.claude.com/docs/en/skills#control-who-invokes-a-skill)，它将严格仅在你亲自在终端敲下 `/release` 命令时才会执行。以 `.claude/skills/release/SKILL.md` 为例：

.claude/skills/release/SKILL.md

```markdown
---
name: release
description: 切新版本发布。负责自增版本号、写入更新日志、打 Git Tag 并推送，以便触发 CI 自动发包。
disable-model-invocation: true
---
1. 确认当前位于干净的 main 分支工作树。如果不是，立刻停下并询问。
2. 运行 `pnpm changeset version` 并提交本次变更。
3. 汇总自上一个 Tag 以来合入的所有 PR，按行写入 CHANGELOG.md 中（仅列出面向用户的实质改动）。
4. 打上 `v<new version>` 标签并推送至远程。后续发包由 CI 接管，严禁在本地开发机直接发布产物。
```

### 为 Claude 接入所需的外部工具

Claude 无法直接感知的另一些核心信息，往往散落在团队的其他系统之中，比如 Issue 缺陷追踪面板或线上错误监控看板。如果这些系统提供命令行工具（CLI），通常是最轻便的接入途径。例如，只要本地安装并登录了 `gh`（GitHub CLI），Claude 就能直接创建 Pull Request 并阅读审查意见，无需你额外多费一句口舌。面对它从未见过的全新 CLI，只需在提示词中引导它查看 `--help` 便已足够。

对于没有 CLI 的系统，可以通过 [MCP（Model Context Protocol）协议](https://code.claude.com/docs/en/mcp)实现标准化连接。在终端运行命令即可直接添加服务：

```shellscript
claude mcp add --transport http notion https://mcp.notion.com/mcp
```

接入后，该服务即可在会话内通过 `/mcp` 命令查看管理。需要注意的是，已连接的 MCP 服务即便在未使用时，其工具名称与描述也会计入上下文占用；因此建议随时在 `/mcp` 面板中[关闭当前阶段用不到的服务](https://code.claude.com/docs/en/mcp#disable-a-server-without-removing-it)。

此外，如果你使用的是强类型语言，安装[代码智能插件（Code Intelligence Plugin）](https://code.claude.com/docs/en/plugins/code-intelligence)能让 Claude 瞬间精准跳转至符号定义处，免去逐个翻查大量相关文件的开销。

## 给模型提供可执行的检查回路

Claude 往往在它“感觉搞定”的时候停下工作。如果它手头没有任何可以运行的检查手段来验证工作是否**真正做完**，那么“感觉做好了”就是它唯一的判断依据。在实际工程中，这意味着你沦为了它的人肉测试套件，任何疏漏都会一直静默潜伏，直到你偶然发现。

如果你能为它提供一个非黑即白（Pass or Fail）的自动化校验工具，Claude 就能在内部完全闭环这个自愈回路。它修改代码、执行检查；如果测试挂了，它会主动分析输出日志、修复缺陷，然后再次重跑校验，周而复始。

**给 Claude 提供一个它能自行运行并返回明确通过/失败结论的检查手段。一旦拥有这项能力，它就能完全独立自主地推进工作，你无需在旁全程盯盘。**

这项检查的形式几乎不受限制，只要结果能被 Claude 读取即可：

- 一个单元测试或集成测试文件；
- 编译构建命令的退出状态码；
- 一次代码规范检查（Linter）；
- 一个将当前实际输出与预置基准数据（Fixture）做 Diff 的脚本；
- 一张与设计稿原型比对的[真实浏览器运行截图](https://code.claude.com/docs/en/chrome)。

如果你的代码库中已经拥有上述工具，那么你在 `CLAUDE.md` 中**最关键、最值钱的一行文字**，就是声明如何运行该校验的精准命令。

至于将这项检查把关到何等严苛的程度，完全取决于你的需求。从交由 Claude 自主裁量到由 Claude Code 底层刚性锁死，有一整套梯次方案可供选择：

- **提示词软性约定**：在提示词中追加 `修改后运行认证模块测试，持续修复直至全部通过`。由 Claude 自行决定何时达标。这无需任何前期配置，适用于当下的任何单次任务。
- **设定会话目标（Goal）**：通过 [`/goal tests/auth 下所有测试通过且 lint 检查全绿`](https://code.claude.com/docs/en/goal) 设定硬性验收条件。系统会在每轮交互后由独立模型对当前会话进行裁决，未达标前 Claude 将被迫持续推进。日常交互中很少用到它，但在长时间无人值守运行场景下价值连城——能有效防止 Claude 在任务尚未彻底扫尾时，草草留下一段进度总结便提前交卷。
- **配置 Stop 终止钩子**：配置 [`Stop` 钩子](https://code.claude.com/docs/en/hooks#stop)，在 Claude 试图结束当前轮次交差的瞬间自动触发你的验证脚本；若脚本返回退出码 2，系统会强行将 Claude 踢回工位继续修 Bug。该机制由宿主运行环境（Claude Code）在底层刚性锁死，除非类型检查全绿或达到[最大阻断上限](https://code.claude.com/docs/en/hooks#stop-input)，否则绝不允许结束轮次。后文给出了[完整配置示例](#利用-stop-钩子刚性校验)。
- **引入第三方独立审查**：在终端运行 [`/code-review`](https://code.claude.com/docs/en/code-review-local)，启动一个全新、从未见过你此前对话历史的独立子智能体，对当前代码 Diff 进行客观审查。它不会受到此前引导模型编写这批代码时的逻辑先入之见的干扰。

无论采用哪种方式，都请明确要求 Claude 给出**客观证据**：包括它实际执行的具体命令、终端回显输出或运行截图。单纯一句“所有测试均已通过”没有任何信息含量，通读真实的命令输出远比你自己亲手重跑一遍要快得多。对于那些你未曾实时监视的后台会话，这也是你手中唯一可信赖的凭证。

当 Claude 汇报工作完成之后，你还可以在会话内调用 [`/verify`](https://code.claude.com/docs/en/skills#run-and-verify-your-app) 命令，让 Claude 自行启动编译、运行应用并检视实际效果。这能捕获那些单元测试和类型检查容易忽略的整体运行期缺陷。

### 对照需求规格说明（Spec）进行审查

如果你更希望让审查者严格对照最初的设计蓝图把关，而非漫无目的地漫游找 Bug，可以自行编写定制化的审查提示词：

```text
启动一个子智能体，对照 SPEC.md 严格审查本次限流模块的代码 Diff。逐一核对每项需求是否均已落实，检查所有列明的边界异常是否均已编写测试用例。仅报告影响正确性的实质缺陷，略过所有纯代码风格类建议。
```

请千万不要删掉提示词中 `略过所有纯代码风格类建议（skip style）` 这半句话。一个被命令去“挑毛病”的审查模型永远能挑出点什么。如果你对它的每一条边角意见都盲从整改，最终代码里只会凭空堆积出无数层画蛇添足的抽象接口，以及一堆针对不可能发生的场景所编写的冗余测试。

### 利用 Stop 钩子刚性校验

要想利用 `Stop` 钩子将“类型检查必须通过”做成刚性约束，只需在 `.claude/settings.json` 中配置寥寥数行。**退出码 2** 是阻断其交卷的关键信号。该命令输出至 `stderr` 的所有编译报错都会原封不动地作为“当前仍未通过的理由”重新喂给 Claude，因此需要将编译器输出重定向至标准错误：

.claude/settings.json

```json
{
  "hooks": {
    "Stop": [
      {
        "hooks": [
          { "type": "command", "command": "pnpm tsc --noEmit 1>&2 || exit 2" }
        ]
      }
    ]
  }
}
```

为了直观验证该机制的效果，你可以故意让 Claude 做一个破坏类型定义的改动：它将无法顺利交卷，而是会立刻拿到编译器报错回显，并不断自我纠错，直到 `tsc` 彻底绿灯为止。如果该钩子在没有任何工具调用的情况下[连续阻断交卷达到 8 次](https://code.claude.com/docs/en/hooks#stop-input)，Claude Code 底层会判定死锁并强制结束本轮交卷。如需调整此上限，可配置环境变量 [`CLAUDE_CODE_STOP_HOOK_BLOCK_CAP`](https://code.claude.com/docs/en/env-vars)。

## 把不可破例的规则变成刚性约束

**如果某件事在任何情况下都必须发生，请将其配置为钩子（Hook）、拒绝规则（Deny rule）或集中受控配置（Managed setting）。`CLAUDE.md` 仅适用于指引性约定，Claude 有权根据场景判断某条指引并不适用。**

以大家今天在 `CLAUDE.md` 里经常写的三条规则为例：`绝不能读取 .env`、`编辑后必须跑格式化工具`、`切勿修改 migrations 目录`。在绝大多数时候，Claude 确实都会遵守这些要求。但在极少数容不得丁点闪失的严肃场景下，“绝大多数时候遵守”是远远不够的。你应当将它们从 `CLAUDE.md` 中剥离出来，写入由 Claude Code（宿主运行框架）亲自负责解释执行的配置文件中。从那一刻起，执行结果将不再依赖基座模型的记忆或临时起意。

### 通过钩子（Hooks）刚性固化操作步骤

[钩子（Hooks）](https://code.claude.com/docs/en/hooks-guide)能够在 Claude 交互生命周期的特定关键点自动执行你指定的逻辑：在工具调用前或调用后、在 Claude 试图交卷终止时、在会话建立伊始等等。钩子所执行的动作可以是：

- 一条 Shell 脚本命令（最常见的使用姿势）；
- 向指定的 HTTP 接口发起一次 POST 请求；
- 调用你本地某台 MCP 服务器暴露的专属工具；
- 配置为 [`prompt` 或 `agent` 类型的钩子](https://code.claude.com/docs/en/hooks#hook-handler-fields)，引入另一个模型进行智能裁判。

请注意：`prompt` 或 `agent` 类型的钩子由于本质上是交由*另一个模型*做判断，因此它依然属于非确定性范畴。若要实现不可动摇的刚性阻断，务必选用 `command` 或 `http` 钩子，并在希望钩子自身发生超时或崩溃时连带阻断后续动作的场景下，追加 [`onFailure: "block"`](https://code.claude.com/docs/en/hooks#block-the-action-when-a-hook-fails) 声明。举个例子：对于一个专门扫描代码提交中是否混入敏感密钥的钩子，你宁可在扫描器宕机时直接阻断 Commit，也绝不容忍在缺乏安检的情况下把代码放行。

下面是将“保存后自动格式化”实现为 `PostToolUse` 钩子的标准范例。它会在每一次 `Edit` 或 `Write` 文件操作完成后自动静默执行；此时 Claude 是否还记得这条规矩早已无关紧要，因为执行格式化的根本不是它：

.claude/settings.json

```json
{
  "hooks": {
    "PostToolUse": [
      {
        "matcher": "Edit|Write",
        "hooks": [
          { "type": "command", "command": "npx prettier --write --ignore-unknown \"$(jq -r '.tool_input.file_path')\"" }
        ]
      }
    ]
  }
}
```

你可以故意让 Claude 往一个受 Prettier 托管的文件里插入一段缩进错乱的代码来测试这个钩子。保存出来的文件会自动修复所有缩进排版。

同理，“禁止触碰迁移文件”的规则可以写成一个 [`PreToolUse` 钩子](https://code.claude.com/docs/en/hooks-guide#block-edits-to-protected-files)：只要检测到操作路径位于 `migrations/` 下，就直接返回退出码 2 予以阻断。你完全不需要手写这段 JSON：直接向 Claude 输入提示词 `写一个阻断修改 migrations 目录的钩子`，随后输入 `/hooks` 就能直接查看生效的配置。但切勿过度滥用：钩子只适用于**零容忍、毫无例外**的铁律；像 `推荐使用具名导出（Prefer named exports）` 这种处处存在特例的编程偏好，老老实实留在 `CLAUDE.md` 中即可。

### 借助权限规则与沙箱限定操作边界

[权限规则（Permission rules）](https://code.claude.com/docs/en/permissions)负责判定 Claude 拥有哪些命令执行、文件读取与网络请求的合法权限。**`deny` 拒绝规则在任何权限模式下均享有最高强制力**，即便是自动模式（Auto mode）乃至 `bypassPermissions` 模式都无法绕过它，这正是为什么保护 `.env` 必须落在此处：

.claude/settings.json

```json
{
  "permissions": {
    "allow": ["Bash(pnpm tsc --noEmit)"],
    "ask": ["Bash(git push *)"],
    "deny": ["Read(./.env)", "Read(./.env.local)", "Read(./secrets/**)"]
  }
}
```

配置落地后，无论你命令 Claude 查看 `.env` 里的内容，还是它试图在后台通过 `cat .env` 命令偷看，都将遭到系统的无情拦截。

权限规则匹配的是底层的**工具调用指令**，而非抽象的心理意图，因此有必要明确其边界所在：

- `Read` 规则**确实能够**捕获 `cat .env`，因为 Claude Code 能够深度识别[常见的系统级文件读取命令](https://code.claude.com/docs/en/permissions#read-and-edit)；
- 但如果 Claude 执行了一个自行编写并执行的复杂外部脚本去读取该文件，该规则将无法从命令行表面直接拦截；
- 针对某个域名的 `WebFetch` 拒绝规则，无法防范 Claude 在未开启沙箱的情况下直接在终端调用 `curl` 访问该域名。

如果需要实现操作系统级别的文件系统或网络访问边界约束，请在会话中输入 `/sandbox` 开启[沙箱机制（Sandbox）](https://code.claude.com/docs/en/sandboxing)。它在 macOS、Linux 和 WSL2 环境下能对 Claude 的 Shell 命令实施严格的系统级容器化隔离，并且会自动[继承并联动你的 `Read` 拒绝规则以及 `WebFetch(domain:...)` 网络规则](https://code.claude.com/docs/en/sandboxing#permission-rules)；对于涉及高危安全诉求的场景，两者配合使用方为万全之策。

默认情况下，当某个命令在沙箱内被阻断后，Claude 仍有权弹窗向你申请在沙箱外部重试，且该申请仍会走常规权限弹窗流转。而在 `/sandbox` 的 **Overrides** 设置面板中开启[严格沙箱模式（Strict sandbox mode）](https://code.claude.com/docs/en/sandboxing#turn-off-the-retry-with-strict-sandbox-mode)，则会彻底斩断这种沙箱外重试的口子。

自动模式（Auto mode）的核心是一个针对每项动作做风险判定的分类模型，而非死板的规则匹配。它在此方面极具智慧，但既然涉及主观裁决，就必然存在误判的概率。你可以按需调优其对风险的敏感度阈值，你的企业组织也可以统一强制关闭它；因此，你团队中那些绝对不容商量的刚性红线，必须落入 Deny 拒绝规则或 Hooks 钩子中。

### 明确规则的生效作用域

一条规则保存在哪里，直接决定了它会影响到哪些人：

- `.claude/settings.local.json` 与 `~/.claude/settings.json` 纯属你的**个人专属配置**。当你在授权弹窗中勾选了 **“是，且不再询问”（Yes, and don't ask again）** 时，Claude Code 会将该条允许规则持久化在本地私有配置中。
- `.claude/settings.json` 及其中的钩子**归属于整个代码仓库**。一旦提交入库，将无差别适用于在该代码库中工作的每一位团队成员。其中的 `deny` 拒绝规则会立即全员生效；而其中的 `allow` 授权规则和自定义钩子，则需要每位同事在本地首次弹出的[目录信任对话框](https://code.claude.com/docs/en/permissions#what-runs-before-you-trust-a-folder)中确认接受后，方可在其电脑上正式激活[工作区信任机制](https://code.claude.com/docs/en/hooks#workspace-trust)。
- [企业托管配置（Managed settings）](https://code.claude.com/docs/en/managed-settings)**归属于整个组织管理层**。它们由企业管理员后台统一推送、MDM 系统统一下发、或通过只读的 `managed-settings.json` 固化。任何本地个人配置文件均无权覆写托管设置，这使其成为安全与合规团队推行硬性管制的唯一法定阵地。如果你是负责统一策略的管理员，请参阅[为你的组织配置 Claude Code](https://code.claude.com/docs/en/admin-setup)。

不论面向何种作用域，都请务必克制刚性规则的数量。每一个 Hook 和 Deny 规则在特定极端场景下都有可能发生意外误伤，且每一条都需要专门的人力去持续维护。如果你发现自己的配置库里堆了三四十条刚性规则，其中绝大多数大概率只是完全可以让 Claude 自主权衡的普通编程偏好而已。

## 按需调整默认设置

平台的默认配置足够优秀，在某项任务消耗超出预期的时间、Token 算力或引发过多打扰之前，完全可以放心地保持现状。一旦觉得有异常，在会话中输入 `/usage` 即可精准洞察开销流向。

一个崭新的会话从建立之初，就已经默默替你做好了若干关键决策：

- 终端交互与 VS Code 插件会话默认以自动模式（Auto mode）启动；
- 在大多数订阅方案与服务商体系下，默认运行[处于 medium 思考力度的 Claude Opus 5.5](https://code.claude.com/docs/en/model-config#default-model-setting)；
- 当识别到合理动机时，自动将部分子任务下派给子智能体（Subagents）；
- 伴随对话历史拉长，自动启动上下文压缩（Compaction）。

大多数时候你甚至意识不到它们的存在。而当某项任务耗费了超出常理的成本时，问题几乎总是出在上述四项设置中的某一环。

### 切换权限模式

权限控制的两极都伴随着不可忽视的隐形成本：

- **手动模式（Manual mode）**：每一个编辑动作和每一条非只读命令，都必须由你亲自逐击确认。虽然绝对安全，但在经历了十几次弹窗轰炸后，人类很容易产生审美疲劳，开始不加审视盲目点击放行；而且只要你离开键盘，整个进度便彻底陷入停滞。
- **`bypassPermissions` 模式**：除了已明文配置的 deny 和 ask 规则外，全量自动放行所有操作。这种模式只应该在一次性销毁的容器环境中运行。

[自动模式（Auto mode）](https://code.claude.com/docs/en/permission-modes#eliminate-prompts-with-auto-mode)恰到好处地居于两者之间，也是终端交互和 VS Code 插件[默认采用的起手模式](https://code.claude.com/docs/en/permission-modes#which-mode-a-session-starts-in)。Claude 可以在不因琐碎例行操作打扰你的前提下自主推进，而独立的风险分类模型会依照[固定的安全审查流水线](https://code.claude.com/docs/en/permission-modes#how-the-classifier-evaluates-actions)在动作落地前进行实时核验。它集中拦截[那些你绝对希望有人类踩刹车的高危动作](https://code.claude.com/docs/en/permission-modes#what-the-classifier-blocks-by-default)：

- 危险的 `curl | bash` 远程管道执行；
- 生产环境的部署发布与数据库迁移；
- 会强行覆盖他人工作的 Git 强推（Force push）；
- 向未知的外部第三方域名发送敏感私有数据；
- 看起来像是受到 Claude 刚才读取的不可信内容所诱导的异常行为（防提示词注入攻击）。

当自动模式拦截某项操作时，你会收到系统通知，且该动作会登记在 `/permissions` 面板的 **Recently blocked（近期拦截项）** 中，你可以[在此一键核准放行以便 Claude 继续重试](https://code.claude.com/docs/en/auto-mode-config#review-denials)。如果出现[连续 3 次被拦截](https://code.claude.com/docs/en/permission-modes#when-auto-mode-falls-back)（或累计达到 20 次拦截），自动模式会自动挂起降级，重新交由人类逐条确认。

这一切并不会取代你的确定性控制底线，因为分类器是在这些规则**之后**才发挥作用的。Deny 规则、Ask 规则以及 `PreToolUse` 钩子会在分类模型看到之前就先行生效；因此，一条 Deny 规则在自动模式下同样能够实现绝对刚性阻断。沙箱机制也依然会在底层牢牢锁死[其所包裹的 Shell 命令](https://code.claude.com/docs/en/sandboxing#what-runs-outside-the-sandbox)。

你还可以在对话中随口说一句 `在我亲自审查之前不要 push 代码`，风险分类器会[敏锐地将这句话捕获为阻断信号](https://code.claude.com/docs/en/permission-modes#boundaries-you-state-in-conversation)。但请记住这本质上依然是模型在阅读会话上下文，当对话触发历史压缩后这句话有可能被遗忘；因此任何严肃的安全边界，都必须落在 Deny 规则中。

反过来的常见困扰，则是分类模型反复阻断某项在你们团队日常工作流中原本很常见的例行操作。与其每次手动点通过，不如将其加入 `autoMode.allow`，或者在[自动模式全局配置](https://code.claude.com/docs/en/auto-mode-config)中声明你的受信任基础设施架构。这里的配置采用自然语言描述而非晦涩的正则匹配，你甚至可以直接在会话中输入 [`/auto-mode-setup`](https://code.claude.com/docs/en/auto-mode-config#generate-environment-entries)，让系统基于你的项目结构与近期会话自动草拟 `environment` 配置段：

~/.claude/settings.json

```json
{
  "autoMode": {
    "environment": [
      "$defaults",
      "版本控制系统：github.com/example-org 及其名下的所有代码仓库",
      "受信任的内部域名：*.internal.example.com"
    ],
    "allow": [
      "$defaults",
      "允许部署到预发环境命名空间（staging namespace），该环境与生产环境完全隔离且每夜自动重置"
    ]
  }
}
```

请确保在你配置的每个数组列表开头都保留 `"$defaults"` 项。缺少这一项会导致你的自定义条目**直接覆盖替换**内置规则库，而非追加增补。如果在 `environment` 和 `allow` 中丢掉了它，你会失去平台自带的安全基线上下文与豁免逻辑；而在 `soft_deny` 中丢掉它，系统原本针对强推 Git 和生产环境部署的内置安全围栏就会彻底失效。

此外，`autoMode` 配置块必须统一保存在用户全局配置 `~/.claude/settings.json` 中，保存在项目级配置中会被分类器直接忽略。

如果你无论如何都希望在每次变更和命令敲击前亲自过目，可以在会话中按下 `Shift+Tab` 快捷键，自由在包括手动模式（Manual）在内的各权限档位之间循环切换；或者在终端启动时直接指定 `claude --permission-mode manual`。如果觉得手动模式弹窗过于频繁，输入 `/fewer-permission-prompts` 会自动回溯扫描你近期的操作日志，将常见的只读 Bash 和只读 MCP 调用提炼并追加至 `.claude/settings.json` 的白名单中。

### 调整基座模型与思考力度

[思考力度（Effort）](https://code.claude.com/docs/en/model-config#adjust-effort-level)是掌控 Claude 思考耗时与推演深度的核心开关，它完全取代了过去人们在提示词里各种咬文嚼字的技巧。在 Claude Fable 5.2、Opus 5.5、Sonnet 5.5 和 Haiku 5.5 上，默认力度均为 `medium`，这对于需求边界明确的日常功能开发而言绰绰有余。在会话中通过 `/effort` 调整力度的典型时机如下：

- **调高为 `/effort high` 或 `/effort xhigh`**：当任务的正确性高度依赖于那些极易被疏漏的隐蔽分支场景时。比如排查非本人编写的陈旧代码中的诡异 Bug、调试偶发性测试用例（Flaky test）、或实施某项数据库 Schema 改造且必须彻底找全所有旧数据结构的读取方。此时 Claude 会主动推演更多边界情况并在作答前展开多轮自检，这也是额外耗时与 Token 消耗的主要去向。
- **调低为 `/effort low`**：当你正在与 Claude 高频快速往复讨论、且每一步产出你都会亲自把关审阅时：比如头脑风暴构思、第一版架构草图勾勒、跨几个文件的简单变量重命名。Claude 会以极快的速度向你反馈起步方案；既然你全程在手把手导航，多余的深思熟虑除了增加等待时间外毫无实质益处。
- **保留 `max` 挡位给终极难题**：比如在无人值守的情况下让 Claude 独自彻夜攻关排查复杂的安全漏洞。在日常普通任务中开启它往往会导致模型过度推演（Overthink），你耗费了大量成本，拿到的答案却未必比 `high` 档位好到哪里去。
- **单次专项深度推演**：如果只是在一长串日常开发流中偶然穿插了一个非常棘手的小问题，只需在当次提示词中加入 [`ultrathink`](https://code.claude.com/docs/en/model-config#use-ultrathink-for-one-off-deep-reasoning) 标识即可，无需专门修改全局 effort 配置。

在基座模型选型方面，默认的 Opus 5.5 在绝大多数编码场景下表现极其稳健，而 Sonnet 在日常常规编码任务中成本显著更低。如需调用 [Claude Fable 5.2](https://code.claude.com/docs/en/model-config#work-with-fable)，可在会话内运行 `/model fable`。Haiku 则非常适合指派给那些承担简单工作的子智能体。[模型配置指南](https://code.claude.com/docs/en/model-config)详细列出了各个计划和供应商支持的完整模型清单。

### 算清子智能体（Subagents）的成本账

Claude 会在后台自主判定时机，将任务分发给[子智能体（Subagents）](https://code.claude.com/docs/en/sub-agents)：

- 全局大范围的代码库检索会自动委派给内置的 Explore 探查智能体；
- 在 Fork 模式开启（默认行为）时，支线延伸任务会[分叉独立运行](https://code.claude.com/docs/en/sub-agents#fork-the-current-conversation)；
- 其派生出的子智能体默认全部在后台异步运行，主会话丝毫不受阻塞，可以继续顺畅交流。

你几乎从不需要主动开口要求它这么做，但理解其运作逻辑与背后代价大有裨益。

子智能体在以下场景下能带来巨大收益：

- 同时并行并发推进若干项彼此独立的繁重子任务，大幅缩短整个任务的总交付耗时；
- 隔离海量的冗长日志回显（如全量跑一遍庞大的测试套件或执行广谱代码搜索），避免这些噪音冲刷污染主对话上下文，否则它们会在后续整个会话中长期占用 Token；
- 获取一个完全不知道这批代码当初是如何写出来的、客观中立的独立审查视角；
- 为特定子任务配置比主会话更收敛狭窄的工具集权限，比如配置一个只读却无权修改任何代码的只读审查员。

它们所带来的核心成本是 **Token 消耗**：因为每一个子智能体都拥有自己独立的对话请求，且统统计入你的主账户用量中。有时候它还会带来额外的时间开销：一个全新启动的子智能体首先必须自行搜集上下文，而这些背景信息主对话可能早就具备了，这反而会导致它比直接在当前会话内执行**更慢**。

此外，默认情况下子智能体运行的是与主会话相同的模型（或更小的模型）来处理同一项任务。它带给你的是**并行度与新视角的红利**，而不是更聪明的答案。

要想有效控制子智能体的开销，可以采取以下措施：

- 如果子智能体的工作非常机械简单（比如检索引用了某个模块的所有关联文件、或核对文档里的超链接死链），在其配置中显式声明 [`model: haiku`](https://code.claude.com/docs/en/sub-agents#choose-a-model)。此类任务无需杀鸡用牛刀，而 Haiku 的单次请求成本要低廉得多；
- 明确要求子智能体仅回传精简后的结论摘要，避免其将检索出的几十条原始结果一股脑倒灌回主上下文；
- 定期输入 `/usage` 查看各类子智能体占用的 Token 份额，以便评估每一类子智能体的产出是否值回票价；
- 在 `.claude/agents/` 中定义定制子智能体时，将其权限严格限定为 `tools: Read, Grep, Glob`。这样它就变成了一个绝对无法改动任何源码的纯只读审查员，且该限制由底层框架刚性锁死，比在提示词里软性苦口婆心地叮嘱管用得多。

这样一个纯粹的只读审查员只需一个极其简短的配置文件 `.claude/agents/reviewer.md` 即可搞定：

.claude/agents/reviewer.md

```markdown
---
name: reviewer
description: 对照最初制定的需求规格说明（Spec），审查已修改的代码文件。适合在功能开发完毕后、发起 PR 之前调用。
tools: Read, Grep, Glob
---
你现在作为一名未曾参与编码的第三方独立审查者审阅代码。对照给定的需求规格说明书，
逐一核对各项业务需求是否均已落地、列明的所有边界异常是否均有对应测试覆盖。
仅汇报影响业务正确性的实质性漏洞，略过所有纯代码风格类琐碎意见。
```

只需在会话中对 Claude 说一句 `让 reviewer 对照 SPEC.md 审查限流模块的代码`，所有排查出的漏洞缺陷就会结构化地回传至你的主会话中，交由主 Claude 动手修复。

### 压制上下文与使用开销

得益于当前大多数模型标配的 100 万（1M）Token 上下文窗口以及在接近上限时自动触发的上下文压缩机制，你几乎永远不用担心上下文耗尽爆炸的问题。但尽管容量宽裕，你依然可能在为你根本不需要的多余上下文**白白买单**。每一次请求都会将整场对话历史完整发送，一个杂糅了三项互不相干任务的长会话，在推进第四项任务的每一步时都会被迫把前三项历史重新读上一遍。在[缓存命中期内这部分享有巨额折扣](https://code.claude.com/docs/en/costs#why-usage-climbs-in-a-long-session)，但一旦缓存失效，就必须全额付费。

[`/usage`](https://code.claude.com/docs/en/costs) 命令是诊断开销的第一站。在 Pro、Max、Ultra、Team 和 Enterprise 等方案下，它会按技能、子智能体、插件和 MCP 服务器多维度清晰拆解你的资源流向。一旦发现长上下文累积或频繁发生缓存穿透（Cache miss）且单项超过整体用量的 10%，系统还会主动发出告警。从这里开始，常用的优化动作非常清晰：

- **在不相关的任务之间输入 `/clear` 开启全新对话**：这不会消耗任何成本，却能彻底切断下一项任务为上一项任务的冗长历史买单的恶性循环。输入 `/clear oauth-migration` 可以在清空的同时为即将离开的会话命名归档，方便你日后随时找回。
- **带明确聚焦目标地执行 `/compact`**：例如 `/compact 保留 API 变更记录与相关测试命令`。在超长会话中，由于 `/compact` 本身需要通读整场对话并生成摘要，它自身就是一次庞大的计算请求，在缓存过期后尤甚。
- **警惕隐形后台计算**：比如 `/loop` 周期性任务、每轮交互后自动触发的 Goal 验收裁决、以及 Claude 自行派生出的后台子智能体，在你未敲击键盘时都在持续产生请求。

[提示词缓存（Prompt cache）](https://code.claude.com/docs/en/prompt-caching)在常规订阅账号下大约维持 1 小时，在直接使用 API Key、云端托管商或按量积分体系下大约维持 5 分钟。子智能体的缓存默认也是 5 分钟，除非特别调优。

对于 1 小时缓存体系，当一个超过 20 万 Token 的长会话长期处于闲置状态时，系统会在缓存即将彻底过期前自动执行一次上下文压缩，确保你吃完午饭回来后能够基于一份紧凑的精简摘要继续推进。当然，如果你后续完全不需要先前的对话历史，直接另起一个全新会话的成本永远是最低的。

## 掌控会话航向

**盯紧前一分钟，在 Claude 出现航向偏离的瞬间果断敲下 `Esc`；在连续两次纠错无果后，坚决执行 `/clear` 并重新组织一份更清晰的提示词，切忌硬撑进行第三次拉扯。**

再完美的系统配置，也取代不了你在头一分钟里的敏锐观察，以及在 Claude 走向偏门时及时踩下刹车的决断。用来控制会话航向的按键与命令屈指可数，值得每一位工程师烂熟于胸：

- **`Esc` 键**：能够在 Claude 执行动作的半途瞬间叫停，同时完好保留截至当前已产生的所有产出，方便你立即调整方向而不丢失已有成果。
- **`/rewind` 命令（或在空白输入框连敲两下 `Esc`）**：唤起[版本回退菜单（Rewind menu）](https://code.claude.com/docs/en/checkpointing#rewind-and-summarize)，支持将代码改动、对话历史或两者同时回滚撤销至之前的某个特定提示词节点。这大幅降低了探索未知架构的心理包袱——你可以放心大胆地先尝试更大胆激进的解法，如果走不通，随时一键回退即可。在该菜单中，还可以对会话中已经陈旧失效的局部历史进行定向摘要提炼。
- **`/clear` 重开**：当你对同一个问题已经连续纠偏两次而 Claude 依然无法领会其意图时，继续展开第三次纠错往往毫无裨益——这只会让对话历史中徒增两段失败尝试的无效代码供 Claude 不断重新阅读并自我干扰。立刻输入 `/clear`，结合前两次试错所吸取的认知教训，重新写一份语义更加精准的全新提示词，其成功率和效率几乎每一次都远超硬聊。

需要明确的是，会话检查点（Checkpoints）仅覆盖 Claude 在主会话中通过自身文件工具修改过的文件，那些[完全通过 Bash 命令在底层脚本修改的文件将无法被还原](https://code.claude.com/docs/en/checkpointing#bash-command-changes-not-tracked)。检查点机制是 Git 版本控制的强力助手，而非其替代品。

此外还有两个实用锦囊：输入 [`/btw`](https://code.claude.com/docs/en/interactive-mode#side-questions-with-%2Fbtw) 可以插入一条轻量的即时支线提问，且该问答完全不会沉淀进主会话历史中。对于需要跨越数天的大型工程任务，在会话中运行 `/rename oauth-migration` 可以为其命名，之后在终端运行 [`claude --resume oauth-migration`](https://code.claude.com/docs/en/sessions#resume-by-session-id-or-name) 即可无缝恢复现场（包括检查点数据）；而运行 `claude --continue` 则能秒级接续最近一次的会话。

## 让 Claude 无人值守自主运行

**在启动无人值守运行之前，请务必确保：它清楚了解怎样才算做完（Done）、具备自主校验产出的手段、且权限边界已被严格限定。为会话设定轮数上限或预算上限，并在最终交付环节保留人工审批把关。**

一旦你不在电脑前实时监护，本指南中所述的所有原则的重要性都会成倍放大。当你在旁看着时，Claude 漏掉某处上下文并不是什么大问题：一两条消息内你就能立刻察觉并纠偏。而在你临睡前启动的夜间自主任务中，没有任何人会当场提醒它，第二天早晨醒来你很可能会痛心地发现它在错误的假设上通宵忙碌了一整夜。

在放手让某项任务独自无人值守运行之前，请对照以下五个灵魂拷问逐一核对该任务：

1. **它清楚什么是完成状态吗？** 是否拥有明确的 Goal 目标判定条件、一份 Spec 规格说明书，或者一个必须由红转绿的失败测试用例？
2. **它能够自检工作成果吗？** 本地测试套件、`Stop` 终止钩子、或者某种形式的自动化审查流程是否已挂载就绪？
3. **它被允许触碰哪些边界？** 权限规则、`dontAsk` 模式、沙箱隔离、独立工作树（Worktree）、乃至它唯一允许推送的目标分支是否均已限制到位？
4. **有什么能让它停下来？** `--max-turns` 最大轮数上限、`--max-budget-usd` 成本上限、账户支出限额是否已筑牢底线？
5. **产出交付到哪里，由谁签字验收？** 无论是提交为一个 PR、一条评论还是一份总结报告，最终的合并代码、生产部署或任何覆水难收的操作，是否都有真人负责最终把关？

一旦各环节校验就绪，Claude 完全能够独当一面推进大型复杂任务。而属于你的不可替代的职责，是在起点启动它、精准界定本次任务的“验收标准”，并在终点对最终合入进行审批把关。

### 通过脚本化命令调用 Claude

运行 [`claude -p "你的提示词"`](https://code.claude.com/docs/en/headless) 能够实现单次执行完毕即刻退出的无头模式（Headless mode），这也是将 Claude Code 无缝集成进 CI 流水线任务、Git 自动化 Hooks 以及 Shell 批量循环脚本的核心途径。

在编写自动化脚本时，你几乎总会需要搭配以下关键参数：

- [`--bare`](https://code.claude.com/docs/en/headless#start-faster-with-bare-mode)：跳过所有 Hooks 钩子、Skills 技能、Plugins 插件、MCP 服务以及各级 `CLAUDE.md` 说明文件（不论是项目级的还是全局的），确保无论脚本在哪台机器上运行，环境表现绝对幂等一致。该模式下绝不会读取你的 claude.ai 网页端登录凭据：认证必须显式来自环境变量 `ANTHROPIC_API_KEY`、通过 `--settings` 传入的 `apiKeyHelper` 配置、或底层云厂商凭证。
- `--append-system-prompt`、`--mcp-config` 与 `--settings`：用于在无头模式下，显式精准传入本次运行**确实需要**的依赖项。请注意，通过 `--settings` 传入的钩子[在 `--bare` 模式下不会执行](https://code.claude.com/docs/en/headless#start-faster-with-bare-mode)，因此如果任务依赖钩子，请勿开启 `--bare`。
- `--allowedTools`：预先核准本次运行允许调用的工具清单；配合 [`--permission-mode dontAsk`](https://code.claude.com/docs/en/permission-modes#allow-only-pre-approved-tools-with-dontask-mode)，彻底拒绝任何本应引发弹窗询问的其他工具调用。
- `--output-format json`：直接将最终输出包裹为一个结构化的单体 JSON 对象供上层脚本解析；配合 `--verbose` 使用 `stream-json` 则能实时以流式捕获整个执行事件流。

组合起来的脚本范例如下：

```shellscript
for file in $(cat files.txt); do
  claude --bare -p "将 $file 迁移至全新的日志库 API 并执行 commit 提交。成功回复 OK，失败回复 FAIL。" \
    --allowedTools "Read,Edit,Bash(git add *),Bash(git commit *)" \
    --permission-mode dontAsk \
    --max-turns 20
done
```

当单次运行正常结束时，Claude 会返回 `OK` 或 `FAIL`；而一旦触发轮数上限，程序则会直接返回非零错误码退出。建议先拿 3 个文件进行小规模试点试跑，排查潜在卡点，优化提示词后，再全量投入生产运行。

自动模式同样适用于 `-p`，只需追加 `--permission-mode auto` 参数即可。在非交互式批处理中，若遭遇分类器拦截，系统会自动拒绝该单项动作并允许 Claude 尝试绕道前行，且多次拦截不会像在终端里那样粗暴挂起脚本。在正式采用前，请先通读[批处理场景下的阈值判定规则](https://code.claude.com/docs/en/permission-modes#repeated-block-thresholds)。

### 基于定时调度或事件驱动触发

一旦启动，Claude 能够独立处理后续所有事情。唯一超出其能力范围的，是自主决定“何时启动”——因此必须有外部扳机来扣动它：要么是你本人、要么是一个定时器、要么是 CI 跑崩或收到新 PR 等外部事件。

在已打开的交互会话内，可以使用 [`/loop`](https://code.claude.com/docs/en/scheduled-tasks#run-a-prompt-repeatedly-with-%2Floop) 命令，按固定时间间隔循环执行某项任务：

```text
/loop 15m 检查当前分支的 CI 状态；如果变红，抓取失败任务的日志，修复代码并重新 push 推送
```

请注意，该命令的每次循环都会累加为主会话中的新轮次，因此切勿在超长对话中长期挂机运行。如果希望在合上笔记本电脑后任务依然持续运转，可以使用 [`/schedule`](https://code.claude.com/docs/en/routines#create-from-the-cli) 编排[云端定时任务（Cloud Scheduled Tasks / Routines）](https://code.claude.com/docs/en/routines)。该功能依赖 claude.ai 账号登录而非普通 API Key。你可以通过直接对话让 Claude 帮忙配置 GitHub 事件触发器，也可以直接访问 [claude.ai/code/routines](https://claude.ai/code/routines) 绑定 Webhook API 触发。

在正式放行云端定时任务之前，请务必利用 [GitHub 分支保护规则锁死 `main` 主分支，防止该自动化任务意外绕过保护](https://code.claude.com/docs/en/routines#repositories-and-branch-permissions)。同时，任何全新的自动化例行任务在彻底放手之前，务必人工观察其最初几轮的实际运行表现。

### 并行运行多个独立会话

当你需要同时并发推进几项互不相干的任务时，请为每个任务分配独立的代码工作树检出（Checkout），杜绝代码编辑产生冲突。使用 [`claude -w feature-auth`](https://code.claude.com/docs/en/worktrees#start-claude-in-a-worktree) 可以在全新的 Git Worktree 中启动隔离会话，[桌面端应用](https://code.claude.com/docs/en/desktop#work-in-parallel-with-sessions)支持多窗口并行平铺运行这些任务，而[云端会话（Cloud Sessions）](https://code.claude.com/docs/en/claude-code-on-the-web)则直接将整个算力推向云端容器执行，完全不占用你的本机资源。

Git Worktree 本质上是一份全新的干净检出，这意味着像 `.env` 这种被 `.gitignore` 忽略的文件并不会天然存在，本地依赖也并未就绪。针对前者，你可以在仓库根目录下创建一个 [`.worktreeinclude`](https://code.claude.com/docs/en/worktrees#copy-gitignored-files-into-worktrees) 文件（语法与 `.gitignore` 完全一致），Claude Code 在为每个会话创建 Worktree 时，会自动将其中列出的受保护私有文件安全复制进去：

.worktreeinclude

```text
.env
.env.local
config/dev-credentials.json
```

请确保该文件只包含轻量配置文件：由于底层采用的是文件物理复制而非符号软链接，若将 `node_modules` 写入其中，会导致每个 Worktree 都要完整拷贝几十甚至上百兆文件。针对庞大依赖目录，可配置 [`worktree.symlinkDirectories`](https://code.claude.com/docs/en/settings-reference#worktree-symlinkdirectories) 实现目录软链接复用，或者将安装命令声明在 `CLAUDE.md` 中，让 Claude 在新工作区启动时自动跑一遍依赖检查。

你几乎不需要亲自打扫维护这些工作树环境：

- 当你退出一个未命名的临时工作树会话时，若其中没有产生有效改动，Claude Code 会[自动清理回收该 Worktree](https://code.claude.com/docs/en/worktrees#clean-up-worktrees)；对于已命名或包含未提交修改的会话，它会贴心询问你如何处理；
- 子智能体独占的工作树会在其完成任务且无改动时自动销毁；
- 那些被意外遗留的后台工作树，一旦闲置时间超过 `cleanupPeriodDays` 设定值且无未结事务，会被系统自动垃圾回收扫描清理。

唯一需要你亲手善后的，是使用 `claude -p --worktree` 启动的批处理命令——由于其执行完直接退出不作停留，你需要后续手动运行 `git worktree remove <path>` 予以清理；若 Git 提示工作树处于锁定状态，先执行 `git worktree unlock <path>` 解锁即可。

面对跨越海量文件的单一机械性重构改造，输入 [`/batch 将所有响应处理函数全量迁移至 v2 响应工具类`](https://code.claude.com/docs/en/commands) 会自动将任务拆解为 5 到 30 个独立的并行单元并向你出示拆分规划。一旦你批准放行，每个子单元都会分配独立的 Worktree 隔离推进并自动提交 PR。在终端运行 [`claude agents`](https://code.claude.com/docs/en/agent-view)（目前为实验性预览特性）则能在单块屏幕上集中俯瞰监控本机后台并发运行的所有智能体工作实况。

此外，开辟第二个独立会话也是获取中立客观第三方审查最经济便捷的方式：会话 A 专心编写接口限流逻辑，会话 B 直接阅读并审查 `@src/middleware/rateLimiter.ts`，由于其完全未曾参与编写过程，不会有任何思维盲区；你只需将 B 会话挑出的 Bug 结论复制回 A 会话即可。这与 `/code-review` 背后的设计哲学如出一辙，唯一的区别只是由你负责在两者之间搬运转达信息。

## 可以停止做的事

以下列出的每一条建议，在它们最初被总结出来时都曾是无比正确的真知灼见。然而它们当中的绝大多数，本质上都是当年针对模型羸弱能力的“打补丁式曲线救国方案”；随着基座模型的日新月异，这批旧范式已经彻底完成了历史使命。如果以下某些做法依然留存在你的肌肉记忆中，这里详述了为什么你可以放心地彻底戒掉它们。

| 过时的旧习惯 | 为什么今天完全可以弃用 |
| --- | --- |
| **“上下文窗口是头等瓶颈，必须极度激进地进行微操管理”** | 当前绝大多数模型均标配 100 万（1M）Token 级别的超大上下文容量，且自带智能平滑的自动压缩机制，你几乎永远不可能把它耗尽。在不同独立任务之间执行 `/clear` 依然非常值得推荐，但这纯粹是为了让上下文保持聚焦以便拿到更高质量的解答并节省成本，而非因为容量会爆炸。 |
| **“遇到 Claude 漏掉的指令，拼命在文字里加 IMPORTANT 或全大写 ALL CAPS”** | 早期的弱模型确实需要通过加粗加大语气来吸引注意力。而当今的模型完全能平等理解平实质朴的文字表达；一味地堆砌感叹号只会诱导 Claude 在不恰当的场景下生搬硬套、过度反应。如果某项规则绝对不容破坏，把它写进 Hook 钩子或 Deny 规则中；如果某行规则在长篇大论中被遗忘，说明你的指引文件太臃肿了，赶紧去删减冗余行数。 |
| **“通过启动子智能体来保护主会话的上下文窗口”** | 担心上下文用尽在今天早已是伪命题。子智能体依然是并行多任务处理、屏蔽冗长杂乱日志干扰以及获取独立客观代码审查的绝佳工具，但请清醒地认识到：每一个派生出的子智能体都会额外消耗你真金白银的 Token。 |
| **“把同一个任务派发给子智能体，以期获得更好的答案”** | 把一模一样的任务原封不动地丢给子智能体，根本不可能凭空变出更高明的结果。引入全新的独立审查员之所以管用，是因为它没有见过你之前的推理过程，这与单纯的“下派任务”有着本质的区别。 |
| **“在提示词中拼命念咒：think hard、think harder、请务必深思熟虑”** | 掌控推演深度的唯一法定把手是 Effort 设置。这类咒语在现代模型看来只是普通的文本碎片，它最多只能在现有的 Effort 等级内部产生极其微弱的倾向拉扯，绝不可能凭空提升思考力度的物理上限。当然，`ultrathink` 是个例外——它被系统专门设计用来在单轮交互中定向激活深度推理模式，而无需改动全局 Effort 档位。 |
| **“在提示词中反复敲打：不要偷懒、继续推进、不达目的绝不罢手”** | 当前的模型在明确了任务目标后通常会极其自觉地贯彻到底，这类情绪化的催促措辞不但无法解决代码卡壳，反而更容易导致模型在细枝末节上画蛇添足。为 Claude 提供一个切实可跑的 Pass/Fail 自动化校验工具才是破局的关键，且这项举措永远有效。如果会话确实在半途意外中断了，输入一句轻描淡写的 `继续（continue）` 便已足够；对于无人值守运行，挂载 `/goal` 或配置 `Stop` 钩子能起到绝对强制的刚性约束。 |
| **“在 `CLAUDE.md` 中花费大量篇幅详述系统架构与文件目录树”** | Claude 自己阅读代码库的速度与深度远超你的想象。只记录那些代码本身绝对体现不出来的隐性增量。 |

如果本指南中提到的其他任何实践建议在日后开始让你感到繁琐甚至沦为了形式主义，那同样也是一个清晰的信号：它多半也该被归入上面这张淘汰清单中了。

## 相关参考资源

- [Claude Code 工作原理全解](https://code.claude.com/docs/en/how-claude-code-works)：执行循环、底层工具集以及系统启动加载流；
- [深入探索上下文窗口](https://code.claude.com/docs/en/context-window)：会话中的空间占用分布与生命周期加载时机；
- [拓展 Claude Code 的无限可能](https://code.claude.com/docs/en/features-overview)：深入权衡技能（Skills）、钩子（Hooks）、MCP 协议、子智能体与插件的选型；
- [选择合适的权限模式](https://code.claude.com/docs/en/permission-modes)与[权限系统深度配置指南](https://code.claude.com/docs/en/permissions)；
- [高效管理与优化使用成本](https://code.claude.com/docs/en/costs)；
- [以无头脚本化模式运行 Claude Code](https://code.claude.com/docs/en/headless)与[借助云端例行任务实现自动化流转](https://code.claude.com/docs/en/routines)；
- 面向技术主管与企业管理员：[为你的组织配置 Claude Code](https://code.claude.com/docs/en/admin-setup)。
