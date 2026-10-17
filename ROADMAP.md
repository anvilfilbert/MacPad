# MacPad Roadmap

Current implementation and ownership facts are in `PROJECT_CONTEXT.md`.
Issue and PR evidence is authoritative for exact-head acceptance.

## Finish localization and Store foundations

**Status:** Merged; issue #29 closed
**Tracking:** PR #34, issues #28 and #29

All six genuine EN/DE screenshots and their provenance are present and validated.
Merged through PR #34. Preserve the exact-head automated and owner evidence.

Preserve accepted owner tests, including Full Keyboard Access. The Save As
partial-success finding is resolved. Signed Store sandbox/migration and Apple
publication gates remain separate; merging alone does not complete issue #28.

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

The published direct release remains 1.3.1, independently of Store preparation.
The bilingual website is deployed by Shared Services. Website and mailbox
administration remain outside this repository.

The current owner-approved direction is direct Mac distribution, following the
unsuccessful App Review appeal. Preserve the Store/TestFlight evidence in
[App Store preparation](docs/app-store-preparation.md); it is historical evidence,
not a plan to resubmit the Mac application. MacPad Mobile stays in the App Store.

Prepare the branded universal DMG, verify Developer ID signing, notarization,
stapling and Gatekeeper, then verify installation and launch from the downloaded
release. Publish the same final artifact and checksum through GitHub Releases
and update the English/German Mac website pages through Shared Services. Keep
the old release available for rollback and do not replace its assets.

Apple accounts, signing, notarization, Store upload, review, and publication
require explicit owner approvals and evidence. The signed DMG and website release
workflow is approved; creation of signing credentials and other security-sensitive
account changes retain their action-time approval gates. Source visibility and
SourceForge changes are not part of this work.
