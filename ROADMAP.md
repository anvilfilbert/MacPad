# MacPad Roadmap

Statuses used here: `Proposed`, `Approved`, `In progress`, `PR ready`, `Merged`,
`Deployed`, `Verified`, `Paused`, `Rejected`.

## Stable direct-release product

**Status:** Verified through repository evidence

- Current documented release: `1.3.1`.
- Preserve universal direct download, packaging verification, checksums, and
  release provenance while Store preparation proceeds.

## English/German localization and Mac App Store preparation

**Status:** In progress on `codex/localization-app-store-prep`

Tracked by issues #28 and #29. The active plan keeps one implementation, adds
native localization and a first-class Store archive path, and stops before
owner/Apple external actions.

**Do not fold portfolio-context changes into that branch.**

## Current bug triage

**Status:** Proposed / open

- #30 and #32 appear related to duplicate menu-bar icons after an update.
- #31 requests opening a supported file when dragged onto MacPad rather than
  inserting the file path.

These issues require normal diagnosis, tests, and isolated product pull
requests. The portfolio foundation does not implement them.

## Shared website and `macpad.net`

**Status:** Paused in this repository

The current README continues to link `anvilfilbert.github.io`. Website source,
future migration, VPS, Cloudflare, DNS, and the registered `macpad.net` domain
are coordinated in `MacPad-SharedServices` and require separate approval.

## External release gates

**Status:** Paused

No production bundle identifier, Team ID, certificate, profile, App Store
Connect record, pricing, territory, upload, review submission, notarization, or
publication action is authorized by this roadmap.
