# MacPad Security Best Practices Report

## Executive Summary

MacPad has a small security surface: it is a native macOS plain-text editor with no network stack, no authentication, no server component, no database, and no third-party package dependencies. No critical or high-severity vulnerabilities were found in this review.

The main security concern is local privacy: session restore currently persists open tab contents and local file paths in `UserDefaults`. That is useful for recovery, but it means unsaved notes can remain on disk outside the user-selected document files. Two lower-priority hardening items are broad local file opening and release trust for public downloads.

Scope note: the requested `security-best-practices` skill has reference material for Python, JavaScript/TypeScript, and Go, but no Swift/AppKit-specific reference file. This report therefore uses repo inspection plus general desktop-app security review criteria.

## Critical Severity

No critical findings.

## High Severity

No high-severity findings.

## Medium Severity

### S-001: Session restore persists unsaved document text and file paths in plain local preferences

**Impact:** Any unsaved or sensitive text left in open MacPad tabs can be serialized into the app preferences store and retained on disk until the session is cleared or overwritten.

Evidence:

- `EditorSessionState` stores `filePath`, `text`, and `originalText` as codable fields in [Sources/NotepadMacCore/SessionState.swift](Sources/NotepadMacCore/SessionState.swift:47).
- `EditorDocument.sessionState(...)` writes the current editor text, original text, and file path into the session object in [Sources/NotepadMacCore/EditorDocument.swift](Sources/NotepadMacCore/EditorDocument.swift:72).
- `AppDelegate.saveSession()` encodes the session and stores it in `UserDefaults` under `MacPad.SessionState.v1` in [Sources/NotepadMac/AppDelegate.swift](Sources/NotepadMac/AppDelegate.swift:192).
- The README documents session restore for unsaved tab text in [README.md](README.md:44).

Why this matters:

`UserDefaults` is suitable for lightweight preferences, but it is not a secure store for private document content. This is a local privacy risk rather than a remote exploit, because another local process, backup, diagnostic bundle, or user with filesystem access could recover unsaved notes and local file paths from preferences.

Recommended fix:

Make full text session restore an explicit privacy tradeoff instead of the unconditional default. Lowest-risk options:

1. Restore window/tab layout by default, but do not persist unsaved document text.
2. Add a setting such as "Restore unsaved tab text" and default it off.
3. Add a "Clear Session Data" command that deletes the `MacPad.SessionState.v1` key.
4. If full restore remains enabled, document where the local session data is stored and what it can contain.

## Low Severity

### S-002: File open path accepts broad data files and reads them fully into memory

Evidence:

- The open panel allows `.plainText`, `.text`, and `.data` in [Sources/NotepadMac/AppDelegate.swift](Sources/NotepadMac/AppDelegate.swift:63).
- `EditorDocument.loadFile(_:)` reads the selected file with `Data(contentsOf:)` before decoding it in [Sources/NotepadMacCore/EditorDocument.swift](Sources/NotepadMacCore/EditorDocument.swift:35).

Why this matters:

Because file selection is user-driven, this is not a remote code execution issue. The practical risk is availability: accidentally opening a very large or binary file can allocate a large `Data` buffer, freeze the editor, or consume excessive memory.

Recommended fix:

Restrict the open panel to text UTTypes and add a file-size guard before reading. For example, read `URLResourceValues.fileSizeKey` and show a clear error for files above a conservative limit.

### S-003: Public release builds are ad-hoc signed and not notarized

Evidence:

- The build script signs with an ad-hoc identity via `codesign --sign -` in [scripts/build-app.sh](scripts/build-app.sh:34).
- The README tells users the app is locally signed but not Apple-notarized in [README.md](README.md:30).

Why this matters:

This is a distribution trust issue, not an app runtime vulnerability. Users downloading a ZIP from GitHub cannot rely on Apple notarization checks, and macOS will show unidentified-developer warnings.

Recommended fix:

If an Apple Developer account becomes acceptable later, sign and notarize release artifacts. If not, publish SHA-256 checksums with each GitHub release so users can verify ZIP integrity against the release notes.

## Informational Findings

### S-004: Repo hygiene and dependency surface are currently good

Evidence:

- The Swift package has no external package dependencies in [Package.swift](Package.swift:13).
- Build output, release ZIP output, and derived data are ignored in [.gitignore](.gitignore:1).
- The repository includes a security policy in [SECURITY.md](SECURITY.md:1).
- Dependabot is configured for Swift package checks in [.github/dependabot.yml](.github/dependabot.yml:1).
- A secret-pattern scan over tracked source and docs did not find API keys, private keys, GitHub tokens, or local `local home-directory` paths.

Recommended maintenance:

Keep generated app bundles and release archives out of git, continue using GitHub releases for binaries, and keep security reporting private through GitHub advisories or the owner contact path.

## Suggested Fix Order

1. Address S-001 first, because it is the only medium-severity finding and affects user privacy.
2. Address S-002 next with a small file-type and file-size guard.
3. Improve S-003 either through notarization or release checksums.

