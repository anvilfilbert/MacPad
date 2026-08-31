# MacPad English/German and App Store Preparation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship a completely localized English/German MacPad, prepare the App Store as the official launch distribution channel, retain the direct build only as the foundation for one owner-gated legacy-user transition release, and produce credential-free archive, metadata, screenshot, migration, and private-repository readiness evidence up to the explicit Apple-account and owner-decision gates.

**Architecture:** Keep one AppKit implementation and the existing `NotepadMacCore` business logic. Add native String Catalog resources, a small typed bundle-localization boundary, persistent security-scoped file references for the sandboxed channel, a typed customer-route boundary, and one native Xcode macOS application target with `DirectRelease` and `AppStore` configurations. SwiftPM remains the test and transition-build foundation; the App Store configuration contains no legacy customer routes or direct updater.

**Tech Stack:** Swift 6.3, AppKit, Foundation, Swift Testing, Swift Package Manager, Xcode 26.6, Xcode String Catalogs, Xcode build configurations, App Sandbox, shell verification scripts, GitHub Actions.

**Spec:** [GitHub issue #29](https://github.com/anvilfilbert/MacPad/issues/29) and [GitHub issue #28](https://github.com/anvilfilbert/MacPad/issues/28), together with the approved 2026-08-28 owner brief and the binding cross-project design and plan in `docs/superpowers/specs/2026-08-28-private-source-app-store-cutover-design.md` and `docs/superpowers/plans/2026-08-28-private-source-app-store-cutover.md`.

## Global Constraints

- Work only in the MacPad desktop repository; never modify MacPad Mobile.
- English is the source and primary language; German is the only additional launch language.
- Use macOS native per-app language selection and Xcode String Catalogs. Do not implement a custom language switcher.
- German copy must be concise, natural, and platform-standard, without unnecessary `Du` or `Sie`.
- Preserve the product focus: plain text, immediate launch, and the optional menu-bar workflow. Do not add accounts, telemetry, advertising, networking, Markdown tooling, themes, extensions, or IDE features.
- Keep identifiers, defaults keys, URLs, accessibility identifiers, log/debug messages, file extensions, keyboard shortcuts, and invariant encoding names untranslated.
- Preserve file encodings, mixed line endings, file-conflict protection, recovery, multi-window/tab behavior, accessibility, and keyboard conventions.
- Store configuration must use App Sandbox, user-selected read/write file access, app-scoped bookmarks, and printing only. Do not add broad home, Documents, Downloads, network, or temporary-exception entitlements.
- Session state may persist paths and bookmark data but never document text.
- The App Store is the official binary channel at launch. Preserve the current direct build only as a local verification and final legacy-transition foundation; it is not a permanent parallel customer channel.
- Store builds must contain no customer-facing GitHub, GitHub Pages, DeepWiki, or SourceForge route, public-repository credit, or direct-update command. Do not substitute an invented URL or silently fall back to a repository route while the public URL contract is owner-gated.
- The final public direct-transition release must use the approved permanent bilingual routes, must not present GitHub Releases or SourceForge as an update channel, and must be Developer ID signed and notarized. Preparing or publishing it remains outside this credential-free plan and requires the later owner gates in the cross-project plan.
- Do not change repository visibility, SourceForge state, DNS/domain state, release publication, or CI billing/plan state in this work. Each source repository becomes private only after its own verified production Store gate; permanent SourceForge deletion remains separately owner-gated.
- Keep `local.macpad.app` as the repository placeholder until the owner approves a production identifier.
- Never add a Team ID, certificate, provisioning profile, signing secret, App Store Connect record, upload step, notarization credential, or final Store URL.
- Draft price only: MacPad USD 2.99; future bundle USD 3.99. Do not set pricing or territories externally.
- Preserve unrelated untracked workspace files and directories without editing, committing, or deleting them.
- Use focused commits, no force pushes, and the protected-branch pull-request workflow.

## Inspection Baseline

- `main`, `origin/main`, and annotated tag `v1.3.1` resolve to commit `59c1e66`.
- The focused branch is `codex/localization-app-store-prep`.
- Issues #28 and #29 are the only open Store/localization tracking issues; no competing branch or pull request exists remotely.
- The current product is a SwiftPM executable with a manually assembled application bundle. There is no Xcode project, String Catalog, localization directory, asset catalog, entitlement file, or Store configuration.
- `Resources/Info.plist` currently uses `local.macpad.app`, has no Utilities category, and exposes the English document type `Plain Text`.
- The direct build is ad-hoc signed and produces a universal `arm64 x86_64` ZIP.
- Session state stores only `filePath`; Open Recent delegates to `NSDocumentController` and has no persistent bookmark data.
- `AppDelegate.menuNeedsUpdate(_:)` compares the visible title `Open Recent`; this must be replaced with a stable identifier before localization.
- `Assets/MacPad-Review.png` is only 633×457 and has alpha, so it is not a valid Mac App Store screenshot.
- A bounded fresh `swift test --disable-sandbox` diagnosis completed 72 tests in 6 suites with zero failures when run in the normal macOS host environment. The same command reproducibly hangs after `Build complete!` inside the outer managed Codex filesystem sandbox because the AppKit Swift Testing helper cannot complete there; SwiftPM's `--disable-sandbox` flag does not disable that outer sandbox. One earlier run also encountered `.build` contention, and two coordinated-save tests still contain unbounded worker waits that should be made finite, but neither is the confirmed root cause of the outer-sandbox stall.

## Architecture Decision

Use a committed native `MacPad.xcodeproj` with one `MacPad` application target and shared source-file references. The target gets `Debug`, `DirectRelease`, and `AppStore` configurations plus two shared archive schemes. `DirectRelease` has no sandbox entitlements and may retain the current repository routes only while it is an internal preparation build; the later final transition release replaces them from the approved public URL contract. `AppStore` compiles with `MACPAD_APP_STORE`, uses only the approved sandbox entitlements, omits the direct updater, and compiles out every legacy customer route.

Rejected alternatives:

1. Opening `Package.swift` directly in Xcode cannot produce the required first-class macOS app archive target and configuration-specific entitlements.
2. A second Store app implementation would duplicate AppKit behavior and create drift.
3. XcodeGen or another project generator would add a third-party build dependency without solving a product requirement.

## Planned File Structure

- `Resources/Localizable.xcstrings`: canonical English/German customer-visible strings and plural variants.
- `Resources/InfoPlist.xcstrings`: localized Info.plist document-type display name.
- `Sources/NotepadMacCore/Localization.swift`: typed native bundle lookup and formatting functions shared by core errors and AppKit.
- `Sources/NotepadMacCore/PersistedFileReference.swift`: backward-compatible path plus optional bookmark data model.
- `Sources/NotepadMac/SecurityScopedFileAccess.swift`: Foundation connector for bookmark creation, resolution, stale refresh, and balanced access.
- `Sources/NotepadMac/RecentDocumentStore.swift`: bounded bookmark records aligned with native recent-document order.
- `Sources/NotepadMac/DistributionChannel.swift`: compile-time direct/Store behavior and explicitly injected customer-route policy.
- `Configurations/Base.xcconfig`, `Configurations/DirectRelease.xcconfig`, `Configurations/AppStore.xcconfig`: explicit channel settings without credentials.
- `Resources/AppStore.entitlements`: Store sandbox, user-selected read/write, app-scoped bookmarks, and printing.
- `Resources/Assets.xcassets/AppIcon.appiconset`: committed native icon renditions derived from `Resources/MacPadLogo.png`.
- `MacPad.xcodeproj`: native application target and shared Direct/AppStore schemes.
- `scripts/compile-localizations.sh`: deterministic catalog compilation for the manual direct bundle.
- `scripts/check-localizations.swift`: typed catalog structure, locale, completeness, placeholder, and plural validation.
- `scripts/archive-local.sh`: credential-free unsigned Xcode archive candidate creation and structural artifact inspection.
- `scripts/app-store-preflight.sh`: one read-only credential-free Store/direct verification entrypoint.
- `scripts/validate-store-screenshots.sh`: exact dimensions, alpha, format, and filename validation.
- `docs/app-store-preparation.md`: the single authoritative bilingual Store copy, evidence, recommendations, owner gates, and readiness matrix.
- `StoreAssets/Screenshots/{en,de}`: final opaque real-app screenshots only.

## Apple Evidence Used by This Plan

- Native per-app language and String Catalog workflow: <https://developer.apple.com/documentation/xcode/localizing-and-varying-text-with-a-string-catalog> and <https://developer.apple.com/documentation/xcode/testing-localizations-when-running-your-app>
- App Sandbox and user-selected files: <https://developer.apple.com/documentation/security/app-sandbox> and <https://developer.apple.com/documentation/security/accessing-files-from-the-macos-app-sandbox>
- Printing entitlement: <https://developer.apple.com/documentation/bundleresources/entitlements/com.apple.security.print>
- Mac screenshot specifications: <https://developer.apple.com/help/app-store-connect/reference/app-information/screenshot-specifications/>
- Utilities category: <https://developer.apple.com/library/archive/documentation/General/Reference/InfoPlistKeyReference/Articles/LaunchServicesKeys.html>
- Privacy manifests: <https://developer.apple.com/documentation/bundleresources/privacy-manifest-files>
- Export compliance: <https://developer.apple.com/help/app-store-connect/manage-app-information/overview-of-export-compliance>
- Distribution and notarization: <https://developer.apple.com/documentation/xcode/preparing-your-app-for-distribution> and <https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution>
- Store update restriction: App Review Guideline 2.4.5(vii), <https://developer.apple.com/app-store/review/guidelines/>

---

### Task 1: Bound coordinated-save waits and preserve the correct test environment

**Files:**
- Modify: `Tests/NotepadMacCoreTests/EditorDocumentTests.swift`
- Modify: `.github/workflows/swift-ci.yml`

**Interfaces:**
- Consumes: existing `NSFileCoordinator` semaphore-based integration tests.
- Produces: finite waits that report the exact missing coordination event and a CI wall-clock bound.

- [ ] **Step 1: Record the current isolated test evidence**

Run one bounded controller session in the normal macOS host environment, outside the outer Codex filesystem sandbox, for:

```bash
swift test --disable-sandbox
```

If it has not completed in 60 seconds, capture `ps -axo pid,ppid,state,etime,command`, terminate only the spawned SwiftPM process tree, and preserve the log. A run inside the managed Codex filesystem sandbox is an environment reproduction, not a valid product pass/fail result. Expected host result is 72 tests, 6 suites, zero failures.

- [ ] **Step 2: Write the failing cleanup-safety check**

In both coordinated-save tests, replace every worker-side unbounded `DispatchSemaphore.wait()` with an assertion helper whose failure identifies the gate:

```swift
private enum CoordinationWaitError: Error {
    case timedOut(String)
}

private func waitForCoordinationSignal(
    _ semaphore: DispatchSemaphore,
    name: String
) throws {
    guard semaphore.wait(timeout: .now() + 15) == .success else {
        throw CoordinationWaitError.timedOut(name)
    }
}
```

Add `defer` cleanup immediately after each worker is scheduled so every gate is signalled and every worker completion is waited with a finite bound even when an assertion exits early.

- [ ] **Step 3: Verify the altered test detects an unreleased gate**

Temporarily prevent one required signal in the test-only code and run the exact affected test filter. Expected: a finite failure naming that gate in under 20 seconds. Restore the signal before continuing.

- [ ] **Step 4: Run both coordination tests and the full suite**

Run:

```bash
swift test --disable-sandbox --filter EditorDocumentTests/waitsForCoordinatedWriter
swift test --disable-sandbox --filter EditorDocumentTests/rejectsSaveAfterCoordinatedExternalEdit
swift test --disable-sandbox
```

Expected: both focused tests pass; the full suite has zero failures and no test process remains.

- [ ] **Step 5: Add the CI wall-clock bound**

Set `timeout-minutes: 10` on the Swift test job. Do not add retry or fallback execution.

- [ ] **Step 6: Commit**

```bash
git add Tests/NotepadMacCoreTests/EditorDocumentTests.swift .github/workflows/swift-ci.yml
git commit -m "test: bound coordinated save test waits"
```

### Task 2: Add the native English/German localization foundation

**Files:**
- Create: `Resources/Localizable.xcstrings`
- Create: `Resources/InfoPlist.xcstrings`
- Create: `Sources/NotepadMacCore/Localization.swift`
- Create: `Tests/NotepadMacCoreTests/LocalizationTests.swift`
- Create: `scripts/check-localizations.swift`
- Create: `scripts/check-localizations.sh`
- Modify: `Package.swift`

**Interfaces:**
- Produces: `MacPadLocalization`, `MacPadStringKey`, `localized(_:)`, and typed formatting functions available to both targets.
- Produces: catalogs with exactly `en` and `de`, source language `en`, and stable semantic keys.

- [ ] **Step 1: Write catalog-contract tests before adding catalogs**

Create typed `Decodable` catalog fixtures in `LocalizationTests.swift`. The tests must fail because the catalog files do not exist, then enforce:

```swift
#expect(catalog.sourceLanguage == "en")
#expect(Set(catalog.locales) == ["en", "de"])
#expect(catalog.missingGermanKeys.isEmpty)
#expect(catalog.placeholderMismatches.isEmpty)
#expect(catalog.unexpectedPluralCategories.isEmpty)
```

The parser may use `[String: CatalogString]` for dynamic catalog keys, but must not use `Any`, `[String: Any]`, or silent decode recovery.

- [ ] **Step 2: Run the new test and verify RED**

```bash
swift test --disable-sandbox --filter LocalizationTests
```

Expected: fail specifically because `Localizable.xcstrings` and `InfoPlist.xcstrings` are absent.

- [ ] **Step 3: Add the typed native lookup boundary**

Implement a value type that delegates to Apple bundle localization rather than storing translations:

```swift
public struct MacPadLocalization: Sendable {
    public let bundle: Bundle

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    public func string(_ key: MacPadStringKey) -> String {
        bundle.localizedString(
            forKey: key.rawValue,
            value: key.englishValue,
            table: "Localizable"
        )
    }
}
```

`MacPadStringKey` is an exhaustive `String, CaseIterable, Sendable` enum. Each case supplies one English source value. Dynamic text uses named typed functions such as `statusLine(line:column:zoom:lineEnding:encoding:)`, `openFailure(fileName:)`, and `fileTooLarge(path:sizeBytes:maximumBytes:)`; callers never concatenate translated fragments.

Add the existing core target as a library product so the Xcode app target can link the same module without copying its source:

```swift
.library(name: "NotepadMacCore", targets: ["NotepadMacCore"])
```

- [ ] **Step 4: Create the catalogs**

Add every `MacPadStringKey` to `Localizable.xcstrings` with English and German values. Add `CFBundleTypeName` to `InfoPlist.xcstrings` with:

| Key | English | German |
| --- | --- | --- |
| `CFBundleTypeName` | Plain Text | Klartext |

Keep invariant encoding values unchanged: `UTF-8`, `UTF-8 BOM`, `UTF-16 LE`, `UTF-16 BE`, `Windows-1252`, and `ISO-8859-1`.

- [ ] **Step 5: Encode the safety-critical German terms**

Use these action-specific translations as the review baseline:

| English intent | German |
| --- | --- |
| Save | Sichern |
| Save As… | Sichern unter … |
| Don’t Save | Nicht sichern |
| Discard Changes | Änderungen verwerfen |
| Replace | Ersetzen |
| Reload from Disk | Neu laden |
| Recover | Wiederherstellen |
| Delete | Löschen |
| Cancel | Abbrechen |
| This file changed outside MacPad. | Diese Datei wurde außerhalb von MacPad geändert. |
| Save to another file, reload, or keep editing. | In einer anderen Datei sichern, neu laden oder weiterbearbeiten. |

- [ ] **Step 6: Add the repository-local validator**

`scripts/check-localizations.sh` invokes the checked-in Swift validator. It must fail for unsupported locales, missing German values, `needs_review` states, placeholder type/count/order mismatches, empty translated values, or plural categories that differ between English and German. It must also run:

```bash
xcrun xcstringstool compile Resources/Localizable.xcstrings --output-directory "$TEMP_DIR"
xcrun xcstringstool compile Resources/InfoPlist.xcstrings --output-directory "$TEMP_DIR"
```

- [ ] **Step 7: Run GREEN validation**

```bash
swift test --disable-sandbox --filter LocalizationTests
./scripts/check-localizations.sh
```

Expected: zero failures; compiled products contain both `en.lproj` and `de.lproj`.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Resources/Localizable.xcstrings Resources/InfoPlist.xcstrings Sources/NotepadMacCore/Localization.swift Tests/NotepadMacCoreTests/LocalizationTests.swift scripts/check-localizations.swift scripts/check-localizations.sh
git commit -m "feat: add English and German string catalogs"
```

### Task 3: Localize every AppKit and core customer-visible string

**Files:**
- Modify: `Sources/NotepadMac/AppDelegate.swift`
- Modify: `Sources/NotepadMac/EditorWindowController.swift`
- Modify: `Sources/NotepadMac/EditorFontPreferences.swift`
- Modify: `Sources/NotepadMac/FindPanelController.swift`
- Modify: `Sources/NotepadMac/MainMenuFactory.swift`
- Modify: `Sources/NotepadMac/SaveEncodingAccessory.swift`
- Modify: `Sources/NotepadMacCore/EditorDocument.swift`
- Modify: `Sources/NotepadMacCore/EditorFontPreference.swift`
- Modify: `Sources/NotepadMacCore/SessionState.swift`
- Modify: `Sources/NotepadMacCore/TextMetrics.swift`
- Modify: `Tests/NotepadMacTests/WindowRoutingTests.swift`
- Modify: `Tests/NotepadMacCoreTests/EditorDocumentTests.swift`
- Modify: `Tests/NotepadMacCoreTests/EditorFontPreferenceTests.swift`
- Modify: `Tests/NotepadMacCoreTests/TextMetricsTests.swift`

**Interfaces:**
- Consumes: `MacPadLocalization` and the complete catalog from Task 2.
- Produces: localized menus, panels, alerts, errors, accessibility text, status content, and window titles without display-text control flow.

- [ ] **Step 1: Add failing identifier- and locale-based AppKit tests**

Replace visible-title menu discovery with identifiers. Add stable identifiers for every custom menu branch and safety-critical action, including:

```text
menu.file
file.openRecent
file.save
file.saveAs
file.clearSession
view.menuBar
help.checkUpdates
find.term
find.replacement
find.next
find.previous
find.replace
find.replaceAll
editor.text
editor.status
```

Tests must first fail because `file.openRecent` and the localized German values are not wired.

- [ ] **Step 2: Replace title-based control flow**

Give the recent submenu `NSMenu.Identifier("file.openRecent")` and change `menuNeedsUpdate(_:)` to compare the identifier. `NSMenuItem.representedObject` must carry a structured recent-file value after Task 6, not a localized title or parsed tooltip.

- [ ] **Step 3: Migrate menus and distribution-neutral labels**

Use the typed localization boundary for File, Edit, Format, View, Window, Help, Services, About, Hide, Quit, recent documents, menu-bar commands, and all custom menu items. Preserve selectors and key equivalents exactly.

- [ ] **Step 4: Migrate windows, panels, alerts, and errors**

Localize the Find/Replace window, Go To Line, Save As encoding accessory, unsaved-document prompt, file conflict/reload flow, open/save/font/session failures, restoration summaries, About credits prose, status line, `Untitled`, line-ending `Mixed`, and all `LocalizedError.errorDescription` values. Keep URLs and paths as interpolated data, never translatable source text.

- [ ] **Step 5: Localize accessibility and tooltips**

Localize every custom accessibility label and menu-bar tooltip while preserving stable identifiers. Verify `Document text`, `Document status`, all Find controls, Go To Line input, encoding picker, and menu-bar new-window action in both languages.

- [ ] **Step 6: Make Find/Replace adapt to German**

Remove the fixed `430×204` assumption and fixed label/button column widths. Use intrinsic content size with these constraints:

```swift
window.contentMinSize = NSSize(width: 500, height: 204)
grid.column(at: 0).xPlacement = .trailing
grid.column(at: 1).width = 220
grid.column(at: 2).xPlacement = .fill
```

Set buttons to resist compression and size the panel from `grid.fittingSize` plus 32 points horizontal and vertical padding. The German panel must have no ambiguous layout and no clipped label or button.

- [ ] **Step 7: Verify RED/GREEN behavior**

Run focused tests before and after each migration group. Then run:

```bash
swift test --disable-sandbox
./scripts/check-localizations.sh
```

Expected: all tests pass; shortcut uniqueness is unchanged; tests locate behavior by stable identifiers; catalog validator reports no uncovered typed key.

- [ ] **Step 8: Commit**

```bash
git add Sources/NotepadMac/AppDelegate.swift Sources/NotepadMac/EditorWindowController.swift Sources/NotepadMac/EditorFontPreferences.swift Sources/NotepadMac/FindPanelController.swift Sources/NotepadMac/MainMenuFactory.swift Sources/NotepadMac/SaveEncodingAccessory.swift Sources/NotepadMacCore/EditorDocument.swift Sources/NotepadMacCore/EditorFontPreference.swift Sources/NotepadMacCore/SessionState.swift Sources/NotepadMacCore/TextMetrics.swift Tests/NotepadMacTests/WindowRoutingTests.swift Tests/NotepadMacCoreTests/EditorDocumentTests.swift Tests/NotepadMacCoreTests/EditorFontPreferenceTests.swift Tests/NotepadMacCoreTests/TextMetricsTests.swift Resources/Localizable.xcstrings
git commit -m "feat: localize MacPad in English and German"
```

### Task 4: Package native localizations in the direct-download app

**Files:**
- Create: `scripts/compile-localizations.sh`
- Modify: `scripts/build-app.sh`
- Modify: `scripts/package-release.sh`
- Modify: `Resources/Info.plist`
- Modify: `Tests/NotepadMacTests/WindowRoutingTests.swift`

**Interfaces:**
- Consumes: both String Catalogs.
- Produces: `MacPad.app/Contents/Resources/{en,de}.lproj/{Localizable,InfoPlist}.strings` for the manual direct bundle.

- [ ] **Step 1: Add a failing direct-bundle resource assertion**

Extend release verification to fail unless all four compiled localization files exist and `CFBundleLocalizations` is exactly `en`, `de`.

- [ ] **Step 2: Run the direct build and verify RED**

```bash
./scripts/build-app.sh
```

Expected: fail the new resource assertion because the direct builder does not yet compile catalogs.

- [ ] **Step 3: Compile catalogs into the staged app**

`scripts/compile-localizations.sh` takes exactly two explicit arguments: catalog directory and output directory. It compiles both catalogs with `xcstringstool`, verifies the four output files, and raises a specific nonzero error for any missing locale or product. Call it from `build-app.sh` before signing.

Sign the ad-hoc direct candidate with `codesign --options runtime` so the public workflow exercises Hardened Runtime now and can later replace only the signing identity plus notarization steps.

- [ ] **Step 4: Advertise native locales and Utilities category**

Add:

```xml
<key>CFBundleLocalizations</key>
<array>
    <string>en</string>
    <string>de</string>
</array>
<key>LSApplicationCategoryType</key>
<string>public.app-category.utilities</string>
```

Keep `CFBundleDevelopmentRegion` equal to `en` and the identifier equal to `local.macpad.app`.

- [ ] **Step 5: Verify both localizations in the direct artifact**

```bash
./scripts/build-app.sh
plutil -p build/MacPad.app/Contents/Info.plist
find build/MacPad.app/Contents/Resources -maxdepth 2 -type f -print | sort
codesign --verify --deep --strict build/MacPad.app
lipo -archs build/MacPad.app/Contents/MacOS/MacPad
```

Expected: `en` and `de` resources, strict signature success, and `arm64 x86_64`.

Also inspect `codesign -dv --verbose=4 build/MacPad.app` and require the `runtime` flag.

- [ ] **Step 6: Commit**

```bash
git add Resources/Info.plist scripts/compile-localizations.sh scripts/build-app.sh scripts/package-release.sh Tests/NotepadMacTests/WindowRoutingTests.swift
git commit -m "build: package localized direct releases"
```

### Task 5: Add backward-compatible persisted file references

**Files:**
- Create: `Sources/NotepadMacCore/PersistedFileReference.swift`
- Create: `Tests/NotepadMacCoreTests/PersistedFileReferenceTests.swift`
- Modify: `Sources/NotepadMacCore/SessionState.swift`
- Modify: `Sources/NotepadMacCore/EditorDocument.swift`
- Modify: `Tests/NotepadMacCoreTests/SessionStateTests.swift`

**Interfaces:**
- Produces: `PersistedFileReference(path:bookmarkData:)`.
- Historical model change: `EditorSessionState` can decode legacy `filePath` values for isolated compatibility tests. The owner-approved 2026-08-31 launch path does not call this decoder and deletes the obsolete stored session value.

- [ ] **Step 1: Write failing legacy and new-state tests**

Tests must cover:

```swift
let legacyJSON = #"{"id":"tab","filePath":"/tmp/note.txt","selectedLocation":0,"wordWrapEnabled":true,"statusBarVisible":true,"zoomPercent":100,"lineEnding":"windows"}"#
#expect(decoded.fileReference?.path == "/tmp/note.txt")
#expect(decoded.fileReference?.bookmarkData == nil)
```

Also cover Base64 bookmark round-trip, absence for untitled tabs, malformed bookmark data decode failure, session limits, and the invariant that no text field is encoded.

- [ ] **Step 2: Run the focused tests and verify RED**

```bash
swift test --disable-sandbox --filter PersistedFileReferenceTests
swift test --disable-sandbox --filter SessionStateTests
```

- [ ] **Step 3: Implement the value model**

```swift
public struct PersistedFileReference: Codable, Equatable, Sendable {
    public let path: String
    public let bookmarkData: Data?

    public init(path: String, bookmarkData: Data?) {
        self.path = path
        self.bookmarkData = bookmarkData
    }
}
```

Use custom `EditorSessionState` coding keys for `fileReference` and legacy `filePath`. Encode only `fileReference`; decode `fileReference` first, then construct a reference from legacy `filePath` with `bookmarkData: nil`.

- [ ] **Step 4: Keep persistent file references separate from launch state**

`EditorDocument` keeps the resolved `URL` for current I/O and exposes explicit methods to attach or refresh its `PersistedFileReference`. Under the owner-approved 2026-08-31 launch contract, AppDelegate neither writes nor restores document sessions. It deletes the obsolete `MacPad.SessionState.v1` value on launch without changing `MacPad.RecentDocumentBookmarks.v1`.

- [ ] **Step 5: Run GREEN tests and full session tests**

```bash
swift test --disable-sandbox --filter PersistedFileReferenceTests
swift test --disable-sandbox --filter SessionStateTests
```

- [ ] **Step 6: Commit**

```bash
git add Sources/NotepadMacCore/PersistedFileReference.swift Sources/NotepadMacCore/SessionState.swift Sources/NotepadMacCore/EditorDocument.swift Tests/NotepadMacCoreTests/PersistedFileReferenceTests.swift Tests/NotepadMacCoreTests/SessionStateTests.swift
git commit -m "feat: persist bookmark-capable file references"
```

### Task 6: Implement distribution-aware security-scoped session and Open Recent access

**Files:**
- Create: `Sources/NotepadMac/DistributionChannel.swift`
- Create: `Sources/NotepadMac/SecurityScopedFileAccess.swift`
- Create: `Sources/NotepadMac/RecentDocumentStore.swift`
- Create: `Tests/NotepadMacTests/DistributionChannelTests.swift`
- Create: `Tests/NotepadMacTests/SecurityScopedFileAccessTests.swift`
- Create: `Tests/NotepadMacTests/RecentDocumentStoreTests.swift`
- Modify: `Sources/NotepadMacCore/Localization.swift`
- Modify: `Sources/NotepadMac/AppDelegate.swift`
- Modify: `Sources/NotepadMac/EditorWindowController.swift`
- Modify: `Sources/NotepadMac/MainMenuFactory.swift`
- Modify: `Tests/NotepadMacTests/WindowRoutingTests.swift`
- Modify: `Resources/Localizable.xcstrings`

**Interfaces:**
- Consumes: `PersistedFileReference`.
- Produces: `DistributionChannel`, `CustomerRoutes`, `SecurityScopedFileAccess`, `ResolvedFileAccess<Value>`, `SuccessfulFileTransition`, and `RecentDocumentStore`.
- Guarantees: every successful `startAccessingSecurityScopedResource()` has one `stopAccessingSecurityScopedResource()` on success and error paths.

- [ ] **Step 1: Write failing distribution-policy tests**

```swift
#expect(DistributionChannel.direct.showsDirectUpdateCommand)
#expect(!DistributionChannel.direct.requiresPersistentSecurityScope)
#expect(!DistributionChannel.appStore.showsDirectUpdateCommand)
#expect(DistributionChannel.appStore.requiresPersistentSecurityScope)
```

Add explicitly constructed `CustomerRoutes` fixtures for the current direct preparation channel and for an unconfigured Store channel. The Store tests must fail if Help, Report an Issue, Privacy, Security, or Check for Updates resolves to GitHub, GitHub Pages, DeepWiki, or SourceForge; if `Check for Updates…` exists; or if About contains `Public repo` or a repository link. Missing owner-approved Store routes must omit their commands instead of falling back.

- [ ] **Step 2: Implement the pure channel policy**

```swift
enum DistributionChannel: Equatable {
    case direct
    case appStore

    static var current: DistributionChannel {
        #if MACPAD_APP_STORE
        return .appStore
        #else
        return .direct
        #endif
    }

    var showsDirectUpdateCommand: Bool { self == .direct }
    var requiresPersistentSecurityScope: Bool { self == .appStore }
}
```

Define `CustomerRoutes` as a strictly typed value with explicit optional `URL` properties for product, Help, support/issue reporting, privacy, security, and update/migration destinations. Pass the channel and route set explicitly into menu, About, URL-action, and file-access construction. Menu items exist only for configured routes. Keep the current direct GitHub routes behind `#if !MACPAD_APP_STORE` so both SwiftPM and `MACPAD_DIRECT` Xcode preparation builds preserve current behavior; the Store compilation condition must exclude their literals from the binary. Do not inspect receipts or bundle paths at runtime, invent URLs, or add a repository fallback. The later cross-project link-migration gate replaces both channels with the exact approved public URL contract and keeps direct update UI absent from the Store channel.

- [ ] **Step 3: Write failing real bookmark tests**

Using real temporary files, test bookmark creation, resolution, file move/stale refresh where the OS reports staleness, read/write through the resolved URL, and an operation that throws. Verify the thrown operation error is preserved. Do not replace Foundation bookmark APIs with mocks.

- [ ] **Step 4: Write failing recent-store tests**

Use an isolated `UserDefaults` suite. Test ordered add/deduplicate, bookmark replacement after Save As, clear, corrupt-data failure, and a strict maximum of 20 records.

- [ ] **Step 5: Implement the Foundation connector**

Use these explicit interfaces:

```swift
struct ResolvedFileAccess<Value> {
    let value: Value
    let refreshedReference: PersistedFileReference
}

struct SuccessfulFileTransition: Equatable, Sendable {
    let previousReference: PersistedFileReference?
    let currentReference: PersistedFileReference
}

struct SecurityScopedFileAccess {
    let requiresBookmark: Bool

    func makeReference(for url: URL) throws -> PersistedFileReference

    func access<Value>(
        _ reference: PersistedFileReference,
        operation: (URL) throws -> Value
    ) throws -> ResolvedFileAccess<Value>

    func accessGrantedURL<Value>(
        _ url: URL,
        operation: (URL) throws -> Value
    ) throws -> ResolvedFileAccess<Value>
}
```

Own `SuccessfulFileTransition` in `EditorWindowController.swift`. Its callback is `((SuccessfulFileTransition) -> Void)?`. Capture `previousReference` before Save As begins; after the write and bookmark creation both succeed, attach `currentReference`, then emit the transition for recent-document replacement. A failed write or bookmark creation emits no transition and no recent replacement.

Resolve bookmarks with `.withSecurityScope` and `.withoutUI`, then require a successful `startAccessingSecurityScopedResource()`. After a successful start, install one `defer` that performs exactly one stop; while that scope is active, recreate stale bookmark data before invoking the operation, invoke the operation, and return its value plus the refreshed reference. A failed start performs no refresh, operation, or stop and throws a localized access-denied error. If `requiresBookmark` is true and a restored reference has no bookmark, throw a localized `missingPersistentAccess(path:)` error. `accessGrantedURL` exists specifically for a live open/save-panel grant: it does not resolve a bookmark or start another scope; it invokes the operation first and creates the persistent reference afterward, before the panel-granted flow returns. This separate boundary is required because Foundation refuses to create a scoped bookmark for a Save As destination until that file exists.

- [ ] **Step 6: Wire customer routes and file operations**

Replace hard-coded URL selectors with access to the injected `CustomerRoutes`. Both About presentations expose only Website, Support, and Privacy on macpad.net, with no creator, source-code, visible email, or mailto content. Help and Support use the permanent support route. The Store channel never exposes direct update UI; the Direct channel may retain only its separate transition update route. Wire Open, Save, Save As, reload, and Open Recent through the security-scoped access boundary.

The open panel creates a reference while the user-selected existing-file grant is live. Controller load, existing-file save, reload, and Open Recent operations execute through `SecurityScopedFileAccess.access`. A new Save As destination does not exist before the first write, so the save panel uses `accessGrantedURL`: write through the live grant first, then create and attach the bookmark before returning. Save As emits `SuccessfulFileTransition` only after the new reference is attached; the AppDelegate replaces the old recent bookmark with the new one.

- [ ] **Step 7: Wire native Open Recent ordering to stored bookmarks**

Continue using `NSDocumentController.recentDocumentURLs` for native ordering. Store bookmark records separately in `MacPad.RecentDocumentBookmarks.v1`; join by standardized path when building the menu. `representedObject` carries `PersistedFileReference`. Clearing the native menu also clears bookmark records.

- [ ] **Step 8: Discard obsolete launch sessions without touching recents**

Normal launch creates exactly one blank document. Do not decode, restore, or write `MacPad.SessionState.v1`; delete any legacy value. Keep recent-document bookmarks independent so saved files remain available through Open Recent. Dirty documents still require the localized Save, Don't Save, or Cancel decision before quit, and explicit file opens continue to use the approved access boundary.

- [ ] **Step 9: Verify focused and full tests**

```bash
swift test --disable-sandbox --filter DistributionChannelTests
swift test --disable-sandbox --filter SecurityScopedFileAccessTests
swift test --disable-sandbox --filter RecentDocumentStoreTests
swift test --disable-sandbox --filter WindowRoutingTests
swift test --disable-sandbox
```

- [ ] **Step 10: Commit**

```bash
git add Sources/NotepadMac/DistributionChannel.swift Sources/NotepadMac/SecurityScopedFileAccess.swift Sources/NotepadMac/RecentDocumentStore.swift Sources/NotepadMacCore/Localization.swift Sources/NotepadMac/AppDelegate.swift Sources/NotepadMac/EditorWindowController.swift Sources/NotepadMac/MainMenuFactory.swift Tests/NotepadMacTests/DistributionChannelTests.swift Tests/NotepadMacTests/SecurityScopedFileAccessTests.swift Tests/NotepadMacTests/RecentDocumentStoreTests.swift Tests/NotepadMacTests/WindowRoutingTests.swift Resources/Localizable.xcstrings
git commit -m "feat: restore sandboxed files with bookmarks"
```

### Task 7: Add the native Xcode app target and channel configurations

**Files:**
- Create: `Configurations/Base.xcconfig`
- Create: `Configurations/DirectRelease.xcconfig`
- Create: `Configurations/AppStore.xcconfig`
- Create: `Resources/AppStore.entitlements`
- Create: `MacPad.xcodeproj/project.pbxproj`
- Create: `MacPad.xcodeproj/project.xcworkspace/contents.xcworkspacedata`
- Create: `MacPad.xcodeproj/xcshareddata/xcschemes/MacPad-Direct.xcscheme`
- Create: `MacPad.xcodeproj/xcshareddata/xcschemes/MacPad-AppStore.xcscheme`
- Modify: `Resources/Info.plist`

**Interfaces:**
- Consumes: the `NotepadMacCore` Swift package library product and `DistributionChannel`.
- Produces: one `MacPad` application target with `Debug`, `DirectRelease`, and `AppStore` configurations.
- Produces: compile conditions `MACPAD_DIRECT` and `MACPAD_APP_STORE`.

- [ ] **Step 1: Write the failing Xcode build checks**

Add the two unsigned `xcodebuild` commands to a temporary verification script and run it. Expected: fail because `MacPad.xcodeproj` does not exist. Remove the temporary script after the Xcode project is validated; the permanent commands move into `scripts/app-store-preflight.sh` in Task 8.

- [ ] **Step 2: Create exact build configurations**

`Base.xcconfig` sets macOS 14.0, Swift 6, warnings as errors, Hardened Runtime, version `1.3.1`, build `15`, `local.macpad.app`, Utilities category metadata, and no development team. `DirectRelease.xcconfig` defines `MACPAD_DIRECT` and no entitlement file. `AppStore.xcconfig` defines `MACPAD_APP_STORE` and `CODE_SIGN_ENTITLEMENTS = Resources/AppStore.entitlements`.

- [ ] **Step 3: Add only the approved Store entitlements**

```xml
<dict>
    <key>com.apple.security.app-sandbox</key>
    <true/>
    <key>com.apple.security.files.user-selected.read-write</key>
    <true/>
    <key>com.apple.security.files.bookmarks.app-scope</key>
    <true/>
    <key>com.apple.security.print</key>
    <true/>
</dict>
```

- [ ] **Step 4: Create the Xcode target and schemes**

Reference `Sources/NotepadMac` directly and link the local package product `NotepadMacCore`; do not copy Swift files or compile core sources into the app target. Link AppKit. Include both String Catalogs, `Info.plist`, and `LICENSE`. Leave `ASSETCATALOG_COMPILER_APPICON_NAME` unset until Task 8 adds the icon catalog. The Direct scheme archives with `DirectRelease`; the Store scheme archives with `AppStore`. Neither scheme contains a Team ID or upload action.

- [ ] **Step 5: Build both configurations with warnings as errors**

```bash
xcodebuild -project MacPad.xcodeproj -scheme MacPad-Direct -configuration DirectRelease -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
xcodebuild -project MacPad.xcodeproj -scheme MacPad-AppStore -configuration AppStore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
```

Expected: both commands exit 0; Store compilation omits direct-update UI, public-repository credits, and every legacy customer route, and requires persistent bookmarks.

- [ ] **Step 6: Commit**

```bash
git add Configurations Resources/AppStore.entitlements Resources/Info.plist MacPad.xcodeproj
git commit -m "build: add direct and App Store Xcode targets"
```

### Task 8: Add the native AppIcon asset catalog and archive preflight

**Files:**
- Create: `Resources/Assets.xcassets/Contents.json`
- Create: `Resources/Assets.xcassets/AppIcon.appiconset/Contents.json`
- Create: `Resources/Assets.xcassets/AppIcon.appiconset/*.png`
- Create: `scripts/create-app-icon-assets.sh`
- Create: `scripts/archive-local.sh`
- Create: `scripts/app-store-preflight.sh`
- Modify: `scripts/create-app-icon.sh`
- Modify: `Configurations/Base.xcconfig`
- Modify: `MacPad.xcodeproj/project.pbxproj`
- Modify: `.github/workflows/swift-ci.yml`

**Interfaces:**
- Consumes: opaque `Resources/MacPadLogo.png`.
- Produces: native 16, 32, 128, 256, 512, and 1024 pixel icon resources and a credential-free `.xcarchive` candidate.

- [ ] **Step 1: Write icon/preflight assertions first**

The preflight must fail until the asset catalog exists. It validates every `Contents.json` filename, exact pixel size, no alpha, and the source color profile. It also validates the Store entitlement plist with `plutil -lint`.

- [ ] **Step 2: Generate deterministic icon assets**

Extend the existing icon pipeline to produce all macOS 1×/2× renditions from the existing opaque source. Do not redraw or replace the approved artwork. Commit the generated PNGs so Xcode archives do not depend on a pre-build mutation.

Add `Resources/Assets.xcassets` to the Xcode resources phase and set `ASSETCATALOG_COMPILER_APPICON_NAME = AppIcon` only after every referenced rendition exists.

- [ ] **Step 3: Create a credential-free archive candidate**

`scripts/archive-local.sh` uses a temporary DerivedData and archive directory, runs `xcodebuild archive` with `CODE_SIGNING_ALLOWED=NO`, then copies the unsigned app to a verification directory without signing it. It never signs, exports, uploads, notarizes, or reads a signing identity.

- [ ] **Step 4: Inspect the archive**

The script must verify:

```text
MacPad.app/Contents/MacOS/MacPad
MacPad.app/Contents/Resources/en.lproj/Localizable.strings
MacPad.app/Contents/Resources/de.lproj/Localizable.strings
MacPad.app/Contents/Resources/en.lproj/InfoPlist.strings
MacPad.app/Contents/Resources/de.lproj/InfoPlist.strings
MacPad.app/Contents/Resources/AppIcon.icns
MacPad.app/Contents/Resources/LICENSE
```

It checks that the archive and verification copy have no signature directory, then inspects `plutil`, `lipo`, bundle version, placeholder identifier, localizations, category, and absence of private paths/secrets. The preflight separately lints the source entitlement plist; signed runtime entitlement acceptance remains owner-gated. It recursively scans the Store app's executable and resources and fails on customer-route domain tokens including `github.com`, `githubusercontent.com`, `sourceforge.net`, `anvilfilbert.github.io`, and `deepwiki.com`, plus `/releases/latest`. A separate runtime test verifies that Store About does not display a public-repository credit; do not reject an otherwise unused shared localized label merely because both channels compile the same catalog. Engineering provenance in an archive-side manifest is allowed only when it is outside the app bundle and cannot be linked or displayed by the app.

- [ ] **Step 5: Add credential-free CI coverage**

Run localization checks and unsigned Xcode builds in Swift CI. Keep the existing direct build as a non-publishing verification job for now; do not treat GitHub Releases or attestations as a permanent customer channel. Add no App Store upload, direct-release publication, notarization, signing, visibility change, or paid-plan-dependent private attestation step. The later cross-project gate must remove tag-triggered publication and re-audit authenticated fetches, Actions allowance, CodeQL eligibility, and attestation behavior before repository privacy.

- [ ] **Step 6: Run preflight and commit**

```bash
./scripts/app-store-preflight.sh
git add Resources/Assets.xcassets scripts/create-app-icon-assets.sh scripts/create-app-icon.sh scripts/archive-local.sh scripts/app-store-preflight.sh Configurations/Base.xcconfig MacPad.xcodeproj/project.pbxproj .github/workflows/swift-ci.yml
git commit -m "build: add Store icon and archive preflight"
```

### Task 9: Create the authoritative bilingual Store preparation package

**Files:**
- Create: `docs/app-store-preparation.md`
- Modify: `README.md`

**Interfaces:**
- Produces: one current source for metadata, privacy/support page copy, compliance evidence, Store review notes, proposals, and owner gates.

- [ ] **Step 1: Audit code and dependencies before writing privacy claims**

Record exact evidence from `Package.swift`, source imports, `NSWorkspace` URL calls, UserDefaults keys, file operations, CryptoKit SHA-256 use, and absence of analytics/ad/account/network SDKs. Distinguish local file content from collected data: MacPad processes content on-device and does not transmit it.

- [ ] **Step 2: Record the privacy-manifest decision**

Apple's required-reason API list does not currently impose macOS declarations, the package has no third-party SDKs, and the app collects no data. Therefore do not add `PrivacyInfo.xcprivacy` without a newly identified required API or SDK. Record the audit date, evidence, and re-audit trigger in the authoritative document.

- [ ] **Step 3: Write complete English and German Store drafts**

Include final local drafts for:

```text
App name
Subtitle
Description
Keywords
Promotional text
Release notes
Three screenshot captions
Privacy-policy page content
Support page content
App Review notes
Review test instructions
```

English positioning begins with `Plain text. Instantly.` German positioning begins with `Klartext. Sofort.` The first benefit is menu-bar instant access; encoding, line-ending, conflict, and recovery details appear later as trust features.

- [ ] **Step 4: Record draft owner decisions without external mutation**

Document:

- Primary category: Utilities (`public.app-category.utilities`).
- Age-rating answers: no objectionable content, unrestricted web access, gambling, contests, messaging, user-generated content, advertising, or purchases in the app; owner must re-confirm in the live questionnaire.
- App Privacy draft: no data collected; owner must enter and attest in App Store Connect.
- Export compliance: local SHA-256 hashing exists; no network or encryption feature is implemented; owner must complete Apple's live determination before adding `ITSAppUsesNonExemptEncryption`.
- Content rights: repository artwork and Apache-2.0 code/license evidence; owner must attest.
- EU DSA trader status: owner decision required; do not infer status.
- Draft price: USD 2.99; future bundle USD 3.99; territories require owner selection.
- Launch distribution: the App Store is the official installation and update channel; the direct build is limited to one legacy-user transition release and repository-local verification.
- Cutover dependency: no repository visibility or SourceForge change occurs until the permanent bilingual public routes, exact signed migration test, verified live Store listing, and separate owner approval required by the cross-project plan.

- [ ] **Step 5: Propose identifiers and state migration consequences**

Present exactly these owner options without changing the project placeholder:

1. Recommended: `com.anvilfilbert.MacPad` — aligns with the public publisher namespace.
2. Alternative: `app.macpad.editor` — stronger product naming but should be chosen only if the brand namespace is controlled long term.

Changing from `local.macpad.app` changes the UserDefaults domain, recent-document identity, sandbox container, and code-signing identity association. Direct and Store builds should normally adopt the same approved production identifier before first App Store upload; the identifier cannot be changed after that upload. Provide a one-time preferences/session migration plan only after the owner selects the final identifier.

- [ ] **Step 6: State the exact public URL contract owner input**

Do not invent URLs or consume domain-availability research as approval. State: `OWNER INPUT REQUIRED: final HTTPS public URL contract on an owner-controlled domain.` The contract must provide anonymous English/German destinations for product/marketing, Help/documentation, support and issue reporting, privacy, security reporting, release notes, direct-user migration/update guidance, and the final App Store listing. Include ready-to-publish English and German support/privacy/help/migration content directly below this gate. Record that App Store Help/Privacy/Support commands remain absent rather than falling back until the exact routes are approved and compiled.

- [ ] **Step 7: Document the legacy-user and private-repository readiness gates**

Add a fail-closed migration matrix for the exact signed sequence: installed v1.3.1-or-earlier direct app → Developer ID-signed/notarized final transition build → production App Store build. The later owner-gated test must cover bundle identifier and preferences/container migration, saved and dirty documents, the one-blank-document relaunch contract, recent files, security-scoped bookmarks, recovery, Help/Support/Privacy/Security routes, and update/migration guidance. Do not publish overwrite/removal instructions before the exact signed-build sequence is proven.

Record the current private-repository audit without changing external state: private Actions consumes the account allowance; current release publication and unauthenticated GitHub Releases cannot remain customer infrastructure; the unauthenticated `origin/main` fetch, CodeQL eligibility, environment protections, reusable workflows, and artifact retention require a real post-adaptation check; private GitHub artifact attestations require GitHub Enterprise Cloud and are internal provenance rather than customer trust. The repository-safe release record may preserve only the final direct release checksum, immutable commit/tag, release notes, and pass/fail status for signing, notarization, and stapling. Keep the Developer ID identity summary, Team/account identifiers, certificate details, notarization log, and other identifying evidence in an owner-approved private location outside every repository. If a valid historical public attestation bundle already exists before the workflow is removed, preserve it as optional private historical evidence; do not require or invent a final-transition attestation after the binding plan removes that workflow.

- [ ] **Step 8: Keep README concise and commit**

README may link to `docs/app-store-preparation.md` as a preparation document but must not claim Mac App Store availability, notarization, production signing, permanent public GitHub/SourceForge distribution, or an owner-approved public domain. Current direct-install instructions remain factual preparation-state documentation until the later cross-project link-migration gate replaces them.

```bash
git add docs/app-store-preparation.md README.md
git commit -m "docs: prepare bilingual App Store materials"
```

### Task 10: Capture and mechanically validate real English/German screenshots

**Files:**
- Create: `StoreAssets/Screenshots/en/01-menu-bar.png`
- Create: `StoreAssets/Screenshots/en/02-editor-tabs.png`
- Create: `StoreAssets/Screenshots/en/03-safe-conflict.png`
- Create: `StoreAssets/Screenshots/de/01-menu-bar.png`
- Create: `StoreAssets/Screenshots/de/02-editor-tabs.png`
- Create: `StoreAssets/Screenshots/de/03-safe-conflict.png`
- Create: `scripts/validate-store-screenshots.sh`
- Modify: `docs/app-store-preparation.md`

**Interfaces:**
- Consumes: the completed localized app and safe fixture documents.
- Produces: six real-app opaque screenshots at 1440×900 in sRGB PNG plus matching bilingual captions.

- [ ] **Step 1: Write the validator before capturing images**

The validator must fail because the six expected files are absent. It accepts only `.png`, `.jpg`, or `.jpeg`, requires exact 1440×900 dimensions, rejects alpha, verifies 16:10, rejects unexpected files, and scans visible fixture inputs for user names, local paths, email addresses, IP addresses, tokens, and private filenames. sRGB is a compatibility convention, not an asserted Apple requirement.

- [ ] **Step 2: Prepare safe local fixtures**

Use only `Welcome.txt`, `Tabs.txt`, and `Conflict-Safety.txt` with short product copy. Do not expose local paths, real recent files, personal data, browser content, certificates, or account details.

- [ ] **Step 3: Capture English screenshots from the real DirectRelease app**

Launch with Apple's language test argument, not an app-owned switch:

```bash
open -n build/MacPad.app --args -AppleLanguages '(en)'
```

Capture: menu-bar new-window access first; a clean editor with native tabs second; the external-change safety alert third.

- [ ] **Step 4: Capture German screenshots from the same app**

Relaunch with:

```bash
open -n build/MacPad.app --args -AppleLanguages '(de)'
```

Capture the same three scenarios. Confirm no clipped German text and localized VoiceOver labels before saving each file.

- [ ] **Step 5: Flatten and validate**

Use macOS image tools to place genuine captures on an opaque 1440×900 canvas without altering app UI content. Run:

```bash
./scripts/validate-store-screenshots.sh
```

Expected: 6/6 valid, 1440×900, 16:10, no alpha, no private content.

- [ ] **Step 6: Commit**

```bash
git add StoreAssets/Screenshots scripts/validate-store-screenshots.sh docs/app-store-preparation.md
git commit -m "assets: add bilingual Store screenshots"
```

### Task 11: Perform bilingual native-language and real sandbox smoke verification

**Files:**
- Create: `docs/verification/app-store-local-smoke.md`
- Modify only if a reproduced defect requires a failing regression test first.

**Interfaces:**
- Produces: exact commands, expected/actual results, timestamps, app hashes, and pass/fail/skip totals for the release candidate.

- [ ] **Step 1: Verify macOS recognizes both native app localizations**

Register the built app with Launch Services, open System Settings → General → Language & Region → Applications, add MacPad, and verify English and German are offered independently from the system language. Record this as a manual OS integration result, not an automated inference from catalog files.

- [ ] **Step 2: Verify safe language relaunch behavior**

With a saved open document and an edited dirty document, change the per-app language and relaunch. Verify the dirty document triggers the normal Save/Don't Save/Cancel owner choice before termination; choose Save and confirm content is preserved. After relaunch, verify exactly one blank document opens and the saved document remains available through Open Recent. Do not persist document text or document-session state in preferences.

- [ ] **Step 3: Record the signed Store sandbox sequence as authorization-gated**

All signing is prohibited in this task. Record the scenario as `SKIPPED-AUTHORIZATION`, with no candidate path or hash, until the owner separately authorizes a signed Store candidate. After that separate authorization, use a temporary external fixture directory and perform, in order:

```text
Open → edit → Save → quit → relaunch to one blank document → Open Recent → Save As → external modification → conflict alert → Reload → Print → menu-bar new document
```

Confirm bookmark refresh and access remain balanced, no dirty text is silently discarded, and inaccessible Open Recent entries fail clearly.

- [ ] **Step 4: Repeat in English and German**

Check menus, Find/Replace, alerts, About, status line, encoding accessory, document type, menu-bar tooltip, accessibility labels, keyboard navigation, and clipping. Record VoiceOver label values and any manual-only limitation.

- [ ] **Step 5: Reproduce any failure before editing**

For every discovered defect, add the smallest failing automated test or deterministic script check, verify RED, implement one root-cause fix, verify GREEN, then rerun the affected smoke segment. Do not bundle unrelated fixes.

- [ ] **Step 6: Commit smoke evidence**

```bash
git add docs/verification/app-store-local-smoke.md
git commit -m "test: document bilingual sandbox smoke results"
```

### Task 12: Run final verification, review, push, and open the protected-branch PR

**Files:**
- Modify: `CHANGELOG.md`
- Modify: issue comments and pull-request description externally after fresh local evidence.

**Interfaces:**
- Consumes: all prior tasks.
- Produces: verified branch, focused commits, PR, issue evidence, and owner/Apple gate matrix.

- [ ] **Step 1: Update current-state release documentation**

Add an Unreleased section describing English/German localization and Store preparation. Do not increment the app version or create a tag/release unless separately approved after merge.

```bash
git add CHANGELOG.md
git commit -m "docs: record localization and Store preparation"
```

- [ ] **Step 2: Run the complete repository checks**

Do not run `scripts/build-app.sh` or `scripts/package-release.sh` in this task because the direct-release path performs ad-hoc signing. Use only the unsigned Xcode and archive checks below while all signing remains prohibited.

```bash
git diff --check
plutil -lint Resources/Info.plist Resources/AppStore.entitlements
./scripts/verify-public-repo.sh
./scripts/check-localizations.sh
swift test --disable-sandbox
./scripts/app-store-preflight.sh
./scripts/validate-store-screenshots.sh
xcodebuild -project MacPad.xcodeproj -scheme MacPad-Direct -configuration DirectRelease -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
xcodebuild -project MacPad.xcodeproj -scheme MacPad-AppStore -configuration AppStore -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO SWIFT_TREAT_WARNINGS_AS_ERRORS=YES build
```

Record exact test pass/fail/skip totals, build exit codes, archive path, app version/build, architectures, entitlement keys, localization files, screenshot results, and SHA-256 values. Scan the Store `.app` executable and resources and fail if they contain `github.com`, `githubusercontent.com`, `sourceforge.net`, `anvilfilbert.github.io`, `deepwiki.com`, or `/releases/latest`. Separately test that Store About exposes no repository credit and Store menus expose no legacy route; direct engineering provenance outside the runtime bundle is not a customer route.

- [ ] **Step 3: Inspect artifacts and future repository-privacy readiness**

Verify the ZIP/archive contain the Apache-2.0 license, no local user paths, personal names, email addresses, IPs, serial numbers, credentials, profiles, certificates, Team IDs, or private notes. Confirm unrelated untracked workspace artifacts remain outside this task's diff. Verify the two binding cross-project documents are unchanged by this task.

Record, without mutating settings, whether the current release workflow has tag publication, unauthenticated private-incompatible fetches, public-only attestation, or GitHub Release customer dependencies; whether the current account plan supports private Actions, CodeQL, and attestations; and which checks must move to the later cross-project CI-adaptation gate. Do not claim the repository is privacy-ready merely because the current public workflow passes.

- [ ] **Step 4: Review the complete non-interactive diff**

```bash
git status --short --branch
git --no-pager diff --check main...HEAD
git --no-pager diff --stat main...HEAD
git --no-pager diff main...HEAD
```

Run a task-scoped review after every commit and one whole-branch review. Resolve every Critical or Important finding and rerun covering tests.

- [ ] **Step 5: Push without force and create the PR**

```bash
git push -u origin codex/localization-app-store-prep
gh pr create --repo anvilfilbert/MacPad --base main --head codex/localization-app-store-prep --title "Localize MacPad and prepare App Store builds" --body-file /private/tmp/macpad-localization-app-store-pr.md
```

Before the command, write `/private/tmp/macpad-localization-app-store-pr.md` with the exact Step 2 results under `Summary`, `Verification`, `Store evidence`, and `Owner gates`. The PR body links `Fixes #29` only if localization is complete and `Fixes #28` only if every repository-local readiness item is complete; otherwise use `Refs #28` and leave it open. The file must contain no unfilled template tokens.

- [ ] **Step 6: Wait for current protected checks and update issues**

Wait for every check currently required by branch protection and record its exact name and result. Do not assume current CodeQL/default-setup checks remain eligible after privatization; that is a later account-plan verification gate. Comment on #28 and #29 with exact tests, builds, archive, screenshots, localization completeness, route omissions, migration/private-CI readiness findings, and remaining owner gates. Close only genuinely complete work. Do not use admin merge without explicit approval.

- [ ] **Step 7: Deliver the readiness matrix**

Report every requirement as one of:

```text
Done
Owner decision
Apple-account blocked
Unverified
```

Explicitly stop before production bundle-ID selection, domain purchase or DNS/publication, Developer Program enrollment, Team/certificate/profile configuration, App Store Connect record creation, Paid Apps Agreement, tax/banking, final public URL adoption, Developer ID signing/notarization, direct transition publication, upload, TestFlight, App Review, Store publication, SourceForge mutation, CI plan purchase, or repository visibility change.

The delivery must also include issue, branch, commit, and PR links; an exact changed-file inventory; test/build totals; archive and screenshot locations; localization completeness; proposed identifiers; unresolved verification; and the user's next owner-gated actions in dependency order.

## Plan Self-Review

- **Spec coverage:** Tasks 2–4 cover complete native localization and direct packaging; Tasks 5–8 cover sandbox access, Xcode configurations, entitlements, icons, archives, and CI; Tasks 9–10 cover authoritative bilingual Store materials and screenshots; Tasks 11–12 cover native language behavior, real sandbox smoke, final verification, PR, and owner gates.
- **Placeholder scan:** No implementation step uses `TBD`, `TODO`, silent fallback, fake URL, invented Team ID, or invented production identifier. Explicit owner inputs are named as gates.
- **Type consistency:** `PersistedFileReference` flows through `SecurityScopedFileAccess`, `RecentDocumentStore`, and controller file state without becoming launch-session state. `DistributionChannel` and `CustomerRoutes` supply the single Store/direct policy used by menus, About, URL actions, artifact scanning, and bookmark requirements.
- **Scope check:** The work is large but cohesive: every task produces a reviewable MacPad distribution capability on the same branch without changing product behavior outside localization and sandbox-compatible file access.
- **Test coverage:** Every behavior change has a RED/GREEN automated test or deterministic artifact validator before implementation. Native System Settings integration, real sandbox panels, VoiceOver, printing, and screenshot content remain explicit manual OS smoke checks with recorded evidence.
- **Owner gates:** The plan completes safe repository-local work while stopping before all account, value-moving, credential, identifier, domain/URL, signing, upload, publication, SourceForge, CI-plan, and repository-visibility decisions. The binding cross-project sequence remains the authority for every later cutover action.
