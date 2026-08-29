# App Store local smoke evidence

## Status and scope

- Evidence window: 2026-08-29 02:37-02:46 CEST (Europe/Zurich).
- Source commit: `b6198f8510e78e8814edf4b9357e85137aadcb2d`.
- Associated remote branch: `origin/codex/localization-app-store-prep`.
- Verification checkout: detached at the source commit and clean before this evidence file was created.
- Scope: repository-local automated checks and read-only host-capability preflight only.
- Acceptance status: **Task 11 is not accepted.** No manual native-language, relaunch, real Store sandbox, VoiceOver, printing, menu-bar, or clipping scenario was completed.

This record does not claim that MacPad is signed, notarized, submitted, approved, distributed, or verified in production. No app was launched, no system permission was changed, and no Apple account or distribution service was accessed.

The signed candidate path and signed candidate hash are unavailable because all signing, including ad-hoc signing, was outside the authorized scope. The exact source commit above is the only candidate identity recorded here.

## Result definitions

| Result | Meaning |
| --- | --- |
| `PASS` | The manual scenario was performed on the required candidate and every listed observation passed. |
| `FAIL` | The manual scenario was performed and at least one required observation failed. |
| `SKIPPED-AUTHORIZATION` | The scenario was not run because it requires an action that was explicitly not authorized. |
| `BLOCKED-HOST` | The scenario was not run because this host lacked the required display or accessibility capability and changing host permissions was not authorized. |
| `NOT TRIGGERED` | The defect-reproduction step was unnecessary because no authorized manual scenario reached a product defect. |

Automated command results use their process exit codes. A passing automated check is evidence only for the behavior that check directly exercises; it is not a manual smoke-test pass.

## Automated evidence

The Swift command blocks below share this public-safe scratch-path preamble, initialized once in the same shell:

```bash
TASK11_SCRATCH_ROOT="$(mktemp -d)"
```

### Checkout identity

Commands:

```bash
git status --short --branch
git rev-parse HEAD
git branch -r --contains HEAD
```

Expected: exit `0`, exact source commit, detached clean checkout, and association with the named remote branch.

Result: exit `0`. The checkout reported detached `HEAD`, no modified or untracked files, the exact source commit above, and association with `origin/codex/localization-app-store-prep`.

### Localization catalogs

Command:

```bash
./scripts/check-localizations.sh
```

Expected: exit `0`; 129 `Localizable` keys and 1 `InfoPlist` key validated for both English and German.

Result: exit `0`. The validator reported 129 `Localizable` keys and 1 `InfoPlist` key for both English and German. This proves the repository catalogs satisfy the validator contract; it does not prove Launch Services offers both per-app languages or that the rendered UI is unclipped.

### Focused tests

Localization command:

```bash
swift test --disable-sandbox --scratch-path "$TASK11_SCRATCH_ROOT/focused-tests" --filter LocalizationTests
```

Expected: exit `0`; all selected localization tests pass.

Result: exit `0`; 7 tests in 1 suite passed with 0 failures.

Window-routing command:

```bash
swift test --disable-sandbox --scratch-path "$TASK11_SCRATCH_ROOT/window-routing-tests" --filter WindowRoutingTests
```

Expected: exit `0`; all selected window-routing tests pass.

Result: the build completed, but the test process emitted no test results during a bounded 60-second wait. It was interrupted and exited `130`. **No local `WindowRoutingTests` pass is claimed.**

Combined file-access and persistence command:

```bash
swift test --disable-sandbox --scratch-path "$TASK11_SCRATCH_ROOT/safe-focused-tests" --filter 'SecurityScopedFileAccessTests|RecentDocumentStoreTests|PersistedFileReferenceTests|SessionStateTests'
```

Expected: exit `0`; all selected file-access, recent-document, persisted-reference, and session-state tests pass.

Result: no test result was emitted during the bounded wait, so the process was interrupted and exited `130`. No local result is claimed for that combined attempt.

Core persistence rerun:

```bash
swift test --disable-sandbox --scratch-path "$TASK11_SCRATCH_ROOT/safe-focused-tests" --filter 'PersistedFileReferenceTests|SessionStateTests'
```

Expected: exit `0`; all 27 selected tests in 2 suites pass with 0 failures.

Result: exit `1`; 27 tests in 2 suites ran with 3 issues. The `Session state` suite passed. Three persisted-file-reference cases failed when the restricted local runner returned `NSCocoaErrorDomain` code `512` while writing temporary fixture files. This is retained as a local host result and is not relabeled as a product pass or failure.

### Full local suite

Command:

```bash
swift test --disable-sandbox --scratch-path "$TASK11_SCRATCH_ROOT/full-tests"
```

Expected: exit `0`; the complete repository test suite passes with 0 failures.

Result: the local build did not complete within the bounded 60-second verification window. The process was interrupted and exited `130` before a full test total was available. **No full local-suite pass is claimed.**

### Local unsigned Store preflight

Command:

```bash
./scripts/app-store-preflight.sh
```

Expected: exit `0`; the complete unsigned Store preflight passes without signing, export, or distribution.

Result: exit `1`. Before the failure, the script passed its entitlement lint, public-repository content check, and English/German localization check. The first unsigned native build then failed because the restricted runner could not write SwiftPM diagnostic cache data and could not access host simulator services. The command set `CODE_SIGNING_ALLOWED=NO`; no signing, export, upload, or distribution action occurred. **No local Store-preflight pass is claimed.**

### Screenshot validator

Command:

```bash
./scripts/validate-store-screenshots.sh
```

Expected for the current incomplete Task 10 state: exit `1` and a fail-closed missing-screenshot result. Store-readiness expectation after Task 10 is six valid screenshots and exit `0`.

Result: exit `1`, fail-closed because `StoreAssets/Screenshots` is absent. The expected six Task 10 screenshots remain absent. No screenshot was created or altered.

### Read-only host capability preflight

Command:

```bash
swift -module-cache-path "$TASK11_SCRATCH_ROOT/host-module-cache" -e 'import ApplicationServices; import CoreGraphics; var count: UInt32 = 0; let status = CGGetActiveDisplayList(0, nil, &count); print("display_query_status=\(status.rawValue)"); print("active_display_count=\(count)"); print("screen_capture_preflight=\(CGPreflightScreenCaptureAccess())"); print("accessibility_trusted=\(AXIsProcessTrusted())")'
```

Expected for an acceptance-capable interactive host: exit `0`, display-query status `0`, at least 1 active display, screen-capture preflight `true`, and accessibility trust `true`.

Result: exit `0` with:

```text
display_query_status=0
active_display_count=0
screen_capture_preflight=false
accessibility_trusted=false
```

These values only establish that this runner cannot perform the required visual and accessibility smoke work. No permission prompt was triggered and no permission setting was changed.

### Exact-commit remote CI

Expected: the exact source commit completes the full remote tests, English/German localization validation, and unsigned Store preflight without signing, export, or distribution.

Result: the exact source commit completed the repository's remote Swift workflow successfully in 3 minutes 36 seconds: [GitHub Actions run 33224026548](https://github.com/anvilfilbert/MacPad/actions/runs/33224026548).

The remote run reports 148 tests in 11 suites with 0 failures, validation of 129 `Localizable` keys and 1 `InfoPlist` key for English and German, and a passed unsigned App Store preflight with no signing, export, or distribution. This is separate remote automation evidence. It does not erase the local hang/failures above, and it does not prove any manual macOS integration or signed-runtime behavior.

## Automated-evidence limits

Automated language injection, accessibility identifiers, security-scoped bookmark tests, and unsigned entitlement inspection do **not** prove any of the following:

- Launch Services exposes English and German as native per-app language choices;
- a language change safely terminates and relaunches the real app;
- VoiceOver announces correct localized labels;
- the signed Store candidate runs in the real App Sandbox;
- Open, Save, Save As, session restore, Open Recent, conflict reload, and bookmark renewal work across a signed sandbox lifecycle;
- printing succeeds with the runtime print entitlement;
- menu-bar-only document creation works in the signed runtime;
- English or German UI text is visually unclipped;
- the signed binary contains and honors the intended runtime entitlements.

Those observations require the manual scenarios below on an authorized signed candidate and a capable interactive macOS host.

## Manual acceptance matrix

| Scenario | Result | Evidence or blocker |
| --- | --- | --- |
| Native per-app language recognition | `BLOCKED-HOST` | There are 0 active displays. Screen-capture and accessibility preflight both returned `false`, so System Settings and Launch Services UI could not be observed. |
| Safe language-change relaunch with saved and dirty documents | `BLOCKED-HOST` | No interactive display was available, and changing host permissions was not authorized. No app was launched. |
| Real Store sandbox sequence: Open, edit, Save, quit, relaunch, session restore, Open Recent, Save As, external modification, conflict alert, Reload, Print, menu-bar new document | `SKIPPED-AUTHORIZATION` | The scenario requires a signed entitled Store candidate. All signing, including ad-hoc signing, was explicitly prohibited. Candidate path and hash are therefore unavailable. |
| English/German menus, Find/Replace, alerts, About, status, encoding, document type, tooltip, keyboard navigation, VoiceOver, and clipping | `BLOCKED-HOST` | The host has no active display and did not have screen-capture or accessibility trust. No bilingual visual or VoiceOver observation was possible. |
| Reproduce a defect, add RED coverage, implement one fix, rerun affected smoke segment | `NOT TRIGGERED` | No authorized manual scenario reached a product defect. No defect fix or implementation edit was made. |

### Manual totals

| Result | Count |
| --- | ---: |
| `PASS` | 0 |
| `FAIL` | 0 |
| `SKIPPED-AUTHORIZATION` | 1 |
| `BLOCKED-HOST` | 3 |
| `NOT TRIGGERED` | 1 |

## Remaining gates

- Task 10 remains incomplete: its six real English/German screenshots are absent, and the validator correctly fails closed. Screenshot capture is host-blocked under the recorded display and permission state.
- An owner must separately authorize any signing workflow before a signed Store candidate path and hash can exist.
- A capable interactive macOS host must expose a display and the required user-granted accessibility capability before native language, relaunch, bilingual UI, VoiceOver, clipping, Print, and menu-bar scenarios can be observed.
- The complete signed Store sandbox sequence must pass before Task 11 can be accepted.
- Apple-account, notarization, App Store Connect, pricing, upload, review, publication, distribution, and production verification remain outside this record and unresolved.

Until those gates are satisfied, the verified surfaces are limited to the exact-commit remote totals above, the successful local catalog and localization-test checks, and the recorded local host-capability values. Local full-suite and unsigned-preflight passes are not claimed; manual Store acceptance was not performed; merged, distributed, and production-verified states are not claimed.
