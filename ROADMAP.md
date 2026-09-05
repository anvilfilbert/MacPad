# MacPad Roadmap

Current implementation and ownership facts are in `PROJECT_CONTEXT.md`.
Issue and PR evidence is authoritative for exact-head acceptance.

## Finish localization and Store foundations

**Status:** Implemented; foreground evidence complete; final merge review pending
**Tracking:** PR #34, issues #28 and #29

All six genuine EN/DE screenshots and their provenance are present and validated.
Complete final exact-head automated checks and merge review.

Preserve accepted owner tests, including Full Keyboard Access. The Save As
partial-success finding is resolved. Signed Store sandbox/migration and Apple
publication gates remain separate; merging alone does not complete issue #28.

## Integrate Finder file opening

**Status:** Implemented and owner-tested; integration outstanding
**Tracking:** PR #35, issue #31

After PR #34 merges, merge updated main into PR #35, resolve overlapping editor
changes, and verify combined file-open, save, and localization behavior.
Retain the owner drag PASS at its tested head; assess renewed acceptance only
for behavior affected by integration. Issue #30 is closed after verified cleanup.

## Documentation foundation

**Status:** Merged
**Tracking:** PR #33

Keep portfolio ownership and release gates current without changing runtime
behavior or deployment workflows.

## Distribution and shared services

The published direct release remains 1.3.1, independently of Store preparation.
The bilingual website is deployed by Shared Services. Mailbox follow-up belongs
to its issue #5, not this repository.

Apple accounts, signing, notarization, Store upload, review, and publication
require separate owner approvals and evidence. Source visibility and SourceForge
cutover decisions are not authorized by this roadmap.
