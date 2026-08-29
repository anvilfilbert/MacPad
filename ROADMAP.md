# MacPad Roadmap

Statuses used here: `Proposed`, `Approved`, `In progress`, `PR ready`, `Merged`,
`Deployed`, `Verified`, `Paused`, `Rejected`.

## Stable direct-release product

**Status:** Verified through published repository evidence

- Current documented release: `1.3.1`.
- Preserve the universal direct download, packaging verification, checksums,
  provenance, and direct-update path while Store preparation proceeds.

## English/German localization and Mac App Store preparation

**Implementation status:** PR ready for correction and final review  
**Acceptance status:** In progress  
**Tracking:** issues #28 and #29, draft PR #34

Implemented and pushed in PR #34:

- native English/German localization;
- bookmark-backed Store-oriented file access and recent documents;
- separate DirectRelease and AppStore Xcode configurations;
- approved Store entitlements;
- AppIcon assets;
- credential-free unsigned builds and universal archive verification;
- bilingual Store copy, owner-gate documentation, and screenshot validation;
- 148-test automated suite and green current CI/security checks.

Required before a merge recommendation:

- add a regression test and explicit handling for a Save As write that succeeds
  before persistent bookmark creation fails;
- refresh the PR description to show that CodeQL Swift is now successful;
- decide which missing manual checks block merge and which remain explicit
  post-merge/Store-submission gates;
- perform a final exact-head portfolio review.

Still required for full issue acceptance and Store readiness:

- six genuine English/German Store screenshots and a passing validation run;
- real language selection/relaunch, clipping, VoiceOver, Print, and menu-bar
  evidence in an interactive Mac environment;
- owner-authorized signed Store-sandbox and migration evidence;
- permanent public HTTPS routes, production identifier, Store metadata/account,
  legal, pricing, territories, signing, notarization, upload, and publication
  decisions.

Do not close #28 or #29 merely because repository-local code is merged.

## Current bug triage

### Duplicate registration/menu-bar entries

**Status:** Proposed / open  
**Tracking:** issue #30

Issue #32 was closed as a duplicate. Diagnose whether the symptom is caused by
multiple installed application bundles, Launch Services registration, updater
behavior, or multiple status-item instances. Implement only after a focused
reproduction and regression test exist.

### Dragged supported file inserts a path

**Status:** Proposed / open  
**Tracking:** issue #31

Diagnose the drag destination and routing behavior. The accepted behavior should
open supported text files through the normal transactional document flow while
preserving ordinary text and path insertion where the drag payload is not an
accepted file-open request.

Both bugs require isolated branches and must not be folded into PR #34.

## Shared website and `macpad.net`

**Status:** Paused in this repository

The README continues to link `anvilfilbert.github.io`. Website source, future
migration, VPS, Cloudflare, DNS, TLS, and `macpad.net` deployment are coordinated
in `MacPad-SharedServices` and require separate approval.

## External release gates

**Status:** Paused

No production bundle identifier, Team ID, certificate, profile, App Store
Connect record, pricing, territory, upload, review submission, notarization, or
publication action is authorized by this roadmap without a separate explicit
owner approval for that exact action.
