# MacPad Roadmap

Current implementation and ownership facts are in `PROJECT_CONTEXT.md`.
Issue and PR evidence is authoritative for exact-head acceptance.

## Finish localization and Store foundations

**Status:** Merged; issue #29 closed
**Tracking:** PR #34, issues #28 and #29

All six genuine EN/DE screenshots and their provenance are present and validated.
Merged through PR #34. Preserve the exact-head automated and owner evidence.

Preserve accepted owner tests, including Full Keyboard Access. The Save As
partial-success finding is resolved. Issue #28 is closed because the owner
discontinued Mac App Store distribution; this is not a claim that the historical
Store sandbox/migration or Apple publication gates passed.

## Integrate Finder file opening

**Status:** Merged; issue #31 closed
**Tracking:** PR #35, issue #31

PR #35 is integrated into main. Retain the owner drag PASS at its tested head;
repeat acceptance only when later changes affect that behavior.
Issue #30 is closed after verified cleanup.

## Documentation foundation

**Status:** Merged
**Tracking:** PR #33

Keep portfolio ownership and release gates current without changing runtime
behavior or deployment workflows.

## Signed direct distribution and shared services

**Status:** Released and verified, 2026-10-17
**Tracking:** PR #38 and [MacPad 1.4.0](https://github.com/anvilfilbert/MacPad/releases/tag/v1.4.0)

MacPad 1.4.0 (16) is available as a signed, notarized universal DMG. The bilingual
website links the same release through Shared Services. Website and mailbox
administration remain outside this repository.

The current owner-approved direction is direct Mac distribution, following the
unsuccessful App Review appeal. Preserve the Store/TestFlight evidence in
[App Store preparation](docs/app-store-preparation.md); it is historical evidence,
not a plan to resubmit the Mac application. MacPad Mobile stays in the App Store.

Developer ID signing, notarization, DMG stapling, Gatekeeper, downloaded
installation/launch, owner save/reopen acceptance, public checksum verification
and live English/German download checks passed. Keep the old release and website
rollback available; do not replace historical assets. Future releases need
their own exact-artifact checks and owner approvals.

Apple accounts, signing, notarization, Store upload, review, and publication
require explicit owner approvals and evidence. The signed DMG and website release
workflow is approved; creation of signing credentials and other security-sensitive
account changes retain their action-time approval gates. Source visibility and
SourceForge changes are not part of this work.
