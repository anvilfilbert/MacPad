# MacPad Security Best Practices Report

Review date: 2026-08-07
Release target: 1.0.9

## Executive Summary

MacPad is a native, offline macOS plain-text editor. It has no network client, authentication, server, database, analytics, or third-party Swift package dependencies. This review found no critical or high-severity vulnerabilities.

The 1.0.9 hardening closes the identified document-integrity, unsafe file-decoding, session-validation, command-routing, and release-provenance gaps. Twenty-three automated core and AppKit tests cover the relevant regressions.

## Resolved Findings

### S-001: A save could overwrite changes made by another application

Severity: Medium
Status: Fixed in 1.0.9

MacPad now records a SHA-256 digest when a file is loaded and verifies the current file immediately before saving. A mismatch stops the save and offers Save As, Reload from Disk, or Cancel. This avoids silently destroying another editor's changes.

Evidence:

- `Sources/NotepadMacCore/EditorDocument.swift`
- `Sources/NotepadMac/EditorWindowController.swift`
- `Tests/NotepadMacCoreTests/EditorDocumentTests.swift`

### S-002: Symbolic links and special files were not handled defensively

Severity: Medium
Status: Fixed in 1.0.9

File URLs are resolved before loading or saving, so editing a symbolic link updates its target rather than replacing the link. Reads use an open file descriptor plus `fstat`, require a regular file, enforce the 25 MB limit before and during reading, and reject directories and other special files.

Evidence:

- `Sources/NotepadMacCore/EditorDocument.swift`
- `Tests/NotepadMacCoreTests/EditorDocumentTests.swift`

### S-003: Arbitrary bytes could be treated as text and later converted silently

Severity: Medium
Status: Fixed in 1.0.9

MacPad accepts valid UTF-8, UTF-8 with a byte-order mark, or plausible ISO-8859-1 text. Binary-like control data is rejected. Saves preserve the detected encoding and line-ending mode, and fail explicitly rather than performing a lossy conversion.

Evidence:

- `Sources/NotepadMacCore/EditorDocument.swift`
- `Sources/NotepadMacCore/TextMetrics.swift`
- `Tests/NotepadMacCoreTests/EditorDocumentTests.swift`

### S-004: Session data validation and persistence were too permissive

Severity: Low
Status: Fixed in 1.0.9

Session decoding bounds window and tab collections while decoding, clamps cursor and zoom values, deletes malformed state with an explicit error, and stores only file paths and UI metadata. Text edits no longer rewrite session preferences on every keystroke; relevant metadata updates are debounced.

Evidence:

- `Sources/NotepadMacCore/SessionState.swift`
- `Sources/NotepadMac/AppDelegate.swift`
- `Tests/NotepadMacCoreTests/SessionStateTests.swift`

### S-005: Utility panels could redirect document commands

Severity: Low
Status: Fixed in 1.0.9

Find and Replace now use a non-main utility panel. Document commands resolve the main editor first, then the key or last active editor. Duplicate external open requests reuse the existing editor instead of opening the same file twice.

Evidence:

- `Sources/NotepadMac/AppDelegate.swift`
- `Sources/NotepadMac/FindPanelController.swift`
- `Tests/NotepadMacTests/WindowRoutingTests.swift`

### S-006: Release provenance and CI coverage were insufficient

Severity: Medium
Status: Fixed in 1.0.9

CI now runs the automated suite, scans tracked public content for common private-data and credential patterns, builds the universal release package, and verifies its signature, architectures, checksum, archive contents, and absence of local user paths. GitHub Actions use full commit SHA pins. Tagged releases repeat these checks and publish a GitHub build-provenance attestation.

Evidence:

- `.github/workflows/swift-ci.yml`
- `.github/workflows/release.yml`
- `.github/dependabot.yml`
- `scripts/verify-public-repo.sh`
- `scripts/package-release.sh`

## Accepted Distribution Constraint

### S-007: GitHub builds are ad-hoc signed and not Apple-notarized

Severity: Informational
Status: Accepted

The release is ad-hoc signed, checksum-verified, and attested by GitHub Actions, but it is not signed with an Apple Developer ID or notarized by Apple. Developer ID distribution requires paid Apple Developer Program membership and private signing credentials. README installation instructions disclose the resulting Gatekeeper warning.

## Repository Controls

- GitHub secret scanning, push protection, Dependabot security updates, branch protection, and required CI are enabled.
- Private vulnerability reporting is the supported security contact path.
- Workflows have read-only default permissions; the release workflow grants only the permissions needed for release assets and attestations.
- Generated app bundles, archives, and derived build output remain excluded from git.
- Session restore retains saved file paths but not document text; `File > Clear Session Data` removes that metadata.

## Maintenance

Run these checks before each release:

```sh
./scripts/verify-public-repo.sh
swift test
./scripts/package-release.sh
```
