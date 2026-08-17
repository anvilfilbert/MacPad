# Changelog

## Unreleased

- Changed the project license from GPL-3.0 to Apache-2.0.

## 1.2.0

- Added a native File > Open Recent menu with the standard Clear Menu command.
- Recorded only successfully opened or saved files, while preserving duplicate-open prevention and transactional file opening.
- Remembered the preferred editor font and size across launches, new windows, new tabs, and restored sessions.
- Validated persisted font settings and returned safely to the default monospaced font when saved settings are invalid or unavailable.
- Applied display-font changes without modifying document contents or dirty state.
- Added stable accessibility identifiers and explicit VoiceOver labels to the editor, status bar, Find and Replace, Save As encoding, and Go To Line controls.
- Added deterministic keyboard focus loops for the editor and Find and Replace panels.
- Expanded automated coverage to 55 core and AppKit tests.

## 1.1.0

- Added UTF-16 little-endian, UTF-16 big-endian, and Windows-1252 file support alongside UTF-8, UTF-8 BOM, and ISO-8859-1.
- Added an encoding selector to Save As, allowing documents to be converted safely to UTF-8 or another supported encoding.
- Prevented failed file opens from leaving an empty tab or window behind.
- Made line and column updates responsive in large documents by caching line locations and using binary search.
- Added Match Case and Wrap Around controls to Find and Replace.
- Restored window positions and selected tabs while keeping legacy session data compatible.
- Combined session-restore failures into one concise warning.
- Added live menu checkmarks for Word Wrap and Status Bar.
- Added Help, Report an Issue, and explicit Check for Updates commands.
- Expanded automated coverage to 42 core and AppKit tests.
- Improved contributor guidance, release-note automation, dependency-update grouping, and public documentation.

## 1.0.9

- Prevented saves from silently overwriting files changed by another app.
- Preserved symbolic-link targets, UTF-8 BOM, ISO-8859-1, and detected line endings without lossy conversion.
- Rejected oversized, special, and binary-like files before editor decoding.
- Reused an existing editor when Finder sends the same file more than once.
- Kept editor commands routed to the active document while Find, Replace, or Font panels are open.
- Prevented an empty Replace term from inserting replacement text.
- Debounced session metadata writes and removed silent session decoding failures.
- Fixed Go To Line bounds for documents ending with a newline.
- Added 23 automated core and AppKit regression tests.
- Added pinned GitHub Actions, universal package verification, stable latest-download assets, SHA-256 checksums, and build-provenance attestations.

## 1.0.8

- Fixed files opening twice when MacPad was launched from Finder or Open With.
- Changed New Tab to `Command-T` and New Window to `Command-N`.
- Changed Replace to `Option-Command-F`, restoring the standard `Command-H` Hide MacPad shortcut.
- Added standard Services, Hide, Show All, and Bring All to Front menu commands.
- Made Return activate Find Next in the Find and Replace dialogs.
- Made Replace All participate correctly in Undo.
- Added strict signature verification for packaged releases and locally installed app bundles.

## 1.0.7

- Stopped storing document text in session restore data; MacPad now restores saved-file tabs by reloading files from disk.
- Added File > Clear Session Data for manually removing saved session metadata.
- Restricted Open to text file types and added a 25 MB file-size guard before loading.
- Added SHA-256 checksum generation for release ZIPs.

## 1.0.6

- Fixed menu shortcut handling for `Save As`, `Redo`, and `Find Previous` by using explicit Shift modifiers.
- Changed `Time/Date` from plain `t` to `F5`, matching Notepad behavior and avoiding interference with typing.

## 1.0.5

- Moved creator and public repository attribution into the About MacPad panel.
- Removed that attribution from the README.

## 1.0.4

- Added a core editor document module for file identity, dirty state, line endings, save/load, and session snapshots.
- Cleaned the public repository surface.

## 1.0.3

- Added multi-window and multi-tab support.
- Added session restore for open windows and tab groups.
- Updated README screenshot and app logo presentation.
