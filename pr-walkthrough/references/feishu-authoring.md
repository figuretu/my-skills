# 飞书写入规程

lark-doc / lark-whiteboard skill 是命令语法与 XML 格式的真相源，动笔前先加载 lark-doc（重点读创建、更新与 XML 格式的参考）。本文只记录走查文档特有的流程规程和实测坑，不重复语法。

## 目标文档

- 用户给了 URL / token：直接用。先 fetch 一次确认可写；若文档非空，告知用户后从文档末尾追加，不动已有内容。
- 用户没给：新建，标题形如「PR 解读：{主题}」，创建后把 URL 告知用户。

## 分块写入

- 先出全文提纲（章节级），再按章分块 append。每块控制在 1,000 行 XML 以内（正文约 3,000 字），一章一块，长章可拆多块。目的有二：单次写入过大容易失败；分块强迫按提纲推进，是有序性的机械保障。
- 块内容先写本地临时文件，再经 stdin 传入（`--content - < file`）。zsh 在命令替换里嵌套 heredoc 会 parse error，一律走临时文件。
- 工作目录建议 `.ai_docs/pr-reads/<slug>/`：分块 XML、Codex 腿输出都放这里，保留到交付之后，综合修订时靠它们定位原文。

## 锚点与修订

- 需要 block id 时用局部 fetch（`--scope section --detail with-ids` 一类），不整篇拉取。
- 行内小改用 str_replace；注意 XML 模式的 str_replace 只做行内匹配，整段重写要用 block_replace，插入用 block_insert_after，均以 block id 定位。
- 画板锚点选在小节点题句之后、细节段之前（图先行，理由见 report-spec 图文节拍）。

## 实测坑

以下是踩过的、报错信息不指向根因的坑：

- SVG 文本里的尖括号占位符（如 `&lt;projectId&gt;`）会被画板解析器当标签吞掉，只剩空壳。占位符一律写成 `{projectId}` 花括号形式。
- `whiteboard +export` 的预览即使 `--output` 写 .png，实际返回 .jpg。自检读文件按 jpg 找。
- zsh 里 `$(cmd <<'EOF' ... )` 命令替换嵌套 heredoc 直接 parse error。多行内容永远先落临时文件。
- str_replace（XML 模式）匹配不到跨行内容时不会明说是行内限制，只报找不到。改整段直接上 block_replace。
