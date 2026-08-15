# CLAUDE.md

## Persistent AI Run Reports

Every substantial task in this repository — implementation, audit, repair or
verification — must leave a written report behind. The full rules live in
`docs/ai-reports/README.md`.

- Write the complete report to `docs/ai-reports/LATEST_REPORT.md`, overwriting
  the previous one.
- Create a dated immutable archive copy under `docs/ai-reports/archive/` using
  `YYYY-MM-DD_HHmm_<task-slug>_<status-slug>.md` in Asia/Seoul time. Never
  overwrite an existing archive file.
- Append one compact entry to `docs/ai-reports/INDEX.md`.
- Keep terminal output to the short completion receipt only. The full report
  belongs in the Markdown file.
- Failures, skipped work and unverified behaviour stay explicit. Never present a
  previous run's test counts as fresh results.
- Report generation is mandatory even when the status is partial or blocked.
- Reports must contain no secrets, tokens, keys, credentials or environment
  values.
- Do not push or merge unless the user explicitly requests it.
