# Notepad for macOS

A small native macOS plain-text editor modeled after Windows `notepad.exe`.

## Features

- Plain-text editing with native undo, cut, copy, paste, delete, and select all
- New, open, save, save as, and print
- Unsaved-change prompts when closing or quitting
- Find, find next/previous, replace, and replace all
- Go to line and insert current time/date
- Word wrap toggle
- Font chooser and zoom controls
- Status bar showing line, column, zoom, wrap mode, and UTF-8
- Builds into a launchable `Notepad.app`

## Build

```sh
./scripts/build-app.sh
```

The app bundle is created at:

```text
build/Notepad.app
```

Launch it from Finder or with:

```sh
open build/Notepad.app
```

## Development

Run tests:

```sh
swift test
```
