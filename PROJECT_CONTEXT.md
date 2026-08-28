# MacPad — Project Context

**Repository:** `anvilfilbert/MacPad`  
**Product:** MacPad for macOS  
**Last verified:** 2026-08-28  

## Purpose

MacPad is the native macOS plain-text editor in the MacPad product family. This
repository owns macOS product behavior, source code, tests, packaging, direct
releases, and macOS-specific distribution preparation.

## Architecture and ownership

- Native AppKit application with reusable Swift core logic.
- Swift Package Manager remains the current build and test foundation on
  `main`.
- Multiple windows and tabs, explicit save behavior, file-format preservation,
  session restoration without storing document text in preferences, and an
  optional menu-bar launcher are macOS-owned behavior.
- MacPad Mobile is a separate codebase. No source, tests, state, tabs, settings,
  or recovery data are automatically shared.
- Website, domain, shared infrastructure, and future shared contracts belong to
  `MacPad-SharedServices` after explicit approval.

## Verified current state

- Default branch `main` was at `59c1e66` during reconciliation.
- README identifies current release `1.3.1`.
- PR #27 was the latest merged product change and restored Dock reopening when
  menu-bar mode keeps the app alive.
- Open issues at reconciliation:
  - #28: prepare MacPad for Mac App Store distribution.
  - #29: localize MacPad in English and German.
  - #30 and #32: duplicate menu-bar icons after update reports.
  - #31: dragging a supported file to MacPad inserts its path instead of opening it.
- Branch `codex/localization-app-store-prep` was four commits ahead of `main`
  with planning and focused test work and no open pull request. It is separate
  active work and must not be modified by portfolio setup tasks.
- README links the current family website at `https://anvilfilbert.github.io/`.

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
- Mac App Store identifiers, signing, certificates, App Store Connect, pricing,
  territories, uploads, notarization, and publication remain explicit owner or
  Apple gates.
- Website migration and `macpad.net` deployment are Shared Services gates, not
  MacPad implementation tasks.
