# MacPad — Project Context

**Repository:** `anvilfilbert/MacPad`
**Product:** MacPad for macOS
**Last verified:** 2026-10-17

## Purpose

MacPad is the native macOS plain-text editor in the MacPad product family. This
repository owns macOS product behavior, source code, tests, packaging, direct
releases, and macOS-specific distribution preparation.

## Architecture and ownership

- Native AppKit application with reusable Swift core logic.
- Swift Package Manager remains the direct-release and test foundation.
- A native Xcode application target is merged through PR #34 with separate
  DirectRelease and AppStore configurations that reuse the same implementation.
- Multiple windows and tabs, explicit save behavior, file-format preservation,
  one-blank-document relaunch without automatic session restoration, and the
  optional menu-bar launcher are macOS-owned behavior.
- MacPad Mobile is a separate codebase. No source, tests, state, Tabs, settings,
  or recovery data are automatically shared.
- Website, domain, shared infrastructure, and future shared contracts belong to
  `MacPad-SharedServices` after explicit approval.

## Verified current state

- The macOS App Review appeal was unsuccessful. The owner has chosen direct
  distribution for the Mac application instead of further App Store submissions.
  MacPad Mobile remains independently distributed through the App Store.
- [MacPad 1.4.0 (16)](https://github.com/anvilfilbert/MacPad/releases/tag/v1.4.0)
  is published from merged source `6cb8f138def2c2a916daed90633e0e69ccb9998f`.
  Its charcoal/cyan drag-to-Applications DMG contains a universal Apple Silicon
  and Intel app for macOS 14 or later. App and DMG are Developer ID-signed;
  Apple notarization was accepted and the ticket is stapled to the DMG.
- Strict signature, stapler, Gatekeeper, downloaded installation and launch
  checks passed. The owner confirmed typing, saving and reopening a test file.
  The public DMG and checksum match the tested final artifact byte-for-byte.
  Release notes contain the exact SHA-256 and installation instructions.
- The English/German macpad.net download pages offer the same versioned DMG,
  checksum and release notes. Shared Services activated its separately approved
  exact candidate `da49ca088fd73b9db314c51d378bc0c9de9ffec4`; all 12 public routes
  and website-linked anonymous downloads passed verification. See PR #38 for
  app release evidence. Mobile and other hosted services were unchanged.
- The existing unsigned/ad-hoc build and ZIP preflight remain separate from the
  new DMG tooling. The legacy workflow is manual and read-only; version tags do
  not rebuild or publish ad-hoc ZIPs. Usage and publication gates are in the docstrings
  of `scripts/package-dmg.py`, `scripts/verify-developer-id.py`, and
  `scripts/notarize-dmg.py`.

- The legacy `v1.3.1` tag and ad-hoc-signed ZIP assets remain unchanged. They are
  not Apple-notarized and are not the current recommended download.
- PR #34 merged at `4c4da538`; PR #35 merged at `330189263`.
- Merged repository-local implementation includes:
  - English/German native localization and compiled resources;
  - bookmark-backed security-scoped access and Open Recent;
  - sandbox-aware open, save, Save As, reload, and Open Recent;
  - DirectRelease and AppStore Xcode configurations;
  - the approved Store sandbox, user-selected read/write, app-scoped bookmark,
    and printing entitlements;
  - deterministic AppIcon assets;
  - credential-free unsigned builds and universal archive preflight;
  - bilingual Store-preparation material and fail-closed screenshot validation.
- Automated acceptance and the corrected Save As partial-success finding are
  recorded in the merged PRs. Verification results belong to their exact heads.
- Owner foreground evidence, including EN/DE VoiceOver and exact-head Full
  Keyboard Access, is recorded in PR #34 and issues #28/#29. All six genuine
  EN/DE screenshots passed final validation. See
  `docs/verification/app-store-local-smoke.md` for provenance.
- Signed Store sandbox/migration proof was not completed; it is historical
  Store work, not a remaining gate for the released direct DMG.
- Issue #30 is closed after verified Launch Services cleanup.
- PR #35 implements issue #31; the owner verified that dragging a text file
  opens its content instead of inserting its path. Integration is merged.
- Issue #28 is closed following the owner's decision to discontinue Mac App
  Store distribution and provide direct downloads instead.
- Issues #29 and #31 are closed.
- The owner-approved production bundle identifier is `com.anvilfilbert.MacPad`.
  The uploaded candidate was built from `330189263` plus the five identifier
  substitutions now preserved in source, packaging checks, and the existing test.
- Historical Apple-connected validation, upload, and beta review milestones are
  recorded in [App Store preparation](docs/app-store-preparation.md). Those dated
  Store records do not supersede the current direct-release status above.
- MacPad `1.3.1 (15)` was approved for external TestFlight testing. The owner
  confirmed installation, launch, and a basic create, save, and reopen smoke
  test on a Mac. This is historical acceptance, separate from the DMG acceptance;
  public testing is closed and no public Mac App Store release is claimed.
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
