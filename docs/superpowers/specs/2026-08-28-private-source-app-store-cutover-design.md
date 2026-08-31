# Private Source and App Store Distribution Cutover Design

**Status:** Approved by the product owner on 2026-08-31.

**Applies to:** MacPad, MacPad Mobile, the public MacPad website/domain, GitHub source repositories, SourceForge, and the Apple App Store release workflow.

## Decision

MacPad and MacPad Mobile will launch with the Apple App Store as their official binary distribution channel. Their source repositories will become private after all customer-facing links and release infrastructure have been migrated. SourceForge will be retired when the Mac App Store release is confirmed live.

The public product surface will be the owner-controlled domain, not either source repository. It must remain usable without a GitHub, SourceForge, or Apple developer account.

This approval authorizes planning and preparation only. It does not authorize changing repository visibility, deleting SourceForge content, purchasing a domain, enrolling in the Apple Developer Program, accepting Apple agreements, entering Store values, declaring legal status, uploading builds, submitting for review, or publishing an app.

## Portfolio Launch Policy

MacPad and MacPad Mobile will both launch free as privately maintained,
non-commercial hobby projects. This is the canonical portfolio policy for
Store-preparation and cutover work:

- neither app has advertising, subscriptions, in-app purchases, donations,
  paid support, or a paid bundle;
- both Store prices are free;
- storefront availability is deliberately unset until the owner chooses it;
- active Apple Developer Program membership remains required and is an
  owner-funded hobby expense;
- the Paid Apps Agreement and revenue-oriented tax/banking setup are not
  launch requirements for this free, non-monetized model; and
- final EU DSA trader declarations remain owner legal self-assessments and
  must not be inferred from the hobby-project model.

Any future monetization or paid bundle would be a new owner decision and a
new product, legal, metadata, and implementation review. It is not part of
this cutover.

## Target Operating Model

| Surface | Final role | Public? |
| --- | --- | --- |
| Apple App Store | Official MacPad and MacPad Mobile installation and update channel | Yes |
| Product domain | Product information, Help, Support, Privacy, Security, release notes, and Store links | Yes |
| MacPad source repository | Development, issues, CI, tags, and source history for authorized collaborators | No |
| MacPad Mobile source repository | Development, issues, CI, tags, and source history for authorized collaborators | No |
| Website repository | Static public customer website | Yes |
| SourceForge | Retired legacy MacPad distribution surface | No active distribution |

The App Store replaces public GitHub releases and SourceForge for customer delivery. GitHub releases may remain as private engineering artifacts if useful, but they are not customer-facing.

## Public URL Contract

Before either source repository becomes private, the domain project must publish and verify permanent English and German destinations for:

- MacPad product and App Store page;
- MacPad Mobile product and App Store page;
- Help for each app;
- support contact and issue-reporting instructions;
- privacy information for each app;
- security-contact and vulnerability-reporting instructions;
- release notes or an update destination for each app;
- a legacy MacPad migration notice that explains how direct-download users move to the App Store.

The domain project owns the exact hostname and routes. It must record the final mapping in `docs/public-url-contract.md` in the public website repository before application code adopts the URLs. The mapping is a release input, not a runtime configuration service: both apps must continue to work if the website is temporarily unavailable.

Customer-facing pages must not depend on access to a private GitHub repository. Support and security contact details must also remain usable by people without GitHub accounts.

## SourceForge Retirement Semantics

“Shut down SourceForge” means that SourceForge stops being an official or promoted MacPad distribution channel when the Mac App Store version is live. It is a staged retirement rather than an unverified destructive deletion:

1. Capture current project metadata and download statistics and make a private backup of every published file and checksum.
2. Stop synchronization and all new SourceForge uploads.
3. Remove SourceForge links from the apps, website, Store metadata, and public documentation.
4. Verify that the Mac App Store listing, download, first launch, document open/save flow, support page, privacy page, and migration notice work for a customer account.
5. Change the SourceForge project text to a retirement notice pointing to the product domain and Mac App Store, if SourceForge permits this without keeping an active download channel.
6. Disable or remove public downloads only after step 4 passes.
7. Delete the SourceForge project permanently only after a separate explicit owner approval and after confirming the private backup is readable.

If SourceForge cannot present a retirement notice without keeping downloads active, the website migration page becomes the durable notice and the SourceForge downloads are removed after Store verification. A failed or unavailable App Store listing blocks the retirement.

## Legacy Direct-Download Transition

MacPad v1.3.1 and earlier direct builds link customers to public GitHub pages for About, Help, issue reporting, and updates. Making GitHub private would break those destinations for installed copies.

Before repository privacy or SourceForge retirement, MacPad must therefore ship one final direct-transition release unless the current public build can be redirected without changing the binary. That release must:

- replace customer-facing GitHub and SourceForge URLs with the permanent product-domain URLs;
- explain that future installation and updates use the Mac App Store;
- preserve normal document behavior and never force an update;
- use the approved Developer ID-signed and notarized transition-release process;
- avoid presenting GitHub releases or SourceForge as an update channel.

This transition release is not a second long-term distribution channel. It is the bridge that keeps existing installations’ Help, Support, Security, and update guidance functional after the public repositories disappear.

## Repository Privacy Consequences

Changing visibility is scheduled only after the public URL contract and Store cutover are complete.

- Existing clones, downloads, and detached public forks cannot be recalled.
- Apache-2.0 rights already granted for published versions are not revoked by making the repositories private.
- Any license decision for future unpublished versions is a separate owner/legal decision.
- Stars and watchers may be erased and public forks may remain public and detached.
- Public release assets, issues, wiki pages, discussions, and security-reporting routes stop being customer-accessible.
- Private-repository GitHub Actions use the account’s private Actions allowance.
- MacPad’s public-repository artifact-attestation step must be removed, replaced, or explicitly disabled for the private repository according to the account plan.
- Every authenticated clone, push, issue, and CI workflow needed by the project must be smoke-tested after the visibility change.

## Sequenced Gates

The gates are strict and must run in this order:

1. **Feature and localization gate:** finish the in-flight Mobile widget and English/German preparation without changing distribution state.
2. **Domain gate:** select and register the owner-controlled domain, publish the public URL contract, and verify every page anonymously.
3. **Link-migration gate:** replace public GitHub and SourceForge customer links in both apps, the website, metadata, and documentation.
4. **Apple identity and signing gate:** complete Developer Program enrollment, production identifiers, and credential-safe signing preparation.
5. **Legacy-transition gate:** Developer ID sign, notarize, publish, and verify the final MacPad direct-transition release. An ad-hoc signed build is not an acceptable public transition release.
6. **Apple Store preparation gate:** complete App Store Connect records, metadata, screenshots, privacy answers, TestFlight/internal testing, and review preparation.
7. **Owner submission gate:** the owner separately confirms the free Store prices and required tax categories, chooses storefront availability, completes the DSA self-assessments and required Apple agreement state, and approves upload, review submission, and publication.
8. **Production availability gates:** verify each Store listing and production build separately with normal customer accounts. Verified MacPad availability unlocks SourceForge retirement; MacPad Mobile availability is not a SourceForge dependency.
9. **SourceForge retirement gate:** after the MacPad production gate passes, retire the project using the staged procedure above even if MacPad Mobile is still awaiting review.
10. **Repository privacy gates:** make each source repository private only after its own app’s production gate passes, update CI first, and verify authenticated development workflows plus anonymous public pages.
11. **Permanent deletion gate:** only a later explicit owner approval can delete the backed-up SourceForge project or other legacy artifacts.

Failure at any gate stops the cutover. It does not trigger a fallback to silent deletion or a partially private customer experience.

## Coordination Record

The initial decision was delivered on 2026-08-28 to these existing Codex tasks:

| Task | Required handoff |
| --- | --- |
| `MacPadMainChat - 02` | Treat direct distribution as a transition path; migrate customer URLs; prepare private CI; do not change visibility or SourceForge now |
| `MacPad Mobile` | Finish widget #42 without scope expansion; later migrate public-repository URLs and prepare English/German Store distribution |
| `Find available MacPad domains` | Recommend a domain that can host the permanent bilingual public URL contract; do not purchase it |

The implementation plan requires recording non-sensitive delivery dates and receipt evidence in `docs/app-store-cutover-inventory.md`. Internal Codex task identifiers must not be committed to the public repository. A queued message proves delivery, while an explicit response proves acknowledgement. Lack of an acknowledgement blocks an assumption that responsibility transferred; it does not authorize another task to edit that participant’s repository.

## Participant Responsibilities

| Participant | Responsibilities | Must not do without a new owner approval |
| --- | --- | --- |
| MacPad task | English/German and Store preparation; domain-link migration; transition release; direct-update removal from Store build; private-CI adaptation | Change visibility, upload/submit/publish, remove SourceForge |
| MacPad Mobile task | Widget completion; English/German and Store preparation; replace public-repository links with domain URLs | Change visibility, upload/submit/publish |
| Domain task | Recommend a domain; define and implement the public URL contract; English/German public pages and Store/legacy destinations | Purchase/register a domain or publish externally |
| Cross-project coordination task | Maintain this decision and execution plan; verify dependencies and handoffs | Perform owner-gated external actions |
| Product owner | Domain purchase, Apple enrollment and required agreements, final identifiers, free-price/tax-category entry, storefront availability, DSA declarations, submissions, publication, SourceForge retirement/deletion, and repository visibility approvals | None; each irreversible/external action remains an explicit gate |

## Definition of Done

The cutover is complete only when:

- both production apps are live and downloadable from the App Store;
- both Store listings are free and neither app exposes a monetization path outside the portfolio launch policy;
- English and German listings and customer-visible app interfaces have passed review;
- every public Help, Support, Privacy, Security, release-note, and migration URL works anonymously;
- neither app nor the public website sends customers to a private repository or SourceForge;
- SourceForge is no longer an active download channel and its backup is verified;
- both source repositories are private and their required authenticated workflows pass;
- existing direct MacPad users have a functioning migration path;
- the final state and remaining owner-held credentials are documented without storing secrets in any repository.
