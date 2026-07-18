# Changelog

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
