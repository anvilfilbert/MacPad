<h1>
  MacPad
  <img src="Resources/MacPadLogo.png" alt="MacPad logo" width="52" align="center">
</h1>

[![Latest Release](https://img.shields.io/github/v/release/anvilfilbert/MacPad?label=release)](https://github.com/anvilfilbert/MacPad/releases/latest)
[![Build](https://github.com/anvilfilbert/MacPad/actions/workflows/swift-ci.yml/badge.svg)](https://github.com/anvilfilbert/MacPad/actions/workflows/swift-ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue)](LICENSE)
[![macOS](https://img.shields.io/badge/macOS-14%2B-blue)](Package.swift)

Ultra-fast native plain-text editor for macOS. No bloat.

## MacPad family

- [MacPad family website](https://macpad.net/) presents both apps.
- MacPad is the native macOS editor in this repository.
- [MacPad Mobile](https://macpad.net) is the native
  iPhone and iPad counterpart.

The apps are separate codebases and do not automatically synchronize open
documents, tabs, settings, or recovery data. Files stored in a shared location
can be opened explicitly from either app.

[![Ask DeepWiki](https://deepwiki.com/badge.svg)](https://deepwiki.com/anvilfilbert/MacPad)

<p align="center">
  <img src="Assets/MacPad-Review.png" alt="MacPad editor windows with tabs" width="760">
</p>

## Download

Download the latest ready-to-use universal app:

[Download the latest MacPad universal app](https://github.com/anvilfilbert/MacPad/releases/latest/download/MacPad-macOS-universal.zip)

Unzip it and drag `MacPad.app` into Applications. The [latest release page](https://github.com/anvilfilbert/MacPad/releases/latest) also provides release notes.

GitHub is the canonical download source. A synchronized mirror is available on [SourceForge](https://sourceforge.net/projects/macpad-editor/files/latest/download).

Each release includes a matching `.sha256` checksum and GitHub build-provenance attestation.

If macOS warns that the app is from an unidentified developer, right-click `MacPad.app`, choose **Open**, then confirm **Open**. The app is locally signed but not Apple-notarized.

## Latest Changes

`1.3.1` restores Dock reopening when menu-bar mode keeps MacPad running after the last editor window closes.

See [CHANGELOG.md](CHANGELOG.md) for full release history.

## App Store preparation

Repository-local English and German metadata drafts, privacy and support
copy, compliance evidence, and unresolved owner gates are tracked in
[App Store preparation](docs/app-store-preparation.md). This is preparation
material only: it does not mean MacPad has been production-signed, notarized,
submitted, approved, distributed, or published on the Mac App Store.

## Features

- Plain-text editing with native undo, cut, copy, paste, delete, and select all
- New Document, New Tab, New Window, open, Open Recent, save, save as, and print
- Multiple windows, each with multiple tabs
- New Document opens in the active tab group when one exists; New Window always stays separate
- Optional OFF-by-default menu-bar launcher for opening a new empty window with one click
- Every normal launch opens one new blank document; saved files remain available through Open Recent instead of reopening automatically
- Unsaved-change prompts when closing or quitting
- A native Find submenu with find, find next/previous, replace, and replace all controls using Match Case and Wrap Around options
- Standard shortcuts including `Command-N` for a new document, `Command-T` for a new tab, and `Option-Command-F` for Replace
- Go to line and insert current time/date
- Word wrap toggle
- App-wide persistent font chooser and per-tab zoom controls
- VoiceOver labels, stable accessibility identifiers, and predictable keyboard focus order
- Status bar showing line, column, zoom, line ending mode, and detected file encoding
- UTF-8, UTF-8 BOM, UTF-16 LE/BE, Windows-1252, and ISO-8859-1 detection, preservation, and Save As conversion
- Windows, Unix, classic Mac, and mixed line-ending detection and preservation
- Builds into a launchable universal `MacPad.app`
- Uses the included MacPad logo as the app icon

## Build

```sh
./scripts/build-app.sh
```

The app bundle is created at:

```text
build/MacPad.app
```

Launch it from Finder or with:

```sh
open build/MacPad.app
```

Install it into `/Applications` with:

```sh
./scripts/install-app.sh
```

Create a release zip with:

```sh
./scripts/package-release.sh
```

Run the automated suite with:

```sh
swift test
```

## Community

- Use [MacPad Support](https://macpad.net/support) for help and usage details; the route is a release gate until the approved site is live.
- Use [Discussions](https://github.com/anvilfilbert/MacPad/discussions) for questions and ideas.
- Open an [issue](https://github.com/anvilfilbert/MacPad/issues/new/choose) for a reproducible bug or focused feature request.
- See [CONTRIBUTING.md](CONTRIBUTING.md) before submitting a pull request.

## License

MacPad is available under the [Apache License 2.0](LICENSE).

## Security

Report vulnerabilities through [GitHub private vulnerability reporting](https://github.com/anvilfilbert/MacPad/security/advisories/new). See [SECURITY.md](SECURITY.md) for policy details.
