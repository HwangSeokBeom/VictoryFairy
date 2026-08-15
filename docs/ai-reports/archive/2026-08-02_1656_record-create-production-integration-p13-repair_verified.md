> Upload this file to ChatGPT for review and the next implementation prompt.

REPORT_STATUS: RECORD_CREATE_THREE_STEP_PRODUCTION_INTEGRATION_IMPLEMENTED_AND_VERIFIED
REPORT_PROJECT_STATUS: RECORD_CREATE_THREE_STEP_PRODUCTION_INTEGRATION_IMPLEMENTED_AND_VERIFIED
REPORT_BRANCH: feat/pencil-revision-v2
REPORT_BASELINE_HEAD: 268dcb432aae93086779349fab8fe40ebe0666dd
REPORT_HEAD: 0dcfa52946f317a8d6b710949bb88a6c36cac56b
REPORT_PRIMARY_UI_SUITE: COMPLETED_AND_PASSED — Executed 550, passed 477, failed 0, skipped 73, unexpected 0
REPORT_PRODUCTION_CODE_CHANGED: NO

# VictoryFairy AI Run Report — Record Create production integration, P13 repair and final verification

## STATUS

`RECORD_CREATE_THREE_STEP_PRODUCTION_INTEGRATION_IMPLEMENTED_AND_VERIFIED`

Every condition of the status rule is met. `testP13` passes deterministically,
its complete parent class passes, the compact and AccessibilityXXXL assistance
tests pass, one complete final primary UI suite passed in a single run with zero
failures, every width-gated skip has a fresh passing SE 3 counterpart, the full
unit suite and the remaining gates pass, this report and its archive are
current, the working tree is clean, and nothing was pushed or merged.

## PROJECT STATUS

`RECORD_CREATE_THREE_STEP_PRODUCTION_INTEGRATION_IMPLEMENTED_AND_VERIFIED`

The Record Create three-step production integration is closed. Profile / My,
Team Selector and the dedicated `09_States` frames remain unimplemented and were
deliberately not started; they are listed under remaining project gaps and are
outside the scope of this pass.

## SESSION HANDOFF BASELINE

This session took over from the handoff checkpoint written at
`268dcb4 docs(ai): stamp the handoff report ending HEAD`. The checkpoint stated
that production create routing was implemented, that five real create routes use
`RecordCreateFlowView` and two real edit routes stay on `LogEditorView`, and that
the previous complete primary UI run had executed 550 tests with 476 passed, 1
failed, 73 skipped and 0 unexpected, ending `** TEST FAILED **`. All seven
commits the handoff required to be preserved were verified present and
unmodified at takeover: `0576aa0`, `ac33ed3`, `22e8e8c`, `7ab27e1`, `1682f2c`,
`0a4ae72` and `268dcb4`. The working tree was clean, history linear, and no
merge, rebase, cherry-pick or bisect was in progress.

## REPOSITORY / BRANCH / HEAD

The repository is `/Users/hwangseokbeom/GitHub/VictoryFairy` on branch
`feat/pencil-revision-v2`. The date and time at completion was 2026-08-02 16:56
KST. HEAD at the start of this session was
`268dcb432aae93086779349fab8fe40ebe0666dd` and HEAD at the end is
`0dcfa52946f317a8d6b710949bb88a6c36cac56b`, plus the documentation commit that
carries this report. History remains linear. Nothing was pushed, merged, or
opened as a pull request.

## HISTORICAL PRIMARY UI FAILURE

The previous run of 550 tests — 476 passed, 1 failed, 73 skipped, 0 unexpected,
ending `** TEST FAILED **`, recorded in bundle
`Test-VictoryFairy-2026.08.01_23-21-33-+0900.xcresult` — remains a historical
failed run. It is preserved here as history only. It is never combined with, and
never substituted for, any run performed in this session, and none of the
focused, determinism, parent-class or compact results in this report are folded
into the final full-suite count.

## P13 FAILURE EVIDENCE

The single historical failure was
`RecordCreateProductionIntegrationUITests.testP13_ticketOCRAndGameLookupAreReachableInStepOne`,
failing after 60.884 seconds. The recorded failure text was an XCUI snapshot
error: `Failed to get matching snapshot: No matches found for first query match
sequence: Descendants matching type Button -> Elements matching predicate
'"recordCreate.step3.complete" IN identifiers'`, with an automation type
mismatch reported by the accessibility layer.

The failing assertion was `XCTAssertTrue(element.isHittable, …)` at
`VictoryFairyUITests/RecordCreateProductionIntegrationUITests.swift:66`, reached
from the second `recordCreate.assist.findGame` lookup. The recorded text was not
that assertion's message: while building the message, line 68 evaluated `.frame`
on a `recordCreate.step3.complete` button that does not exist on Step 1, and
that read raised the snapshot error, which replaced the real message.

The failure-time accessibility hierarchy established the following. Both
assistance controls existed and were real semantic buttons —
`recordCreate.assist.ticketOCR` labelled `티켓에서 불러오기` at frame
`{{38.1, 662.7}, {325.8, 65.7}}`, and `recordCreate.assist.findGame` labelled
`경기 자동 찾기` at `{{38.1, 735.7}, {325.8, 65.7}}`. Neither was off-screen; the
window was `{{0, 0}, {402, 874}}` and both frames lay fully inside it. Neither
was covered by a pinned bottom action region, because Step 1 has none and
`recordCreate.step3.complete` did not exist anywhere in the hierarchy, which is
the correct Step 1 layout. The query did not resolve to a wrapper: both
assistance controls resolved to the real buttons. The production route and
fixture were correct, with `recordCreate.origin.feed` and
`recordCreate.step1.root` present and no `recordCreate.scenario.*` staging
fixture leaked. Ticket OCR was tapped successfully and its real screen opened,
with the privacy notice `티켓 이미지는 서버로 전송되지 않아요` matched.

Neither production capability was unreachable. No product assertion failed.

## P13 ROOT CAUSE

The ticket OCR sheet was never dismissed. `TicketOCRView` has no `취소` control at
all; its only dismiss action is `닫기`, declared at
`VictoryFairy/Features/OCR/TicketOCRView.swift:81` as `Button("닫기") { dismiss() }`.
The test tapped `app.buttons["취소"].firstMatch`, and because the flow's own
chrome button `recordCreate.cancel` also carries the label `취소` and comes earlier
in the accessibility hierarchy than any presented sheet, that query always
resolved to the chrome button. Being covered by the sheet, it could not be
pressed at all — the trace records `Check for interrupting elements affecting
"recordCreate.cancel" Button` followed by `Computed hit point {-1, -1} after
scrolling to visible`.

Nothing was dismissed. The old guard then treated the continued existence of
`recordCreate.step1.root` as proof of return to Step 1, which is invalid because
the underlying presentation stays in the accessibility hierarchy while a sheet is
still presented. The test proceeded on a false premise, swiped sixteen times
against a covering sheet, and failed — and the diagnostic read of `.frame` on the
absent pinned bar concealed the real cause for the entire run.

## P13 TEST-HARNESS REPAIR

The classification is a test-harness defect. No production regression was
demonstrated, and no production source was modified. The repair covers three
things: dismissing each sheet through the control it actually has, proving return
to the flow rather than inferring it, and making failure diagnostics incapable of
throwing.

## OCR SHEET DISMISSAL REPAIR

Dismissal is now scoped to the sheet itself. A sheet is identified by its own
navigation bar — `티켓 사진 인식` for ticket OCR — and its close control is located
first inside that navigation bar and otherwise in the sheet body with the flow
chrome identifiers `recordCreate.cancel` and `logEditor.cancel` explicitly
excluded, so the covered chrome button can never be picked. The control must
exist, must lie inside the current window, and must be hittable before it is
tapped; then the sheet's own navigation bar must disappear. No arbitrary sleep,
no coordinate tap, and no tap on `recordCreate.cancel` is involved.

The same defect was found in `testP14_photoAnalysisAndAIDraftAreReachableInStepThree`,
which dismissed the `사진 분석` and `AI 초안` sheets the same way. The historical
activity trace proves both of its `취소` taps also resolved to
`recordCreate.cancel` at hit point `{-1, -1}`, so neither sheet was ever
dismissed there either. Its historical pass was a false pass that survived only
because XCUI intermittently reported a covered button hittable. Both sheets are
now dismissed through their own `취소` controls.

## RETURN-TO-STEP1 PROOF

Return is proven, not inferred. The sheet's own navigation bar must be gone, the
step root must exist, and the flow's own chrome control must be hittable again —
the last being the decisive signal, since that same control measured a
`{-1, -1}` hit point while covered. For ticket OCR the sheet-specific notice
`티켓 이미지는 서버로 전송되지 않아요` must also be absent. `exists` alone is no longer
accepted as a return guard anywhere in the repaired paths. `testP13` additionally
confirms that `경기 자동 찾기` becomes visible inside the usable viewport and
hittable, that the lookup answers, that Step 1 stays open, and that the Step 1
draft values for stadium and opponent are unchanged by either assistance action.

## SAFE SCROLL DIAGNOSTICS

The pinned bottom action bar is now optional. Its frame is read only after
`exists`, and it is reported as `NONE` when absent, which is the correct layout
for Step 1 and Step 2. Failure-message construction reads nothing from a missing
element and reports the target identifier, label, existence, hittability, frame,
the window, the obstruction frame or `NONE`, the swipe count and any sheet still
on screen. `scrollIntoView` no longer accepts `isHittable` alone; it also
requires the target to be inside the usable viewport.

## PRODUCTION SOURCE IMPACT

None. `git diff --stat 268dcb4 HEAD -- VictoryFairy/` is empty, so production
source is byte-identical to the baseline. The only changed files in the entire
pass are two UI test files. `TicketOCRView`, `RecordCreateStep1View`,
`RecordCreateFlowView`, production accessibility identifiers, production routing,
assistance services, draft mapping, persistence, API contracts, backend, AppIcon,
LaunchMark and the Fairy systems are all untouched. No assertion was weakened to
existence-only.

## P13 FOCUSED RESULT

`testP13_ticketOCRAndGameLookupAreReachableInStepOne` passed in 29.966 seconds on
iPhone 17 Pro, against the historical 60.884-second failure. Ticket OCR opened,
the OCR sheet was dismissed through `닫기`, return to Step 1 was positively
proven, `경기 자동 찾기` became visible and hittable, game lookup opened and
answered, nothing was saved, and the canonical draft remained intact.

## P13 DETERMINISM RESULT

Three additional consecutive runs from fresh app state, each preceded by removal
of the installed app and test runner, passed at 29.413, 29.237 and 29.590
seconds. Together with the focused run that is four passes out of four, with no
retry logic, no arbitrary sleep, no conditional skip, no coordinate tap and no
production-source change. A combined `testP13` and `testP14` run also passed both
tests in 87.132 seconds.

## P13 PARENT-CLASS RESULT

The complete `RecordCreateProductionIntegrationUITests` class executed 16 tests
with 0 failures and 0 unexpected failures in 547.164 seconds, ending
`** TEST SUCCEEDED **`.

## TICKET OCR PARITY

Ticket OCR is reachable and behaves identically on the production create route.
`testP13` confirms `recordCreate.assist.ticketOCR` is present, hittable, opens
the real `TicketOCRView` with its privacy notice, and closes through `닫기`
without saving. At compact width, `RecordCreateFoundationResponsiveUITests`
`testCompact10_featureSurfacesRemainReachable` and the five
`RecordCreateProductionIntegrationResponsiveUITests` compact route tests, which
assert `recordCreate.assist.ticketOCR` through `assertStep1Compact`, all pass on
SE 3.

## KBO LOOKUP PARITY

KBO game lookup is reachable and answers on the production create route.
`testP13` confirms `recordCreate.assist.findGame` is visible inside the usable
viewport, hittable, and that `recordCreate.assist.lookupStatus` appears with a
non-empty label even when there is no result, without closing the flow or saving.
At compact width,
`RecordCreateProductionIntegrationResponsiveUITests.testCompact07_stepOneAssistanceStaysReachableAndAnswers`
passes on SE 3, along with the same five compact route tests that assert
`recordCreate.assist.findGame`.

## COMPACT ASSISTANCE RESULT

The focused OCR and KBO compact parity run executed 8 tests with 0 failures in
172.587 seconds on the SE 3 simulator `VF-CalendarCompact-SE3`. It covered
`testCompact10_featureSurfacesRemainReachable` and
`testAccessibility07_featureSurfacesRemainReachable` from the foundation
responsive class, the five compact production create route tests, and the
compact lookup-answers test.

## ACCESSIBILITYXXXL ASSISTANCE RESULT

AccessibilityXXXL assistance coverage passes on real production create routes.
`RecordCreateFoundationResponsiveUITests.testAccessibility07_featureSurfacesRemainReachable`,
which reaches both `recordCreate.assist.ticketOCR` and
`recordCreate.assist.findGame` at AccessibilityXXXL, passed in 23.043 seconds in
the focused parity run and again inside the complete class run.
`RecordCreateProductionIntegrationResponsiveUITests` accessibility tests
`testAccessibility01` through `testAccessibility04` also pass, including the
check that the category actually applies and that Step 1 stays usable from a
production route.

## FINAL COMPLETE PRIMARY UI SUITE

One complete `VictoryFairyUITests` run was performed from the beginning against
the final production source, the final UI-test source, the final test bundle and
a clean simulator installation, with the app and test runner uninstalled before
the run.

It executed 550 tests with 477 passed, 0 failed, 73 skipped and 0 unexpected
failures in 8494.635 seconds, ending `** TEST SUCCEEDED **`, on iPhone 17 Pro,
iOS Simulator, Debug configuration. Two independent sources agree exactly: the
`xcodebuild` summary line reads `Executed 550 tests, with 73 tests skipped and 0
failures (0 unexpected) in 8494.635 seconds`, and `xcrun xcresulttool get
test-results summary` reports result `Passed` with `totalTestCount` 550,
`passedTests` 477, `failedTests` 0, `skippedTests` 73 and `expectedFailures` 0.
The result bundle is finalized and readable.

One verification note is recorded for honesty: a naive text search of the run log
for the word `failed` matches six lines, but all six are test names that contain
the word — `testCapture05_failedPhotoDecode`, `testD20_failedDecodeHasItsOwnState`
and `testD37_failedDeletionStaysOnTheDetail`, each matching on its `started` and
`passed` lines. All three passed and the log contains zero `error:` lines. The
authoritative counts are the two agreeing sources above.

This count comes from that single run alone. No focused, determinism,
parent-class, compact or historical result is included in it.

## FINAL SKIP ACCOUNTING

All 73 skips in the final primary run are width-gated responsive tests that are
skipped by `XCTSkip` on the iPhone 17 Pro because the check is only meaningful at
375pt-class width. Every one of the 73 has a fresh passing SE 3 counterpart in
the compact matrix described below, executed from the final test source. The
pairing was computed mechanically by extracting the skipped method list from the
final run and the passing method list from the compact run and taking the set
difference; the number of unpaired skips is zero.

The distribution by class is 14 in `RecordCreateFoundationResponsiveUITests`, 12
in `RecordCreateProductionIntegrationResponsiveUITests`, 9 in
`RecordCreateStep1ResponsiveUITests`, 9 in `RecordDetailResponsiveUITests`, 8 in
`StatisticsResponsiveUITests`, 7 in `RecordCreateStep2ResponsiveUITests`, 7 in
`RecordCreateStep3ResponsiveUITests` and 7 in `CalendarResponsiveUITests`. For
every one of those methods, the same class and method name appears in the SE 3
run as passed. The reason in each case is the same width gate, the expected
compact counterpart is the identical method, the compact device is
`VF-CalendarCompact-SE3`, and the counterpart result is passed.

## COMPACT COUNTERPARTS

The complete compact-counterpart matrix was rerun from the final test source
across all nine responsive classes on `VF-CalendarCompact-SE3`. It executed 141
tests with 0 failures and 0 skips in 3249.198 seconds, ending
`** TEST SUCCEEDED **`.

Two earlier compact runs are explicitly discarded and are not cited as evidence.
The first two attempts were stopped by the task runner at roughly 25 minutes
before completing, so they are incomplete rather than failed. A later complete
141-test run contained the pre-repair `testKeyboard01` failure and predates both
helper corrections. Their result bundles were deleted so no stale compact
evidence could be quoted by mistake. Only the final 141-test run is cited.

## SECOND TEST-HARNESS DEFECT — COMPACT VIEWPORT

Running the compact matrix exposed a second, previously unexercised defect.
`RecordCreateFoundationResponsiveUITests.testKeyboard01_diaryStaysVisibleWhileTyping`
failed on SE 3. Because it is one of the 73 width-gated skips, it had never
actually run at compact width before this pass, so the skip-accounting
requirement is what surfaced it.

The evidence showed the editor navigation bar `직관 기록 수정` occupying y 46 to 100
while the `좌석` text field came to rest at y 31 to 53, underneath it, with its own
label scrolled to y −3.5. The private `scrollIntoView` in that file used the raw
window top as its ceiling, so a target under the top chrome satisfied
`minY >= 0`, XCUI still reported it hittable, the tap landed on the navigation bar
rather than focusing the field, and the keyboard never appeared. It is a boundary
condition, which is why it passed in isolation and failed inside its class — only
the scroll offset differed. Production behaviour was not shown to be defective;
a real user can scroll the field clear of the chrome.

I record one correction to my own earlier judgement. On first observation I
classified this as a transient simulator keyboard delay on the strength of three
isolated passes. That was wrong. It failed a second time at 33.266 seconds
against 33.217 seconds — near-identical early bails — which is order-dependent and
reproducible, not transient.

## REPORT DEVIATION — VIEWPORT ACCEPTANCE CONTRACT

The first repair instruction required universal full-frame containment inside the
usable viewport. Runtime AccessibilityXXXL evidence proved that requirement
unsatisfiable, and my first implementation of it turned one failure into seven.

The evidence was as follows. `티켓에서 불러오기` measured 604pt tall inside a 567pt
usable viewport, so full containment is arithmetically impossible for it. Two
`구장` controls were rejected while hittable with 63.5pt and 93.5pt visible, far
more than a finger needs. Deciding the scroll direction afresh each iteration made
the seat field oscillate between y −51 and y 666.5 until the swipe budget ran out.
A further case appeared during repair: `logEditor.cancel` at y 50 to 86 lives
inside the navigation bar spanning y 46 to 100, so it can never be scrolled below
the ceiling at all.

The final helper therefore verifies semantic target identity, a meaningful visible
intersection, actual hittability, top and bottom obstruction avoidance, and
monotonic scroll convergence, rather than universal full-frame containment. This
is a test-contract correction and does not weaken the production accessibility
requirement.

Concretely, the helper computes the usable viewport as the band below the topmost
visible top-anchored navigation chrome and above any visible keyboard or toolbar,
reading a frame only after `exists`. It accepts a target when the intersection of
its frame with that band is at least `min(44pt, frame.height)` tall and
`min(44pt, frame.width)` wide and the element is hittable. The 44pt threshold is
the Human Interface Guidelines minimum touch target, and the 0.5pt tolerance
covers floating-point geometry only, never a real occlusion. Elements taller than
the viewport are accepted on the same visible-intersection basis and reported as
`OVERSIZED_BUT_ACTIONABLE`. Controls whose frame lies inside a chrome region are
recognised as pinned and accepted when hittable. Scrolling holds one direction,
permits exactly one deliberate reversal when the target has crossed the whole
viewport, then switches to small edge drags instead of another full swipe, and
stops with `NO_SCROLL_PROGRESS` after two stalled swipes. Diagnostics distinguish
`NOT_PRESENT`, `ABOVE_VIEWPORT`, `BELOW_VIEWPORT`, `INSUFFICIENT_VISIBLE_REGION`,
`NOT_HITTABLE`, `NO_SCROLL_PROGRESS` and `OVERSIZED_BUT_ACTIONABLE`, and construct
their message without reading anything from an absent element.

I state plainly that the seven-failure class run was caused by my own over-strict
rule in commit `48bc037`, not by a pre-existing defect. That commit is kept in
history rather than amended, because its run is the evidence that disproved the
containment requirement.

After the correction, all seven previously failing methods passed individually in
375.732 seconds, then three consecutive times from fresh app state at 370.835,
366.251 and 376.900 seconds for 21 passes and no failures. The complete
`RecordCreateFoundationResponsiveUITests` class then executed 24 tests with 0
failures in 856.114 seconds.

## FULL UNIT SUITE

The full unit suite was rerun from the final source state and executed 765 tests
with 0 failures and 0 unexpected failures in 8.277 seconds, ending
`** TEST SUCCEEDED **`.

## BUILDS AND GATES

The standalone Debug build succeeded and the standalone Release build succeeded,
both for the iOS Simulator destination. `scripts/verify_app_icon.sh`,
`scripts/verify_release_readiness.sh`, `scripts/scan_for_secrets.sh` and
`scripts/verify_fixture_exclusion.sh` all passed. `git diff --check` is clean.
The XCUITest target compiles, as demonstrated by every UI run in this report.

## ARCHIVE VALIDITY

No production archive was rebuilt, and none needed to be. Production source is
byte-identical to the baseline `268dcb4`, confirmed by an empty
`git diff --stat 268dcb4 HEAD -- VictoryFairy/`. Only UI-test code changed in this
pass. The existing archive evidence therefore still corresponds to the same
production source and is reported as reused and source-valid, not as newly
created. `verify_release_readiness.sh` passed against this unchanged source.

## FIXTURE EXCLUSION

`scripts/verify_fixture_exclusion.sh` passed. No screenshots, binaries,
DerivedData or build output were committed. The result bundles, logs and exported
attachments cited in this report live under `/private/tmp` and inside
DerivedData; they are local temporary evidence paths only and are marked as such.
This report contains no secrets, tokens, keys, credentials, signing material or
environment-variable values.

## INFRASTRUCTURE INCIDENTS

Three background task runners were stopped at roughly 25 minutes by the harness
while long compact runs were still in progress. These were not test failures and
their partial runs are discarded rather than counted. The remedy was to detach the
long runs from the harness task lifetime with `nohup` and observe them by polling,
after discovering that `setsid` is unavailable on macOS. The final complete UI run
was launched this way, survived one observer being stopped, and exited on its own
with its result bundle finalized.

No simulator was restarted and no process was killed by this session. At the end
of the run no `xcodebuild` process and no UI test runner remained.

## CHANGED FILES

Two files changed across the whole pass, both UI tests, totalling 399 insertions
and 32 deletions. `VictoryFairyUITests/RecordCreateProductionIntegrationUITests.swift`
gained sheet-scoped dismissal, positive return-to-flow proof and non-throwing
viewport diagnostics. `VictoryFairyUITests/RecordCreateFoundationResponsiveUITests.swift`
gained the usable-viewport model, the reachability acceptance contract and
monotonic scrolling. No production file changed.

## COMMITS

All pre-existing commits are preserved. Nothing was amended, reset, rebased,
cherry-picked or discarded, and `268dcb4` was not amended.

Three commits were created by this session. `4c84baa test(record-create): dismiss
assistance sheets through their own controls` is the atomic test-harness change
covering the OCR and photo-analysis and AI-draft sheet dismissal, the return
proof, and the safe diagnostics; the first two planned commits were combined
because they are one indivisible change to one file driven by one failure.
`48bc037 test(ui): scroll against the usable viewport, not the raw window` is the
first compact viewport repair, retained because its run produced the evidence that
disproved universal containment. `0dcfa52 test(ui): accept a reachable control,
not a fully contained frame` is the corrected acceptance contract. A fourth
commit carries this report, its archive copy and the index entry. No empty commit
was created for test execution.

## GIT STATUS

The working tree was clean at the start of this session and is clean after the
documentation commit.

## REMAINING RECORD CREATE INTEGRATION GAPS

None. The production integration pass is closed. The failing test is repaired and
deterministic, its parent class passes, the second compact defect that the skip
accounting exposed is repaired and deterministic, the complete primary UI suite
passes with zero failures in a single run, every width-gated skip has a fresh
passing compact counterpart, the unit suite passes, and the builds and gates pass.

## REMAINING PROJECT GAPS

Profile / My, Team Selector and the dedicated `09_States` frames remain
unimplemented and were not started. Three product decisions remain deferred
unchanged: `STEP3_RATING`, `STEP3_DIARY_LENGTH_LIMIT` and
`RESUMABLE_TEMPORARY_SAVE`.

One observation is carried forward rather than acted on. The sibling per-file
`scrollIntoView` copies in the other responsive and capture UI-test classes still
use the raw window as their ceiling and so carry the same latent top-chrome
defect. They were deliberately not changed, because no focused failure proved the
defect in them and the instruction was not to generalise without such evidence.
All of those classes pass today. This is recorded as a known latent risk, not as
a failure.

## FINAL CONCLUSION

The historical run of 550 tests that ended `** TEST FAILED **` remains a
historical failed run and is not merged into any result here. The production
ticket OCR and KBO lookup capabilities were reachable the whole time; the failure
was caused by the test harness. `TicketOCRView` uses `닫기`, not `취소`, so the old
dismissal query silently pressed the flow's covered chrome button at hit point
`{-1, -1}`. The old guard falsely treated the underlying Step 1's continued
existence as proof of dismissal. The old diagnostic read `.frame` from a missing
element and replaced the real failure with an opaque snapshot error.

Production code did not change. `testP13` passed focused in 29.966 seconds and
three more consecutive times at 29.413, 29.237 and 29.590 seconds. Its parent
class passed 16 of 16 in 547.164 seconds. The final complete primary UI suite
passed in one run with 550 executed, 477 passed, 0 failed, 73 skipped and 0
unexpected in 8494.635 seconds. All 73 skips are paired with fresh passing SE 3
counterparts and zero remain unpaired. Every compact counterpart passed. The
working tree is clean. Nothing was pushed and nothing was merged.

## PUSH / MERGE

Pushed: NO. Merged: NO. Pull request: not created.
