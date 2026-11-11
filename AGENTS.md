## Agent skills

### Issue tracker

Issues and specs live as GitHub issues in `AyuSne/zhangmuchuan`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles map to the same-named labels. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`GLOSSARY.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.

## Translation workflow

翻译文章时使用 [baoyu-translate](../AAA个人博客网站资料/.agents/skills/baoyu-translate/SKILL.md)，并按 [译文工作流程](docs/GUIDE.md#35-添加译文)保存原文和译稿。按作者要求使用 [adapt-translation-to-hugo](../AAA个人博客网站资料/.agents/skills/adapt-translation-to-hugo/SKILL.md) 将译稿适配到 `content/translations/`；提交、推送与上线以作者单独的发布请求为准。

## Build baseline

This site uses OINK v1.4.0 with Hugo Extended 0.169.0 and Go 1.27.3. Keep local builds and CI on this baseline. Do not enable `--panicOnWarning` or `HUGO_PANICONWARNING`; keep warnings visible and review them. The upstream LibSass deprecation warning is accepted.

## Repository hygiene

- Track source, configuration, and lightweight documentation only. Do not commit build output, binaries, archives, or large datasets.
- `.tools/` holds the local toolchain and reference checkouts; it is gitignored.
- Before staging, check file sizes and the staged list; never force-add ignored paths.
