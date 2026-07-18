# MacPad Security Best Practices Report

## Executive Summary

MacPad has a small security surface: it is a native macOS plain-text editor with no network stack, no authentication, no server component, no database, and no third-party package dependencies. No critical or high-severity vulnerabilities were found in this review, and the original review findings were addressed in version 1.0.7.

The main privacy change is that session restore no longer writes document text to `UserDefaults`. MacPad now stores tab/window metadata and saved file paths, then reloads saved-file tabs from disk. File opening is also narrower and guarded by a 25 MB size limit, and release packages include SHA-256 checksums.

Scope note: the requested `security-best-practices` skill has reference material for Python, JavaScript/TypeScript, and Go, but no Swift/AppKit-specific reference file. This report therefore uses repo inspection plus general desktop-app security review criteria.

## Critical Severity

No critical findings.

## High Severity

No high-severity findings.

## Medium Severity

### S-001: Session restore persisted unsaved document text in plain local preferences

Status: Remediated in 1.0.7.

Evidence:

- `EditorSessionState` now stores file path and UI metadata, but no document text fields, in [Sources/NotepadMacCore/SessionState.swift](Sources/NotepadMacCore/SessionState.swift:47).
- Encoding writes only metadata fields in [Sources/NotepadMacCore/SessionState.swift](Sources/NotepadMacCore/SessionState.swift:95).
- `EditorDocument.sessionState(...)` now creates session metadata without editor text in [Sources/NotepadMacCore/EditorDocument.swift](Sources/NotepadMacCore/EditorDocument.swift:104).
- Saved-file tabs are restored by loading the file from disk in [Sources/NotepadMacCore/EditorDocument.swift](Sources/NotepadMacCore/EditorDocument.swift:94).
- `File > Clear Session Data` removes the `MacPad.SessionState.v1` key in [Sources/NotepadMac/AppDelegate.swift](Sources/NotepadMac/AppDelegate.swift:75) and is exposed in [Sources/NotepadMac/MainMenuFactory.swift](Sources/NotepadMac/MainMenuFactory.swift:25).
- The README now states that session restore does not store document text in preferences in [README.md](README.md:46).

Why this matters:

`UserDefaults` is suitable for lightweight preferences, but it is not a secure store for private document content. The remediated design keeps restore metadata while avoiding persistence of unsaved note contents.

Remaining risk:

Saved file paths are still stored so MacPad can restore saved-file tabs. That is a reasonable feature tradeoff for this app, and users can clear it with `File > Clear Session Data`.

## Low Severity

### S-002: File open path accepts broad data files and reads them fully into memory

Status: Remediated in 1.0.7.

Evidence:

- The open panel now allows only `.plainText` and `.text` in [Sources/NotepadMac/AppDelegate.swift](Sources/NotepadMac/AppDelegate.swift:63).
- `EditorDocument.loadFile(_:)` validates file size before reading in [Sources/NotepadMacCore/EditorDocument.swift](Sources/NotepadMacCore/EditorDocument.swift:51).
- Files over 25 MB throw a clear error in [Sources/NotepadMacCore/EditorDocument.swift](Sources/NotepadMacCore/EditorDocument.swift:130).
- Files containing NUL bytes are rejected as unsupported plain text in [Sources/NotepadMacCore/EditorDocument.swift](Sources/NotepadMacCore/EditorDocument.swift:53).

Why this matters:

Because file selection is user-driven, this is not a remote code execution issue. The remediated behavior reduces accidental large/binary file opens and avoids avoidable memory pressure.

### S-003: Public release builds are ad-hoc signed and not notarized

Status: Partially remediated in 1.0.7.

Evidence:

- The build script signs with an ad-hoc identity via `codesign --sign -` in [scripts/build-app.sh](scripts/build-app.sh:34).
- The README tells users the app is locally signed but not Apple-notarized in [README.md](README.md:30).
- Release packaging now writes a `.sha256` checksum file beside the ZIP in [scripts/package-release.sh](scripts/package-release.sh:20).
- The README documents release checksum files in [README.md](README.md:30).

Why this matters:

This is a distribution trust issue, not an app runtime vulnerability. Users downloading a ZIP from GitHub cannot rely on Apple notarization checks, and macOS will show unidentified-developer warnings.

Remaining risk:

Checksums improve artifact integrity verification, but they do not replace Apple notarization. Full remediation still requires Developer ID signing and notarization if an Apple Developer account becomes acceptable later.

## Informational Findings

### S-004: Repo hygiene and dependency surface are currently good

Evidence:

- The Swift package has no external package dependencies in [Package.swift](Package.swift:13).
- Build output, release ZIP output, and derived data are ignored in [.gitignore](.gitignore:1).
- The repository includes a security policy in [SECURITY.md](SECURITY.md:1).
- Dependabot is configured for Swift package checks in [.github/dependabot.yml](.github/dependabot.yml:1).
- A secret-pattern scan over tracked source and docs did not find API keys, private keys, GitHub tokens, or local home-directory paths.

Recommended maintenance:

Keep generated app bundles and release archives out of git, continue using GitHub releases for binaries, and keep security reporting private through GitHub advisories or the owner contact path.

## Current Follow-Up

No critical, high, or medium security work remains from this review. The only remaining item is optional release notarization through Apple Developer ID signing.
