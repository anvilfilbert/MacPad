# Private Source and App Store Distribution Cutover Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Move MacPad and MacPad Mobile to an App Store-first free, non-commercial hobby release while keeping customer support intact, retiring SourceForge safely, and making both source repositories private only after all public dependencies have moved to the product domain.

**Architecture:** Treat distribution as a gated cross-project cutover. The public website owns stable customer URLs; Store builds own installation and updates; private GitHub repositories own engineering only. A final MacPad direct-transition release bridges installed legacy copies before public GitHub and SourceForge disappear. Every external or irreversible action remains an explicit product-owner gate.

**Tech Stack:** Swift 6.3, AppKit, SwiftUI/UIKit, WidgetKit, Xcode 26.6, Xcode String Catalogs, GitHub Actions and CLI, a static public website, Apple Developer/App Store Connect, and SourceForge project administration.

**Spec:** [`docs/superpowers/specs/2026-08-28-private-source-app-store-cutover-design.md`](../specs/2026-08-28-private-source-app-store-cutover-design.md)

## Global Constraints

- Execute the tasks and gates in order. Do not privatize a repository or retire SourceForge early.
- Apply the binding design's portfolio launch policy to both apps. Do not add advertising, subscriptions, in-app purchases, donations, paid support, a paid bundle, or another monetization path in cutover work.
- Do not purchase a domain, enroll an Apple account, accept agreements, enter free-price/tax-category values, choose storefront availability, declare DSA status, upload, submit, publish, change repository visibility, remove public files, or delete a project without a separate explicit owner approval for that action.
- Work in the named repository for each task and never mix MacPad and MacPad Mobile commits.
- Preserve unrelated changes and active worktrees. Finish or coordinate the in-flight Mobile widget and Mac localization work before touching overlapping files.
- English is the source language and German is the only additional launch language.
- Use one owner-controlled domain for anonymous Help, Support, Privacy, Security, release notes, Store links, and the legacy migration notice.
- Do not expose source-repository URLs in customer-visible Store builds, website navigation, Store metadata, or support instructions.
- Do not store Apple credentials, signing identities, provisioning profiles, API keys, account identifiers, SourceForge credentials, or domain-provider credentials in a repository.
- Preserve an offline, checksum-verified backup before removing any public artifact.
- Treat existing Apache-2.0 copies and detached forks as already distributed; repository privacy does not revoke them.
- Use focused commits and non-interactive verification commands. Never force-push.

## Project Boundaries

| Project | Repository root | Primary scope |
| --- | --- | --- |
| MacPad | `.` | Desktop app, direct-transition release, Mac Store build, Mac CI |
| MacPad Mobile | `../PhonePad` | Mobile app, widget, Mobile Store build, Mobile CI |
| Public website | `../anvilfilbert.github.io` | Domain URL contract, public pages, Store links, legacy notice |

File paths in the **Files** lists are relative to the MacPad repository root. Command blocks run from the repository owned by that task: Task 2 commands run from `../anvilfilbert.github.io`, Task 4 commands run from `../PhonePad`, and MacPad or cross-project commands run from `.` unless the step says otherwise. Before executing a task, run `git -C . rev-parse --show-toplevel`, `git -C ../PhonePad rev-parse --show-toplevel`, and `git -C ../anvilfilbert.github.io rev-parse --show-toplevel`; stop if any resolves to a different repository.

The SourceForge and Apple surfaces are external. Their mutation steps are owner-gated even when all repository work is complete.

---

### Task 1: Freeze the verified cross-project baseline

**Files:**
- Create: `./docs/app-store-cutover-inventory.md`
- Read: `./Sources/NotepadMac/AppDelegate.swift`
- Read: `./Sources/NotepadMac/MainMenuFactory.swift`
- Read: `./README.md`
- Read: `./.github/workflows/release.yml`
- Read: `../PhonePad/README.md`
- Read: `../PhonePad/SUPPORT.md`
- Read: `../PhonePad/SECURITY.md`
- Create: `../PhonePad/docs/superpowers/plans/2026-08-28-macpad-mobile-en-de-app-store-preparation.md`
- Read: `../anvilfilbert.github.io/index.html`
- Read: `../anvilfilbert.github.io/scripts/validate-site.sh`

**Interfaces:**
- Consumes: current public URLs, release processes, licenses, Store-preparation branches, active issues, SourceForge metadata, and GitHub visibility/Actions settings.
- Produces: one dated inventory with a disposition for every public dependency and an owner-gate ledger.

- [ ] **Step 1: Record and verify the cross-task handoff**

In `docs/app-store-cutover-inventory.md`, record the non-sensitive delivery date, authoritative design and plan paths, exact task title, and delivery/acknowledgement evidence for `MacPadMainChat - 02`, `MacPad Mobile`, and `Find available MacPad domains`. Do not commit internal Codex task identifiers. Re-send the authoritative paths to any task that received only the preliminary decision. Do not treat a queued-but-unacknowledged handoff as permission to edit that task’s repository.

- [ ] **Step 2: Finish or pause active overlapping work cleanly**

Record the branch, HEAD, worktree status, and owner for the MacPad localization task and Mobile widget task. Do not continue until overlapping edits are committed or the owning task confirms which files are safe.

- [ ] **Step 3: Create the missing Mobile preparation plan**

The `MacPad Mobile` task must use the writing-plans workflow to create `../PhonePad/docs/superpowers/plans/2026-08-28-macpad-mobile-en-de-app-store-preparation.md`. It must cover complete English/German app and Store localization, native per-app language selection, App Store signing and metadata preparation, the binding free/non-monetized portfolio launch policy, and the public-domain/private-source decisions in the design. Commit the plan in the Mobile repository before Task 4 implementation begins.

- [ ] **Step 4: Inventory repository and website links**

Run read-only searches in all three repositories:

```bash
rg -n "github\.com/anvilfilbert/(MacPad|MacPad-Mobile)|sourceforge|Public repo|Check for Updates|Report Issue|wiki|releases/latest" \
  . \
  ../PhonePad \
  ../anvilfilbert.github.io
```

Classify every match as engineering-only, customer-facing, historical evidence, or removable. Record the exact replacement owner for every customer-facing match.

- [ ] **Step 5: Capture external state without mutation**

Record, with timestamps, both repositories’ visibility, default branch, open issues and pull requests, Actions status, releases, tags, forks, stars, watchers, and recent traffic. Record SourceForge project metadata, files, checksums, download totals, homepage, support link, and synchronization path. Never copy authentication data into the inventory.

- [ ] **Step 6: Record the owner-gate ledger**

Create an unchecked ledger for domain purchase, Apple enrollment and required agreement state, production bundle identifiers, free-price/tax-category entry, storefront availability, DSA declarations, uploads, submissions, publication, SourceForge retirement, repository visibility changes, and permanent deletion. Each gate records the owner decision date and evidence only after the decision occurs.

- [ ] **Step 7: Verify the inventory is complete**

```bash
rg -n "github\.com/anvilfilbert/(MacPad|MacPad-Mobile)|sourceforge" \
  . \
  ../PhonePad \
  ../anvilfilbert.github.io
```

Every result must appear in `docs/app-store-cutover-inventory.md` or be explicitly categorized as build/history-only.

- [ ] **Step 8: Commit the MacPad inventory**

```bash
git add docs/app-store-cutover-inventory.md
git commit -m "docs: inventory App Store cutover dependencies"
```

### Task 2: Publish the permanent English/German public URL contract

**Files:**
- Create: `../anvilfilbert.github.io/docs/public-url-contract.md`
- Modify: `../anvilfilbert.github.io/index.html`
- Modify: `../anvilfilbert.github.io/styles.css`
- Modify: `../anvilfilbert.github.io/scripts/validate-site.sh`
- Modify: `../anvilfilbert.github.io/README.md`
- Create: `../anvilfilbert.github.io/en/macpad/index.html`
- Create: `../anvilfilbert.github.io/de/macpad/index.html`
- Create: `../anvilfilbert.github.io/en/macpad-mobile/index.html`
- Create: `../anvilfilbert.github.io/de/macpad-mobile/index.html`
- Create: `../anvilfilbert.github.io/en/help/index.html`
- Create: `../anvilfilbert.github.io/de/help/index.html`
- Create: `../anvilfilbert.github.io/en/support/index.html`
- Create: `../anvilfilbert.github.io/de/support/index.html`
- Create: `../anvilfilbert.github.io/en/privacy/index.html`
- Create: `../anvilfilbert.github.io/de/privacy/index.html`
- Create: `../anvilfilbert.github.io/en/security/index.html`
- Create: `../anvilfilbert.github.io/de/security/index.html`
- Create: `../anvilfilbert.github.io/en/updates/index.html`
- Create: `../anvilfilbert.github.io/de/updates/index.html`
- Create: `../anvilfilbert.github.io/en/macpad-migration/index.html`
- Create: `../anvilfilbert.github.io/de/macpad-migration/index.html`
- Create after domain approval: `../anvilfilbert.github.io/CNAME`

**Interfaces:**
- Consumes: the owner-approved domain and final App Store URLs when Apple creates them.
- Produces: anonymous English/German product, Help, Support, Privacy, Security, release-note, Store-link, and legacy-migration destinations.

- [ ] **Step 1: Complete the domain owner gate**

Present the domain recommendation, registration term, renewal price, registrar, and DNS/hosting impact. Stop until the owner explicitly authorizes purchase and completes any identity/payment step.

- [ ] **Step 2: Write the URL contract before changing navigation**

Use the language-prefixed routes listed above. The shared Help, Support, Privacy, Security, and Updates pages must have separate, clearly labelled MacPad and MacPad Mobile sections. Record locale behavior, canonical URLs, redirect rules, and the owner of each page. Root navigation must offer English and German explicitly. Record the exact owner-approved hostname in `CNAME`; never commit a fake hostname. The contract must include neutral fallback URLs that remain valid when opened by an older app version.

- [ ] **Step 3: Add validation before pages**

Extend `scripts/validate-site.sh` to fail when a required route, `lang` declaration, reciprocal language link, privacy page, security contact, support contact, release destination, or legacy migration page is missing. It must also fail when customer navigation contains a private-source GitHub URL or SourceForge URL.

- [ ] **Step 4: Verify the validator fails for the current site**

```bash
./scripts/validate-site.sh
```

Expected: failure naming the first missing URL-contract route or forbidden customer link.

- [ ] **Step 5: Implement the public pages and navigation**

Add concise English and German pages using the approved product positioning: exceptional launch speed, immediate plain-text editing, Mac menu-bar access, and the Mobile one-tap new-text widget. State privacy behavior factually from verified code. Do not promise iCloud sync, restoration, telemetry behavior, or Store availability unless implemented and verified.

- [ ] **Step 6: Add provisional Store destinations safely**

Before Store URLs exist, product pages may state that the App Store release is being prepared but must not use dead buttons. After Apple creates final public URLs, replace that state in one focused commit and validate every link anonymously.

- [ ] **Step 7: Verify the website**

```bash
./scripts/validate-site.sh
```

Expected: zero failures, no customer-facing private-source or SourceForge links, and all required English/German routes present.

- [ ] **Step 8: Commit and publish only after owner approval**

```bash
git add README.md index.html styles.css scripts/validate-site.sh docs/public-url-contract.md CNAME
git add en/macpad/index.html de/macpad/index.html en/macpad-mobile/index.html de/macpad-mobile/index.html
git add en/help/index.html de/help/index.html en/support/index.html de/support/index.html
git add en/privacy/index.html de/privacy/index.html en/security/index.html de/security/index.html
git add en/updates/index.html de/updates/index.html en/macpad-migration/index.html de/macpad-migration/index.html
git commit -m "feat: add public App Store support routes"
```

Push and publish the public site only after the owner approves the chosen domain and content.

### Task 3: Migrate MacPad customer links and create the direct-transition release

**Files:**
- Modify: `./Sources/NotepadMac/AppDelegate.swift`
- Modify: `./Sources/NotepadMac/MainMenuFactory.swift`
- Modify: `./Sources/NotepadMac/DistributionChannel.swift`
- Modify: `./Tests/NotepadMacTests/DistributionChannelTests.swift`
- Modify: `./README.md`
- Modify: `./SECURITY.md`
- Modify: `./.github/workflows/release.yml`
- Create: `./scripts/build-notarized-transition-release.sh`
- Create: `./scripts/verify-notarized-transition-release.sh`
- Modify or create only the localization, distribution-channel, and test files defined by `docs/superpowers/plans/2026-08-28-macpad-en-de-app-store-preparation.md`.

**Interfaces:**
- Consumes: exact final URLs from the website’s `docs/public-url-contract.md`.
- Produces: Store-safe customer links and one exact, credential-safe mechanism for building and verifying a Developer ID-signed, notarized transition release without a tag-triggered workflow rebuilding or replacing it.

- [ ] **Step 1: Finish the MacPad English/German and Store-preparation plan**

Complete and verify the existing MacPad plan through its credential-free gates. Do not preserve its earlier long-term direct-download assumption: this cross-project decision supersedes that assumption after the transition release.

- [ ] **Step 2: Add channel-specific link tests**

Add tests that inspect the resolved About, Help, Support/Issue, Privacy, Security, and Update destinations for the direct-transition and App Store configurations. Expected Store behavior: every customer destination uses the public domain or Apple; no destination uses GitHub or SourceForge.

- [ ] **Step 3: Verify the tests fail against current URLs**

Run the focused distribution-channel test command defined by the MacPad Store-preparation work. Expected: failures identify the current GitHub Help, Issue, or Update destination.

- [ ] **Step 4: Replace the in-app destinations**

Use typed channel configuration and URL constants, not duplicated string literals. The final direct-transition build opens the public migration/update page. The App Store build always omits direct-update UI because the App Store is the approved installation and update channel. Both channels use the public domain for Help, Support, Privacy, and Security.

- [ ] **Step 5: Replace automatic tag publication with explicit signed-release tooling**

Change `.github/workflows/release.yml` into a non-publishing direct-package verification workflow: remove the `push.tags` trigger, release-tag input, write permissions, artifact-attestation step, and `gh release` publication. Keep tests and package verification and upload only an Actions workflow artifact for engineering inspection. A pushed tag must have no automatic publication side effect.

Create `scripts/build-notarized-transition-release.sh` with explicit arguments for the immutable source commit, version, Developer ID Application identity, `notarytool` Keychain profile, and output directory. It must build from a clean worktree, sign the `.app`, create the notarization submission ZIP, wait for Apple’s result, staple the accepted ticket to the `.app`, recreate the final ZIP, and write its SHA-256. Credentials stay in the local Keychain and are never printed or written to the repository.

Create `scripts/verify-notarized-transition-release.sh` with explicit app, ZIP, checksum, version, and expected-commit arguments. It must fail unless `codesign --verify --deep --strict`, `spctl --assess --type execute`, `xcrun stapler validate`, version/commit provenance, archive contents, and SHA-256 all pass.

- [ ] **Step 6: Remove public-distribution claims from documentation**

Replace the README’s GitHub canonical-download and synchronized-SourceForge instructions with developer-only build instructions and a customer link to the public product page. Keep source license and engineering history accurate.

- [ ] **Step 7: Verify app and release-path behavior**

Run the MacPad test suite, localization validation, direct universal build, App Store preflight, link validation, shell validation for both new release scripts, and a real manual smoke test for launch, menu-bar access, open, edit, save, Help, Support, and migration/update behavior. Confirm that pushing a disposable local tag does not match any GitHub Actions tag-publish trigger; delete only that local disposable tag after the check.

- [ ] **Step 8: Commit the verified MacPad migration**

```bash
git add Sources/NotepadMac/AppDelegate.swift Sources/NotepadMac/MainMenuFactory.swift Sources/NotepadMac/DistributionChannel.swift
git add Tests/NotepadMacTests/DistributionChannelTests.swift README.md SECURITY.md .github/workflows/release.yml
git add scripts/build-notarized-transition-release.sh scripts/verify-notarized-transition-release.sh
git commit -m "feat: migrate MacPad to App Store distribution"
```

- [ ] **Step 9: Review, push, and merge the migration**

Review the exact commit range, push the focused branch, let required CI pass, and merge through the repository’s protected-branch workflow. Record the immutable merged commit SHA. Do not tag or publish from an uncommitted working tree or an unmerged feature branch.

- [ ] **Step 10: Record the immutable release input**

Record the merged commit, version, release notes, migration wording, and exact signing/verification commands. Do not create or push the release tag yet, and do not publish an ad-hoc signed build. Task 5 builds and notarizes from this immutable input only after the Apple identity/signing gate passes.

### Task 4: Migrate MacPad Mobile customer links

**Files:**
- Modify: `../PhonePad/PhonePad/PhonePadAboutSheet.swift`
- Modify: `../PhonePad/PhonePad/Localizable.xcstrings`
- Modify: `../PhonePad/PhonePadUITests/PhonePadLaunchUITests.swift`
- Modify: `../PhonePad/README.md`
- Modify: `../PhonePad/SUPPORT.md`
- Modify: `../PhonePad/SECURITY.md`
- Create: `../PhonePad/docs/adr/0016-app-store-private-source-distribution.md`
- Create or modify: `../PhonePad/docs/app-store-preparation.md`
- Read and execute: `../PhonePad/docs/superpowers/plans/2026-08-28-macpad-mobile-en-de-app-store-preparation.md`

**Interfaces:**
- Consumes: exact Mobile URLs from the website’s `docs/public-url-contract.md`.
- Produces: Mobile Store UI and documentation with no customer dependency on the private source repository.

- [ ] **Step 1: Finish and merge the one-tap new-text widget**

Complete issue #42 in its isolated worktree, run its approved verification, and merge it without mixing distribution changes into the widget commits.

- [ ] **Step 2: Verify and adopt the Mobile preparation plan**

Confirm that `../PhonePad/docs/superpowers/plans/2026-08-28-macpad-mobile-en-de-app-store-preparation.md` exists, is committed, and incorporates this cross-project design. Stop if it is missing or still assumes a public source repository.

- [ ] **Step 3: Finish the Mobile English/German and Store-preparation plan**

Localize all customer-visible About/settings strings and Store metadata. Preserve native per-app language selection; do not add a custom in-app language picker unless the approved Mobile plan explicitly requires one.

- [ ] **Step 4: Add failing destination checks**

Add a focused test or repository validation that fails when customer-facing UI, Store metadata, README, support, or security instructions reference the private-bound GitHub repository or SourceForge.

- [ ] **Step 5: Replace customer-facing repository links**

Replace “Public repo,” local-Xcode installation, issue, support, and security destinations with the approved public domain and App Store destinations. Engineering-only remote URLs may remain in Git configuration and contributor documentation.

- [ ] **Step 6: Verify Mobile behavior**

Run the Mobile test suite, localization validator, archive/preflight checks, and real-device or Simulator smoke tests for normal launch, the widget deep link, empty-document focus, About/settings links, Help, Support, and privacy access.

- [ ] **Step 7: Commit the Mobile migration**

```bash
git add PhonePad/PhonePadAboutSheet.swift PhonePad/Localizable.xcstrings PhonePadUITests/PhonePadLaunchUITests.swift
git add README.md SUPPORT.md SECURITY.md docs/adr/0016-app-store-private-source-distribution.md docs/app-store-preparation.md
git commit -m "feat: migrate MacPad Mobile to App Store distribution"
```

The staged path list must come directly from the verified inventory; do not use `git add .`.

- [ ] **Step 8: Review, push, merge, and pin Mobile**

Review the exact Mobile commit range, push its focused branch, let required unit and UI CI pass, and merge through the repository’s protected-branch workflow. Record the immutable merged commit SHA in `docs/app-store-preparation.md`. Task 5 must archive and upload only from a clean worktree at this recorded SHA, never from the original dirty checkout or an unmerged feature branch.

### Task 5: Complete Apple preparation and production validation

**Files:**
- Modify: `./docs/app-store-preparation.md`
- Modify: `../PhonePad/docs/app-store-preparation.md`
- Modify: `../PhonePad/Config/Base.xcconfig`
- Modify: `../PhonePad/Config/PhonePad.xcconfig`
- Modify: `../PhonePad/Config/Release.xcconfig`
- Modify: `../PhonePad/Config/PhonePad-Info.plist`
- Modify: `../PhonePad/PhonePad.xcodeproj/project.pbxproj`
- Modify: `../PhonePad/PhonePad/Localizable.xcstrings`
- Modify: `../PhonePad/PhonePad/PrivacyInfo.xcprivacy`
- Verify: `../PhonePad/PhonePad/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Modify only the credential-free MacPad Xcode configuration, entitlement, privacy-manifest, metadata, and screenshot files enumerated by its existing Store-preparation plan.

**Interfaces:**
- Consumes: owner Apple account, approved identifiers, signing access, confirmed free-price/tax-category entries, owner-chosen storefront availability, DSA declarations, privacy answers, screenshots, and final public URLs.
- Produces: reviewed production listings and production builds for both apps.

- [ ] **Step 1: Complete the Apple account owner gate**

Guide the owner through Developer Program enrollment, identity, and required agreement-status checks without requesting credentials or storing account data. Record only non-sensitive completion evidence. Do not add the Paid Apps Agreement or revenue-oriented tax/banking setup as launch requirements for the binding free, non-monetized model.

- [ ] **Step 2: Approve immutable product decisions**

Present the final bundle identifiers, display names, SKUs, categories, age ratings, free-price/tax-category entries, storefront availability, DSA declarations, privacy answers, and support/privacy URLs. Storefront availability has no repository recommendation; stop until the owner chooses it and approves the remaining values.

- [ ] **Step 3: Create App Store Connect records after approval**

The owner or an explicitly authorized operator creates both app records. Do not submit, publish, or enter the live free-price/tax-category or storefront values merely because the records exist.

- [ ] **Step 4: Produce and validate signed candidates**

Record the immutable merged MacPad and Mobile commit SHAs. From a clean MacPad worktree at its recorded SHA, run `scripts/build-notarized-transition-release.sh` with every required argument, then run `scripts/verify-notarized-transition-release.sh` against its app, ZIP, checksum, version, and commit. Separately archive both App Store candidates from clean worktrees at their recorded SHAs with the approved team, production identifiers, and App Store distribution signing. Verify signatures, notarization, entitlements, architectures, privacy manifests, sandboxed open/save behavior, printing where applicable, widget deep links, and absence of forbidden direct-update behavior. The Mobile App Store build is Apple-distribution signed; there is no direct Mobile binary channel.

- [ ] **Step 5: Publish the final direct-transition release only after approval**

Show the owner the exact version, immutable source commit, Developer ID identity summary, notarization result, stapled artifact checksum, release notes, migration wording, and verification results. Stop until the owner explicitly approves publication. Create and push an annotated version tag pointing to that exact merged commit; the adapted workflow must perform no publication. Create the GitHub release explicitly from the already verified ZIP and checksum with `gh release create --verify-tag`, then download both assets again and compare their SHA-256 to the approved values. Install the downloaded artifact on a clean Mac and verify every domain link. Never rebuild, replace, or `--clobber` the approved asset after publication.

- [ ] **Step 6: Complete English/German metadata and screenshots**

Validate real-app screenshots and localized names, subtitles, descriptions, keywords, release notes, privacy/support URLs, and review notes. Every claimed feature must exist in the submitted binary.

- [ ] **Step 7: Test through Apple’s pre-production channel**

Upload only after explicit approval. Complete TestFlight/internal or equivalent Apple validation with non-developer customer accounts and record install, update, launch, document, widget, link, and language results.

- [ ] **Step 8: Submit and publish only at separate owner gates**

Submission for review and production publication are two separate external actions. Show the exact build, metadata, confirmed free price and tax category, owner-chosen storefront availability, DSA status, release mode, and validation evidence before each approval.

### Task 6: Verify the live MacPad Store cutover before retiring SourceForge

**Files:**
- Modify: `./docs/app-store-cutover-inventory.md`
- Modify: `../anvilfilbert.github.io/docs/public-url-contract.md`

**Interfaces:**
- Consumes: the production MacPad App Store listing and build, plus the independently tracked MacPad Mobile production status.
- Produces: a signed-off MacPad cutover checklist that permits SourceForge retirement. MacPad Mobile remains a separate production gate for its own repository privacy.

- [ ] **Step 1: Verify production listings anonymously**

From signed-out web sessions and normal customer Apple accounts, verify the MacPad Store page, English/German metadata, free price, owner-chosen storefront availability, support URL, privacy URL, screenshots, and download availability.

- [ ] **Step 2: Verify clean installs and upgrades**

Install the production MacPad app from the Store on a supported clean Mac. Verify first launch, document creation/open/edit/save, menu-bar access, language selection, relaunch, and Store-managed update behavior.

- [ ] **Step 3: Verify every public route**

Run the website validator and manually open every Help, Support, Privacy, Security, release, Store, and legacy-migration route without GitHub authentication.

- [ ] **Step 4: Verify the legacy MacPad bridge**

Install the final direct-transition release, use its update/help path, and confirm it guides the user to the correct public migration page and Mac App Store listing without a private-repository error.

- [ ] **Step 5: Obtain the cutover approval**

Present the complete evidence and exact SourceForge/repository actions. Stop until the owner explicitly approves SourceForge retirement and repository privacy. Approval to publish the apps does not imply this approval.

- [ ] **Step 6: Record MacPad Mobile production status separately**

Record whether MacPad Mobile is pending review or independently live. A pending Mobile review does not block SourceForge retirement because SourceForge distributes only MacPad. It does block changing `anvilfilbert/MacPad-Mobile` to private until the Mobile production listing and public routes have their own equivalent verification.

### Task 7: Retire SourceForge with a verified backup

**Files:**
- Modify: `./docs/app-store-cutover-inventory.md`
- Store the SourceForge backup outside all public repositories in an owner-approved private location.

**Interfaces:**
- Consumes: the verified live MacPad Store gate, explicit retirement approval, and SourceForge administrator access for project `macpad-editor`.
- Produces: no active SourceForge distribution, a working migration destination, and a verified private backup.

- [ ] **Step 1: Export before mutation**

Download every SourceForge release file and checksum, capture project metadata and statistics, and record a manifest. Verify every downloaded checksum and open the archive from the private backup location.

- [ ] **Step 2: Stop automation and uploads**

Resolve the actual synchronization mechanism from SourceForge project settings, GitHub webhooks, and any external automation inventory. Disable only the confirmed mirror/import job or upload integration, then capture the SourceForge file list and latest-update timestamp through read-only API and signed-out checks. Observe the project for at least one previously normal synchronization interval and confirm the file list and timestamp remain unchanged. Do not create a synthetic GitHub release or tag to test retirement.

- [ ] **Step 3: Remove all promoted SourceForge links**

Search both apps, all three repositories, Store metadata, and public pages. Remove or replace each customer-facing SourceForge destination, then run the link and website validators.

- [ ] **Step 4: Apply the retirement state**

If SourceForge supports a retired project notice without active downloads, set the project summary, homepage, and support link to the public migration destination and disable downloads. Otherwise remove the public files after confirming the website migration notice and Store listing are live.

- [ ] **Step 5: Verify from a signed-out session**

Confirm that SourceForge no longer offers MacPad as an active official download and that any remaining notice points to the correct public domain and Store page. Re-run the production Mac install from the App Store.

- [ ] **Step 6: Record evidence without secrets**

Record the retirement timestamp, project state, backup manifest location, checksum verification, and anonymous verification result in the cutover inventory.

- [ ] **Step 7: Keep permanent deletion owner-gated**

Do not delete the SourceForge project in this task. Present the verified backup and retirement evidence later; delete only after a new explicit owner instruction naming the project.

### Task 8: Make both source repositories private and adapt CI

**Files:**
- Read and verify: `./.github/workflows/release.yml`
- Modify: `./.github/workflows/swift-ci.yml`
- Delete: `./scripts/verify-public-repo.sh`
- Create: `./scripts/verify-repository-safety.sh`
- Read and verify: `../PhonePad/.github/workflows/ios-ci.yml`
- Read and verify: `../PhonePad/.github/workflows/ios-ui-tests.yml`
- Modify: `./docs/app-store-cutover-inventory.md`

**Interfaces:**
- Consumes: repository-privacy approval, public URL migration, SourceForge retirement, collaborator inventory, and private Actions allowance decision.
- Produces: two private repositories whose required engineering workflows still function.

- [ ] **Step 1: Prepare CI before changing visibility**

Verify that Task 3’s default-branch workflow has no tag trigger, write permission, release publication, or public-only artifact-attestation step. Rename `scripts/verify-public-repo.sh` to `scripts/verify-repository-safety.sh`, update the non-release workflow callers, and preserve its fail-closed secret/privacy checks. Confirm both projects’ private Actions allowance and expected runner usage with the owner. The Mobile workflows use standard build/test jobs and require no code change unless fresh inspection finds a public-only action; if it does, stop and revise this plan before visibility changes.

- [ ] **Step 2: Verify the dual-visibility CI configuration**

Run the renamed safety script, YAML validation, Swift tests, and the normal non-release CI while MacPad is still public. Use a workflow linter to verify that `.github/workflows/release.yml` is non-publishing and valid. Confirm the final signed transition asset remains the exact manually published artifact approved in Task 5. Verify both Mobile workflow files parse and contain no public-only action.

- [ ] **Step 3: Commit, push, and verify CI adaptations while public**

```bash
git add .github/workflows/swift-ci.yml
git add scripts/verify-public-repo.sh scripts/verify-repository-safety.sh
git commit -m "ci: prepare MacPad for private development"
```

Push through the protected-branch workflow and wait for required CI. Do not change visibility until the adaptation commit is on the default branch and its public-path checks pass.

- [ ] **Step 4: Verify no public customer dependency remains**

Run the cross-repository URL search and website validator. Customer-visible GitHub source URLs may remain only in historical records that are not published as current guidance.

- [ ] **Step 5: Capture final public repository evidence**

Record visibility, HEAD, tags, releases, issues, pull requests, Actions status, forks, stars, watchers, traffic, collaborators, deploy keys, webhooks, environments, Actions secrets/variables names, and branch protections without exposing secret values.

- [ ] **Step 6: Change MacPad visibility after exact owner approval**

Show the repository name and the expected consequences immediately before the action. After approval, make only `anvilfilbert/MacPad` private.

- [ ] **Step 7: Smoke-test MacPad authenticated workflows**

Verify authenticated clone/fetch, a non-destructive push path on a temporary branch, issue access, Actions execution, access to the manually published transition assets, branch protection, and the non-publishing direct-package verification workflow. Remove the temporary branch after verification using a recoverable documented process.

- [ ] **Step 8: Verify Mobile production, then change Mobile visibility after exact owner approval**

First verify the production MacPad Mobile Store listing, clean install, widget tap, document behavior, English/German metadata, and all public routes using the Task 6 method. If Mobile is not live, stop here without changing its repository. After that gate passes, repeat the consequence preview and approval for `anvilfilbert/MacPad-Mobile`; approval for MacPad does not imply approval for Mobile.

- [ ] **Step 9: Smoke-test Mobile authenticated workflows**

Verify authenticated clone/fetch, a non-destructive temporary-branch push, issue access, Actions execution, branch protection, and collaborator access. Confirm the public app and website links still work signed out.

- [ ] **Step 10: Record the private state**

Update the cutover inventory with timestamps, post-change workflow results, retained public forks/copies, Actions implications, and any unresolved follow-up. Never record credentials.

### Task 9: Close the cutover and hand off operations

**Files:**
- Modify: `./docs/app-store-cutover-inventory.md`
- Modify: `../anvilfilbert.github.io/docs/public-url-contract.md`

**Interfaces:**
- Consumes: all completed gate evidence.
- Produces: a current-state operational record with no hidden dependency on the retired public channels.

- [ ] **Step 1: Run the full final verification**

Verify both production Store installs, both languages, Mac menu-bar launch, Mobile widget launch, document open/save/relaunch, all public routes, SourceForge retirement, repository privacy, and required authenticated CI workflows in one dated session.

- [ ] **Step 2: Search for stale current guidance**

```bash
rg -n "github\.com/anvilfilbert/(MacPad|MacPad-Mobile)|sourceforge|Download latest release|Install locally with Xcode|Public repo" \
  . \
  ../PhonePad \
  ../anvilfilbert.github.io
```

Classify every remaining result as private engineering configuration or historical record. Fix every current customer-facing result before closing.

- [ ] **Step 3: Record ownership and renewal responsibilities**

Record who owns domain renewal, Apple Program renewal, Store metadata updates, privacy/support content, security intake, CI allowance monitoring, and SourceForge backup retention. Record contacts and account names only when they are safe and owner-approved; never store credentials.

- [ ] **Step 4: Present the completion report**

Report completed gates, production URLs, Store versions, verification evidence, repository visibility, SourceForge state, backup verification, ongoing costs, and any owner-held follow-up. Do not call the cutover complete while an acceptance criterion in the design remains unverified.

- [ ] **Step 5: Request permanent SourceForge deletion only if still desired**

If the owner still wants the retired project erased, present the exact project, backup manifest, consequences, and recovery limits. Execute deletion only after a new explicit instruction; otherwise leave the safely retired state in place.
