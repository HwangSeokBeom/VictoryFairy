# AI Run Reports — Permanent Workflow

Every substantial AI-assisted task in this repository leaves a complete written
report behind. The terminal is transient; these files are the record.

## Directory

```
docs/ai-reports/
├── README.md          이 문서 — 워크플로 규칙
├── INDEX.md           실행마다 한 줄짜리 이력
├── LATEST_REPORT.md   가장 최근 전체 보고서 (덮어씀)
└── archive/           실행마다 하나씩, 절대 덮어쓰지 않는 사본
```

Markdown, UTF-8. No screenshots, binaries, DerivedData or build output.

## Rules

1. Every substantial implementation, audit, repair or verification task writes a
   complete Markdown final report.
2. Every run creates one immutable archive file under `docs/ai-reports/archive/`.
3. Every run overwrites `docs/ai-reports/LATEST_REPORT.md` with the newest
   complete report.
4. `INDEX.md` receives one compact historical entry per run.
5. The complete report must contain every final-report section the task asked
   for — none may be dropped for brevity.
6. Failures, skipped work and unverified behaviour are never omitted. A report
   that hides a gap is worse than no report.
7. Historical test counts must be labelled historical. Never present a previous
   run's numbers as fresh results.
8. `PARTIAL_WITH_EXPLICIT_GAPS` stays partial until every stated Definition of
   Done item is actually complete.
9. Reports must include: repository, branch, starting HEAD, ending HEAD, changed
   files, fresh test counts, builds, archive evidence, fixture exclusion,
   commits, Git status, remaining gaps, and push/merge status.
10. Reports must never contain secrets, passwords, tokens, private keys, signing
    credentials, environment-variable values or account passwords.
11. After the report is saved, terminal output stays short — see the receipt
    contract below.
12. The user normally uploads only `docs/ai-reports/LATEST_REPORT.md` for review.
13. Reports are documentation only. They are never added to the app target, test
    fixtures or Release resources.
14. Temporary screenshots and `/tmp` artifacts are never committed. A report may
    cite a `/tmp` path as evidence, but must mark it as a local temporary path.

## Archive file naming

```
docs/ai-reports/archive/YYYY-MM-DD_HHmm_<task-slug>_<status-slug>.md
```

Examples:

```
2026-07-31_1015_record-create-foundation_verified.md
2026-07-31_1430_record-create-step1_partial.md
2026-08-01_0900_profile-audit_blocked.md
```

Times are Asia/Seoul. Never overwrite an existing archive file. When a
same-minute filename already exists, append `_02`, `_03`, and so on.

## Terminal receipt contract

After the report files and the commit are complete, the terminal shows only:

```
STATUS: <exact status>
REPORT: <absolute path to LATEST_REPORT.md>
ARCHIVE: <absolute path to the dated archive file>
COMMIT: <commit hash and subject>
GIT_STATUS: <clean or exact remaining changes>
NEXT_ACTION: <one sentence>
PUSHED: NO
MERGED: NO
```

The short receipt never replaces the full report file.

## Push and merge

Nothing is pushed or merged unless the user explicitly asks for it.
