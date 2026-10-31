## Agent skills

### Issue tracker

Issues and specs live as GitHub issues in `AyuSne/zhangmuchuan`, managed with the `gh` CLI. See `docs/agents/issue-tracker.md`.

### Triage labels

Five canonical triage roles map to the same-named labels. See `docs/agents/triage-labels.md`.

### Domain docs

Single-context layout (`GLOSSARY.md` + `docs/adr/` at the repo root). See `docs/agents/domain.md`.

## Build baseline

This site uses OINK v1.4.0 with Hugo Extended 0.169.0 and Go 1.27.3. Keep local builds and CI on this baseline. Do not enable `--panicOnWarning` or `HUGO_PANICONWARNING`; keep warnings visible and review them. The upstream LibSass deprecation warning is accepted.

## Repository hygiene

- Track source, configuration, and lightweight documentation only. Do not commit build output, binaries, archives, or large datasets.
- `.tools/` holds the local toolchain and reference checkouts; it is gitignored.
- Before staging, check file sizes and the staged list; never force-add ignored paths.
