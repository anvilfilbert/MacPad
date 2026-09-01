# App Store local smoke evidence

## Status and scope

- This record keeps chronological evidence separate for the 2026-08-29 worker
  attempt, the 2026-08-31 owner foreground baseline, the owner-contract
  correction based on `c8dacb0d37fd7d26ef707b2898ee2e3207a4476f`,
  and the exact-head owner acceptance candidate identified below.
- The 2026-08-29 automated evidence used exact source commit
  `b6198f8510e78e8814edf4b9357e85137aadcb2d` in a clean detached checkout.
- The 2026-08-31 owner baseline used the isolated, locally ad-hoc-signed c8dacb0
  candidate identified below. It did not replace `/Applications/MacPad.app`.
- The exact-head acceptance candidate was built from
  `3f737b99b180f43b0a2018c51e85900cca6c0d2f` and has partial owner foreground
  evidence recorded below.
- Acceptance status: **Task 11 is not accepted.** The remaining exact-runtime
  Full Keyboard Access, two menu-bar screenshots, and signed Store sandbox
  gates remain incomplete.

This record does not claim that MacPad is Developer ID or App Store signed,
notarized, submitted, approved, distributed, or verified in production. No
system permission was changed and no Apple account or distribution service was
accessed.

During the 2026-08-29 worker attempt no app was launched and all signing,
including ad-hoc signing, was outside that attempt's authorization. The later
owner-approved c8dacb0 candidate is separate evidence with its exact path,
identity, hash, and signature scope recorded below.

## Result definitions

| Result | Meaning |
| --- | --- |
| `PASS` | The manual scenario was performed on the required candidate and every listed observation passed. |
| `PARTIAL` | Genuine evidence exists for only part of the required scenario; every unperformed or blocked part remains open. |
| `FAIL` | The manual scenario was performed and at least one required observation failed. |
| `SKIPPED-AUTHORIZATION` | The scenario was not run because it requires an action that was explicitly not authorized. |
| `BLOCKED-HOST` | The scenario was not run because this host lacked the required display or accessibility capability and changing host permissions was not authorized. |
| `NOT TRIGGERED` | The defect-reproduction step was unnecessary because no authorized manual scenario reached a product defect. |

Automated command results use their process exit codes. A passing automated check is evidence only for the behavior that check directly exercises; it is not a manual smoke-test pass.

## Owner foreground baseline — 2026-08-31

This newer baseline supplements, but does not rewrite, the 2026-08-29 worker
record below. The owner launched the isolated DirectRelease acceptance app at
`/private/tmp/MacPad-c8dacb0-OwnerAcceptance.app` from exact source commit
`c8dacb0d37fd7d26ef707b2898ee2e3207a4476f`. Its version/build is `1.3.1 (15)`,
its bundle identifier is `local.macpad.app.acceptance.c8dacb0`, its executable
SHA-256 is `205a30a757e762a1fa2b6fbf2d7ade87c7759f3e200dd157d348729511db8ee4`,
and its signature is local ad-hoc only. The installed `/Applications/MacPad.app`
was not replaced or modified.

| Scenario | Result | Exact owner evidence and scope |
| --- | --- | --- |
| English menus and remaining About presentation | `PASS-WITH-REJECTED-FINDINGS` | The owner inspected every menu and About in English. Native app identity/version/build plus Website, Support, and Privacy presentation passed visually. Creator/GitHub attribution, visible support email/mailto, and Source Code were rejected and must be absent from the next candidate. This does not prove every alert or control. |
| Saved-document relaunch contract | `PASS` | Relaunch opened one new blank document rather than reopening the saved file, and Open Recent contained `Welcome.txt`. This is the owner-approved contract that supersedes saved-session restoration. |
| Website and Privacy dispatch | `PASS` | About Website dispatched exactly to `https://macpad.net`; About Privacy Policy dispatched exactly to `https://macpad.net/privacy`. Live page content remains a Shared Services release gate. |
| Help/Support dispatch | `FAIL` | Help opened `https://github.com/anvilfilbert/MacPad/wiki` instead of `https://macpad.net/support`. The next candidate must remove this customer-facing GitHub dependency. About Support dispatch was not separately credited. |
| Print interaction | `PASS` | File > Print opened the native macOS print panel with preview and controls; the owner cancelled without printing. This proves panel interaction only, not printed output or Store-sandbox behavior. |
| Save As encoding layout | `FAIL` | The Encoding row was pressed against the left edge. Screenshot: `/private/tmp/MacPad-c8dacb0-QA/save-as-encoding-spacing.png`. Encoding selection and saving behavior were not rejected by this layout finding. |
| Find and Replace | `MIXED` | Find-only was too tall with unused lower space (`/private/tmp/MacPad-c8dacb0-QA/find-replace/find-window.png`). Replace proportions and readable alignment passed (`replace-window.png`). The flat Edit menu was observed in `edit-menu.png`; the owner later approved a grouped Find submenu for the next candidate. |
| Go To | `MIXED` | Entering line 2 moved the cursor to line 2. The native alert was too narrow and compressed (`/private/tmp/MacPad-c8dacb0-QA/go-to/go-to-layout.png`). Navigation behavior passed; presentation failed. |
| Dirty quit: Don't Save | `PASS` | Don't Save quit the app and the discarded untitled document did not restore. |
| Dirty quit: Cancel | `PASS` | Cancel aborted quit, kept the document open, and preserved its text unchanged. |
| Dirty quit: Save | `PASS` | Save wrote `/private/tmp/MacPad-c8dacb0-Work/Quit-Save.txt`, then quit. The file is 13 bytes with exact contents `unsaved check` plus newline and SHA-256 `236de01b7693469f410905fcf1f608f146631a04ff518d12c35422fffa7d2ecc`. No MacPad process remained afterward. |

All passes in this table are narrow baseline evidence for c8dacb0. The active
session/About/menu/layout delta requires a new exact-head candidate recheck;
none of these observations is merge, Store, release, or live-site approval.

## Exact-runtime owner foreground evidence — 2026-09-01

The owner used the disposable DirectRelease acceptance app at
`/private/tmp/MacPad-3f737b9-OwnerAcceptance.app`, built from exact source
commit `3f737b99b180f43b0a2018c51e85900cca6c0d2f`. Its version/build is
`1.3.1 (15)`, its bundle identifier is
`local.macpad.app.acceptance.3f737b9`, and its signature is local ad-hoc with
Hardened Runtime and no Team identifier. The executable SHA-256 is
`6945092846b2d8b52bfb6572e0c6c99b03a40f4a510c73656f901199f40cc927`.
It was not installed over `/Applications/MacPad.app`.

This table records only the observations explicitly confirmed by the owner. It
does not infer increased-text or complete keyboard focus-order acceptance,
screenshot acceptance, signed Store sandbox behavior, or production behavior.

| Scenario | Result | Exact owner evidence and scope |
| --- | --- | --- |
| German identity and Save As presentation | `PASS` | The owner saw `Unbenannt - MacPad`. Save As proposed `Unbenannt.txt`, and the German `Codierung:` row with UTF-8 was visibly balanced. This proves the normal-text visual presentation and default filename, not increased-text or complete focus-order acceptance. |
| Clean relaunch and Open Recent | `PASS` | The owner opened the synthetic `/private/tmp/MacPad-3f737b9-OwnerSession/fixtures/de/Welcome.txt`, quit, and relaunched. Exactly one blank `Unbenannt` document opened, while `Welcome.txt` remained available in Open Recent. |
| New Document, New Tab, and New Window placement | `PASS` | New Document created a second tab, Command-T created a third tab, and New Window created a separate blank window. The clean extra documents were then closed. |
| Grouped German Find menu | `PASS` | Edit exposed the localized `Suchen` submenu with `Suchen …`, `Weitersuchen`, `Rückwärts suchen`, and `Ersetzen …`. |
| Find and Replace reuse | `PASS` | The owner exercised Find to Replace to Find reuse. Both German dialog modes were visually balanced and resized correctly during reuse. This proves the observed normal-text reuse and layout, not increased-text or complete focus order. |
| Go To Line | `PASS` | Going to line 2 moved the document status to `Z. 2, Sp. 1`. |
| German 150% editor zoom and clipping | `PASS` | Editor zoom was raised to 150% on `local.macpad.app.acceptance.3f737b9`. Visual and Accessibility inspection passed for the narrow main window and status bar, localized Edit > Suchen submenu, Find-only, Replace, Go To, Save As including the corrected `Codierung:` spacing, and About. All inspected labels and buttons were fully visible and non-overlapping, with stable identifiers and localized labels still present. This clears the increased-editor-text/clipping gate for those exact surfaces; it does not claim macOS Full Keyboard Access traversal or system-wide text scaling. |
| Dirty Save-before-quit | `PASS` | The German dirty prompt showed `Sichern`, `Nicht sichern`, and `Abbrechen`. The owner chose `Sichern` and saved only the synthetic `/private/tmp/MacPad-3f737b9-OwnerSession/Quit-Save.txt`; MacPad quit after saving. Independent proof verified 22 exact bytes, `eins\r\nzwei\r\ndrei\r\nvier`, with SHA-256 `fca194a1d1a13cee3ccc3816a66b90615f80e496cdbac711536a3ba6b0ddecea`. Relaunch then opened one blank German document. This pass exercises the Save path; it does not re-exercise the other two prompt actions. |
| German VoiceOver traversal | `PASS` | The owner listened through the editor and status, Save As, Find-only, Replace, Go To Line, and the About Website, Support, and Privacy controls, then explicitly reported `Desktop VoiceOver PASS`. This proves the genuine German spoken traversal for those controls. It does not prove that any About or Help URL was opened. |
| Physical menu-bar reopen | `PASS` | MacPad's menu-bar option was enabled, the clean last window was closed without quitting, and the owner physically clicked the MacPad menu-bar icon. Exactly one empty `Unbenannt` window opened. This proves the physical menu-bar action and reopen behavior for this candidate. |
| English menu-bar option persistence | `PASS` | In English on the same exact candidate, turning View > Show MacPad in Menu Bar off and closing the clean last window terminated the candidate. After relaunch, turning the option on and closing the clean last window left `local.macpad.app.acceptance.3f737b9` running. The option was restored to on. This proves the observed off/on termination and persistence behavior only; it does not create the required system-chrome screenshots or independently prove another status-item click. |
| German Print open and cancel | `PASS` | The native German Print state opened with `Drucken`; document commands were disabled while the modal state was active. The owner cancelled without printing. This proves exact-candidate Print-panel interaction, not printed output or signed Store-sandbox entitlement behavior. |
| Customer-route dispatch | `PASS` | In the English About panel, Accessibility exposed Website `macpad.net`, Support `macpad.net/support`, and Privacy `macpad.net/privacy`; each was genuinely clicked. Safari observed Website request `https://macpad.net`, Support ending at `https://macpad.net/login`, and Privacy remaining at `https://macpad.net/privacy`. Help > MacPad Help was also genuinely clicked and ended at `https://macpad.net/login`, consistent with the current origin's `/support` redirect. This proves MacPad dispatched its configured Website, Support, Privacy, and Help routes. It does not accept the live site: the root currently serves Learn2Trade, Support redirects to login, and Privacy returns 404, so correct anonymous MacPad pages remain a hard Shared Services release blocker. No form input or transmission occurred, and no browser autofill or account data is recorded here. |
| Bilingual Store screenshot capture | `PARTIAL` | Computer Use supplied four genuine exact-candidate captures: `screenshots/{en,de}/02-editor-tabs.png` and `03-safe-conflict.png` under `/private/tmp/MacPad-3f737b9-OwnerSession`. Each is a 1440x900 opaque RGB PNG with embedded `sRGB IEC61966-2.1`; native Vision OCR and visual review confirmed the expected EN/DE editor-tab and external-change scenes and found no personal data. SHA-256 values are EN 02 `c94fbea72076ccd3806cebdafad9cac7fda5f20ad18df0bb202192ecd6497bef`, EN 03 `52a0a6d8ac73feca71b21d0c6aca54a92e8e1a4eed5e375d6d02621e62183f67`, DE 02 `f4de29cedd7ff4f072431fa9630e97b5e235bb7e1b1e979ca5ceb5ca712481de`, and DE 03 `68d9212b8cfce273ef46efaf4e66d3e195fe724a1f28f82ffaa7d3437f2cedd8`. The genuine captures were center-padded without scaling or app-content alteration. Computer Use intentionally cropped macOS system chrome and could not access SystemUIServer, so EN/DE `01-menu-bar.png` were not captured or fabricated. No six-file validator pass or final screenshot acceptance is claimed. |

No merge, release, distribution signing, installation, upload, publication, or
production action was performed while collecting this evidence.

## Active owner-contract automated evidence — 2026-08-31

The active correction was verified in the named isolated branch worktree based
on c8dacb0. Before the final review delta, a fresh full Swift run passed 155
tests in 11 suites with zero failures. The review then added a termination-policy
test proving that a cancellation on the second dirty document stops before a
third document is prompted; that focused test passed independently.

A post-review aggregate rerun rebuilt successfully but the local Swift test
helper did not launch the test bundle or emit results during a three-minute
bounded wait, so it was interrupted with exit 130. No 156-test aggregate local
pass is claimed. Exact-head GitHub CI must supply the final aggregate result.

The current catalog validator passed 114 `Localizable`, 10 `TechnicalTerms`,
and 1 `InfoPlist` key for English and German. The public-repository scan, shell
syntax checks, and per-file diff checks passed. A new bounded command runner
passed normal-command, timeout, external-interruption, and early-group-leader
exit probes. The timeout paths return exit 124, an interrupted supervisor
returns its conventional signal status, and every recorded leader and child PID
is gone before the runner returns.

The local unsigned Store preflight passed its icon, entitlement, repository,
and localization checks, then its first Direct `xcodebuild` waited without
reaching project parsing or producing build progress for more than five
minutes. It was manually interrupted; `CODE_SIGNING_ALLOWED=NO` was set and no
signing occurred. Each preflight and archive `xcodebuild` invocation is now
fail-closed at 300 seconds and emits its captured log on failure. The complete
local unsigned preflight is not claimed; exact-head CI remains required for the
Direct package and unsigned Store paths.

## Historical automated evidence — 2026-08-29

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
- Open, Save, Save As, one-blank-document relaunch, Open Recent, conflict reload, and bookmark renewal work across a signed sandbox lifecycle;
- printing succeeds with the runtime print entitlement;
- menu-bar-only document creation works in the signed runtime;
- English or German UI text is visually unclipped;
- the signed binary contains and honors the intended runtime entitlements.

Those observations require the manual scenarios below on an authorized signed candidate and a capable interactive macOS host.

## Manual acceptance matrix — 2026-08-29 worker attempt

| Scenario | Result | Evidence or blocker |
| --- | --- | --- |
| Native per-app language recognition | `BLOCKED-HOST` | There are 0 active displays. Screen-capture and accessibility preflight both returned `false`, so System Settings and Launch Services UI could not be observed. |
| Safe language-change relaunch with saved and dirty documents | `BLOCKED-HOST` | No interactive display was available, and changing host permissions was not authorized. No app was launched. |
| Real Store sandbox sequence: Open, edit, Save, quit, relaunch to one blank document, Open Recent, Save As, external modification, conflict alert, Reload, Print, menu-bar new document | `SKIPPED-AUTHORIZATION` | The scenario requires a signed entitled Store candidate. All signing, including ad-hoc signing, was explicitly prohibited in that earlier worker attempt. Candidate path and hash were therefore unavailable. |
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

- Task 10 remains incomplete: four genuine English/German editor-tab and
  conflict screenshots are validated in the isolated owner-session directory,
  but the two system-menu-bar screenshots are absent. The repository's
  six-file validator therefore remains correctly fail-closed.
- The exact-runtime candidate still requires complete macOS Full Keyboard
  Access traversal and the two genuine menu-bar screenshots.
- A capable interactive macOS session with any required user-granted
  Accessibility or Screen Recording permission is required for the remaining
  UI checks. The current Computer Use capture path cannot include macOS system
  chrome or access SystemUIServer, so it cannot produce the two menu-bar files.
- The complete signed Store sandbox sequence requires separate authorization
  and must pass before Task 11 can be accepted.
- Apple-account and Developer Program membership, notarization, App Store
  Connect free-price and storefront entry, final DSA self-assessment, upload,
  review, publication, distribution, and production verification remain
  outside this record and unresolved. The binding cross-project design is
  the authority for the portfolio launch policy and owner gates.

At runtime commit `3f737b99b180f43b0a2018c51e85900cca6c0d2f`, the local Swift suite passed
158 tests in 11 suites, English/German catalog validation passed, and exact-head
Swift CI and CodeQL passed the Direct package and unsigned Store-preflight
scope. Until the remaining gates are satisfied, the verified foreground
surfaces remain limited to the explicitly scoped owner observations above.
Merged, distributed, and production-verified states are not claimed.
