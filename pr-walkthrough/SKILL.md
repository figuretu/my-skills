---
name: pr-walkthrough
description: PR / 分支变更深度解读。全量精读 diff 后在飞书文档中产出一份走查文档——旅程式叙事、画板图解、真实代码片段、排查路标，帮助项目 owner 重建对代码的理解与掌控（只做理解，不做 code review）。硬依赖 lark-cli 与 lark-doc / lark-whiteboard skill。适用场景：(1) 用户要求解读、理解某个 PR、分支或本地 diff 做了什么，(2) 用户给出 GitHub PR 链接或编号要求分析其设计与影响，(3) 大型变更（含 agent 代写的代码）合并前需要系统性摸清关键设计与流程。
---

# PR Walkthrough

产出物不是 diff 摘要，而是「读者心智模型的增量更新」：读者假设没看过这个 PR 的任何 diff，读完能在脑中重建逻辑在代码里的流转路径，将来排查问题知道从哪个文件、哪个函数下手。产出形式是一份飞书文档。

## 第零步：前置检查

确认以下依赖全部可用，缺任何一项，直接告知用户缺什么、本 skill 无法执行，然后停止。不提供任何替代输出形式。

- `lark-cli` 可执行（`command -v lark-cli`，找不到再看 `/opt/homebrew/bin/lark-cli`）。
- `lark-doc` 与 `lark-whiteboard` skill 在当前环境的可用 skill 列表中。

## 资源

| 文件 | 用途 | 何时读 |
|------|------|--------|
| `references/report-spec.md` | 读者模型、文档骨架、图文节拍、写作规则 | 第五步动笔前必读 |
| `references/subagent-prompts.md` | 子系统精读 / 文档矿工 / 画板绘制 prompt 模板与编排要点 | 第三步分发 subagent、第六步插画板时必读 |
| `references/feishu-authoring.md` | lark-cli 写入规程与实测坑 | 第五步动笔前必读 |
| `references/codex-leg.md` | Codex 独立分析腿的启动、prompt、结果吸收规程 | 第三步决定启动 Codex 分析腿时必读 |

## 第一步：鉴别输入

- **确定 diff 来源**：本地分支用 `git diff <base>...HEAD`（base 通常是 main/master，留意目标仓库可能是工作区里的独立 git 仓库）；远程 PR 用 `gh pr view <id>` 和 `gh pr diff <id>`。`gh` 不可用或无权限时，请用户提供 diff 或 checkout 分支。
- **判型**：重构 / 功能 / 修复 / 混合。类型决定旅程的叙事框架（重构讲"同一操作的新旧管线对比"，功能讲"新增的旅程"，修复讲"原来错在哪"）。
- **判来源**：自己的 PR 主动搜寻随附文档（技术方案、执行计划、run log、遗留清单），它们是"计划 vs 实现偏差"章节的矿源；别人的 PR 没有这一节。
- **目标文档**：用户给了飞书文档 URL 则记下备用；没给则第五步新建，此处不用问。

## 第二步：称重

```bash
# 各目录变更量分布（决定编排与报告地图）
git diff <base>...HEAD --numstat | awk '$1!="-" {split($3,p,"/"); k=p[1]"/"p[2]; v[k]+=$1+$2} END {for (i in v) print v[i], i}' | sort -rn
# 测试占比
git diff <base>...HEAD --numstat | awk '$1!="-" {if ($3 ~ /\.test\.|\.spec\.|__tests__|\/test\//) t+=$1+$2; else s+=$1+$2} END {print "test:", t, "non-test:", s}'
# rename 检测（防把机械搬运当真实变更读）
git diff <base>...HEAD -M --summary | grep rename
# commit subject 集中扫一遍：判型 + 嗅偏差线索。只扫 message，不逐 commit 读 diff
git log --format='%s' <base>..HEAD
```

称重要诚实：结论可以是"几乎全是设计承载代码"，不为安抚读者把 PR 说小。机械变更（lockfile、shim、搬运、等价替换、测试缩进重排）识别出来，供报告"可放心略过"列。

## 第三步：编排（按 diff 量分档）

- **< ~1,000 行**：不分发，直接逐文件精读全部 diff。
- **1,000–5,000 行**：主力自己读，可视子系统边界分 1–3 个 subagent。
- **> 5,000 行**：按子系统 fan-out 精读 + 文档矿工（如有随附文档）。读 `references/subagent-prompts.md`，按模板填充后**在同一条消息里并行发出**全部 agent。

不论哪一档：全量精读，不抽样、不略读；每一行改动必须在某个 agent 的视野之内（杂项 agent 兜底）。

**Codex 独立腿默认不起。** 只在两种情况下起：用户点名要 Codex / 双视角；或 diff 超过 ~5,000 行时主动问一句"要不要加一条 Codex 独立分析腿追求更全的视角"（问一次即可，用户不要就不起）。起腿时读取 `references/codex-leg.md`，按其中规程后台运行、输出落 `.ai_docs/pr-reads/<slug>/`，主力照常推进后续步骤，其产物留到第七步吸收。

## 第四步：主力二次精读（硬规则）

subagent 的素材只能当**地图**——定位哪里重要、结论是什么。**文档中出现的每一段代码，必须亲自 Read 过其所在文件后亲手裁剪。** 引用二手转述会把文档写成摘要腔，且无法保证代码与叙述对得上。

做法：根据素材确定旅程后，列出旅程途经的核心文件清单（入口、调度器、关键算法等），逐个 Read（大文件可按函数定位后读区段），然后才动笔。

## 第五步：合成正文

1. 读 `references/report-spec.md` 与 `references/feishu-authoring.md`，并加载 `lark-doc` skill。
2. 确定目标文档：用户给了 URL 用之；没给则新建（规程见 feishu-authoring）。
3. 先出全文提纲（章节级），再按章分块写入。分块规程见 feishu-authoring；分块本身就是有序性的保障，动笔前想不清提纲就不要动笔。
4. 正文只写文字、表格与代码块，画板留到第六步统一插入；需要画板的小节，点题句写好即可。

## 第六步：画板规划与插入

正文定稿后规划全文画板，共 3–6 张，每张只回答一个问题；优先给图状信息（状态机、闸门、管线、泳道、时序）。规划产物是每张图的「事实清单 + 结构隐喻」，见 `references/subagent-prompts.md` 的画板模板。

- 文档顺序图先行：插入锚点选在小节点题句之后、细节段之前（锚点获取见 feishu-authoring）。
- 每张图一个 SubAgent，全部在同一条消息里并行发出；每个 SubAgent 必须走「插入 → 导出预览 → 看图 → 修」的自检闭环。

## 第七步：综合修订与交付

1. 起过 Codex 腿的：对比两腿发现，矛盾处回代码上核实，独有发现用 block 级修订补进对应章节。
2. 终检通读：导出全文过一遍，对照 report-spec 的写作规则与骨架自查（章节完整、图在细节之前、句子层没有失控），发现问题用 block 级指令修订。
3. 交付：终端给不超过 10 行的摘要 + 文档 URL，重点结论（如合并前必办事项）点出来。

## 边界

**只做理解，不做 code review**：不挑刺、不评风格、不提改进建议。"重要逻辑没有测试兜底"属于事实陈述，写入文档的测试与风险章节。
