# MacPad — Project Context

**Repository:** `anvilfilbert/MacPad`
**Product:** MacPad for macOS
**Last verified:** 2026-09-05

## Purpose

MacPad is the native macOS plain-text editor in the MacPad product family. This
repository owns macOS product behavior, source code, tests, packaging, direct
releases, and macOS-specific distribution preparation.

## Architecture and ownership

- Native AppKit application with reusable Swift core logic.
- Swift Package Manager remains the direct-release and test foundation.
- A native Xcode application target is implemented in open PR #34 with separate
  DirectRelease and AppStore configurations that reuse the same implementation.
- Multiple windows and tabs, explicit save behavior, file-format preservation,
  one-blank-document relaunch without automatic session restoration, and the
  optional menu-bar launcher are macOS-owned behavior.
- MacPad Mobile is a separate codebase. No source, tests, state, Tabs, settings,
  or recovery data are automatically shared.
- Website, domain, shared infrastructure, and future shared contracts belong to
  `MacPad-SharedServices` after explicit approval.

## Verified current state

- Latest published direct release remains `1.3.1`.
- The implementation base for PR #34 is product commit `59c1e66`.
- PR #34, `Implement English/German localization and Store preparation
  foundations`, is open and mergeable on `codex/localization-app-store-prep`.
- Its exact verified head at reconciliation is `7cf22e9`; it is ready for review,
  not draft, and remains unmerged.
- Repository-local implementation in PR #34 includes:
  - English/German native localization and compiled resources;
  - bookmark-backed security-scoped access and Open Recent;
  - sandbox-aware open, save, Save As, reload, and Open Recent;
  - DirectRelease and AppStore Xcode configurations;
  - the approved Store sandbox, user-selected read/write, app-scoped bookmark,
    and printing entitlements;
  - deterministic AppIcon assets;
  - credential-free unsigned builds and universal archive preflight;
  - bilingual Store-preparation material and fail-closed screenshot validation.
- Exact-head Swift CI and CodeQL passed, including 161/161 tests in CI.
  The Save As partial-success finding is corrected and reviewed.
- Owner foreground evidence, including EN/DE VoiceOver and exact-head Full
  Keyboard Access, is recorded in PR #34 and issues #28/#29. Two genuine EN/DE
  system-menu-bar screenshots and final validation of the complete six-file
  screenshot set remain before final acceptance and merge review.
- Signed Store sandbox/migration proof remains a separate owner gate.
- Issue #30 is closed after verified Launch Services cleanup.
- PR #35 implements issue #31 at `466a236`; the owner verified that dragging
  a text file opens its content instead of inserting its path. It is unmerged
  and requires integration after PR #34, with fresh checks of overlapping code.
- Open issues:
  - #28: Mac App Store preparation; implementation substantially complete but
    manual, owner, and Apple gates remain.
  - #29: English/German localization; code/resources are implemented but final
    foreground/manual evidence remains.
  - #31: dragging a supported file inserts its path instead of opening it.
- Issue #32 was closed as a duplicate of #30.
- The bilingual family website is deployed and verified at `https://macpad.net`.
- Both apps are approved as free hobby tools without monetization. Customer
  About/Help links use the website, `/support`, and `/privacy`; creator,
  repository/source, email, and mailto entries are excluded from About.

## Cross-project rules

- Product capabilities and release facts are canonical here.
- Do not place website, VPS, Cloudflare, DNS, or shared-backend implementation in
  this repository.
- A future shared-service contract requires an approved cross-project design and
  independent compatibility plan.
- Do not modify MacPad Mobile from a MacPad task.
- Do not claim synchronization unless a separately approved feature implements
  and verifies it.

## Approval gates

- Product code and documentation changes merge through reviewed pull requests.
- Preserve accepted owner tests with exact-build provenance. Repeat only when
  a relevant change requires renewed acceptance.
- Genuine screenshots and foreground/manual checks require an interactive Mac
  environment; synthetic evidence must not substitute for acceptance.
- Production identifier, customer HTTPS routes, signing, certificates,
  notarization, App Store Connect, pricing, territories, uploads, submission,
  and publication remain explicit owner or Apple gates.
- Website and infrastructure remain Shared Services responsibilities, not
  MacPad implementation tasks. Website availability is not an app release.
