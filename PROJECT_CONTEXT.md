# MacPad — Project Context

**Repository:** `anvilfilbert/MacPad`  
**Product:** MacPad for macOS  
**Last verified:** 2026-08-29  

## Purpose

MacPad is the native macOS plain-text editor in the MacPad product family. This
repository owns macOS product behavior, source code, tests, packaging, direct
releases, and macOS-specific distribution preparation.

## Architecture and ownership

- Native AppKit application with reusable Swift core logic.
- Swift Package Manager remains the direct-release and test foundation.
- A native Xcode application target is being added in draft PR #34 with separate
  DirectRelease and AppStore configurations that reuse the same implementation.
- Multiple windows and tabs, explicit save behavior, file-format preservation,
  session restoration without storing document text in preferences, and the
  optional menu-bar launcher are macOS-owned behavior.
- MacPad Mobile is a separate codebase. No source, tests, state, Tabs, settings,
  or recovery data are automatically shared.
- Website, domain, shared infrastructure, and future shared contracts belong to
  `MacPad-SharedServices` after explicit approval.

## Verified current state

- Latest published direct release remains `1.3.1`.
- The implementation base for draft PR #34 is product commit `59c1e66`.
- Draft PR #34, `Implement English/German localization and Store preparation
  foundations`, is open and mergeable on `codex/localization-app-store-prep`.
- Its exact verified head at reconciliation is `d0488c4`.
- Repository-local implementation in PR #34 includes:
  - English/German native localization and compiled resources;
  - bookmark-backed security-scoped access and Open Recent;
  - sandbox-aware open, save, Save As, reload, and session restoration;
  - DirectRelease and AppStore Xcode configurations;
  - the approved Store sandbox, user-selected read/write, app-scoped bookmark,
    and printing entitlements;
  - deterministic AppIcon assets;
  - credential-free unsigned builds and universal archive preflight;
  - bilingual Store-preparation material and fail-closed screenshot validation.
- Current GitHub checks at `d0488c4` are terminal and successful: Swift CI,
  CodeQL Actions, CodeQL Swift, and code scanning. The recorded full Swift suite
  contains 148 passing tests and the localization contract contains 129 app keys
  plus one Info.plist key for both English and German.
- PR #34 is not acceptance-complete and remains draft. Six genuine bilingual
  Store screenshots and foreground/manual evidence for language relaunch,
  clipping, VoiceOver, Print, menu-bar behavior, and signed Store-sandbox and
  migration behavior remain missing.
- Portfolio review identified a Save As partial-success failure path requiring a
  focused regression test and explicit disposition before merge: the write can
  succeed before persistent bookmark creation, while final UI/session/recent
  state is still pending.
- Open issues:
  - #28: Mac App Store preparation; implementation substantially complete but
    manual, owner, and Apple gates remain.
  - #29: English/German localization; code/resources are implemented but final
    foreground/manual evidence remains.
  - #30: canonical duplicate-registration/menu-bar issue after update.
  - #31: dragging a supported file inserts its path instead of opening it.
- Issue #32 was closed as a duplicate of #30.
- README continues to link the current family website at
  `https://anvilfilbert.github.io/`.

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
- PR #34 must stay draft until the reviewed Save As failure path is resolved or
  proven impossible and the pre-merge versus post-merge manual gates are
  explicit.
- Genuine screenshots and foreground/manual checks require an interactive Mac
  environment; synthetic evidence must not substitute for acceptance.
- Production identifier, customer HTTPS routes, signing, certificates,
  notarization, App Store Connect, pricing, territories, uploads, submission,
  and publication remain explicit owner or Apple gates.
- Website migration and `macpad.net` deployment are Shared Services gates, not
  MacPad implementation tasks.
