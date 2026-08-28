import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@Suite("Window routing")
@MainActor
struct WindowRoutingTests {
    @Test("Open Recent uses a stable identifier")
    func openRecentUsesStableIdentifier() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization
        )

        let recentItem = try #require(menuItem(withIdentifier: "file.openRecent", in: menu))

        #expect(recentItem.submenu?.identifier?.rawValue == "file.openRecent")
    }

    @Test("German bundle values are wired into AppKit")
    func germanBundleValuesAreWiredIntoAppKit() throws {
        try withLocalization(
            languageCode: "de",
            strings: [
                MacPadStringKey.fileMenu.rawValue: "Ablage",
                MacPadStringKey.openRecent.rawValue: "Benutzte Dokumente",
                MacPadStringKey.showInMenuBar.rawValue: "MacPad in der Menüleiste anzeigen"
            ]
        ) { localization in
            let application = NSApplication.shared
            let delegate = appDelegate(localization: localization)
            let menu = MainMenuFactory.makeMenu(
                target: delegate,
                application: application,
                localization: localization
            )
            let menuBarItem = try #require(
                menuItem(withIdentifier: "view.menuBar", in: menu)
            )

            #expect(
                menuBarItem.title == localization.string(.showInMenuBar),
                "The AppKit menu must use the injected German bundle value."
            )
            let fileMenu = try #require(
                menuItem(withIdentifier: "menu.file", in: menu)?.submenu
            )
            #expect(fileMenu.title == "Ablage")
            #expect(
                menuItem(withIdentifier: "file.openRecent", in: menu)?.title
                    == "Benutzte Dokumente"
            )
        }
    }

    @Test("safety-critical menu commands use stable identifiers")
    func safetyCriticalMenuIdentifiers() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization
        )
        let expectedActions: [String: Selector] = [
            "file.save": #selector(AppDelegate.save(_:)),
            "file.saveAs": #selector(AppDelegate.saveAs(_:)),
            "file.clearSession": #selector(AppDelegate.clearSessionData(_:)),
            "view.menuBar": #selector(AppDelegate.toggleMenuBarVisibility(_:)),
            "help.checkUpdates": #selector(AppDelegate.checkForUpdates(_:))
        ]

        #expect(menuItem(withIdentifier: "menu.file", in: menu)?.submenu != nil)
        #expect(menuItem(withIdentifier: "file.openRecent", in: menu)?.submenu != nil)
        for (identifier, action) in expectedActions {
            #expect(
                try #require(menuItem(withIdentifier: identifier, in: menu)).action == action
            )
        }
    }

    @Test("German Find and Replace controls fit without clipping")
    func germanFindAndReplaceLayout() throws {
        try withLocalization(
            languageCode: "de",
            strings: germanFindTranslations
        ) { localization in
            let controller = FindPanelController(
                localization: localization,
                onFindNext: { _, _ in },
                onFindPrevious: { _, _ in },
                onReplace: { _, _, _ in },
                onReplaceAll: { _, _, _ in }
            )
            controller.show(initialTerm: "MacPad", showReplace: true)
            defer { controller.close() }

            let window = try #require(controller.window)
            let contentView = try #require(window.contentView)
            contentView.layoutSubtreeIfNeeded()

            #expect(window.title == "Ersetzen")
            #expect(window.contentMinSize == NSSize(width: 500, height: 204))
            #expect(window.contentLayoutRect.width >= 500)
            #expect(window.contentLayoutRect.height >= 204)
            #expect(
                view(withIdentifier: "find.term", in: contentView)?.accessibilityLabel()
                    == "Suchtext"
            )
            #expect(
                view(withIdentifier: "find.replacement", in: contentView)?.accessibilityLabel()
                    == "Ersatztext"
            )

            let visibleIdentifiers = [
                "find.grid",
                "find.termLabel",
                "find.term",
                "find.replacementLabel",
                "find.replacement",
                "find.next",
                "find.previous",
                "find.replace",
                "find.replaceAll",
                "find.matchCase",
                "find.wrapAround"
            ]
            let visibleViews = try visibleIdentifiers.map { identifier in
                (
                    identifier,
                    try #require(view(withIdentifier: identifier, in: contentView))
                )
            }
            let grid = try #require(
                view(withIdentifier: "find.grid", in: contentView) as? NSGridView
            )
            #expect(!contentView.hasAmbiguousLayout)
            #expect(!grid.hasAmbiguousLayout)
            for (identifier, visibleView) in visibleViews {
                #expect(!visibleView.hasAmbiguousLayout, "Ambiguous layout: \(identifier)")
                let frame = visibleView.convert(visibleView.bounds, to: contentView)
                #expect(contentView.bounds.contains(frame))
            }
            let visibleButtons = visibleViews.compactMap { $0.1 as? NSButton }
            for button in visibleButtons {
                #expect(button.frame.width + 1 >= button.intrinsicContentSize.width)
            }
            let visibleLabels = visibleViews.compactMap { $0.1 as? NSTextField }
                .filter { !$0.isEditable }
            for label in visibleLabels {
                #expect(label.frame.width + 1 >= label.intrinsicContentSize.width)
            }
        }
    }

    @Test("German editor values cross the injected localization boundary")
    func germanEditorValues() throws {
        try withLocalization(
            languageCode: "de",
            strings: [
                MacPadStringKey.untitled.rawValue: "Ohne Titel",
                MacPadStringKey.windowTitle.rawValue: "%1$@ - MacPad",
                MacPadStringKey.documentText.rawValue: "Dokumenttext",
                MacPadStringKey.documentStatus.rawValue: "Dokumentstatus",
                MacPadStringKey.statusLine.rawValue:
                    "Z. %1$lld, Sp. %2$lld  |  %3$lld%%  |  %4$@  |  %5$@",
                MacPadStringKey.windowsLineEnding.rawValue: "Windows (CRLF)",
                MacPadStringKey.utf8Encoding.rawValue: "UTF-8"
            ]
        ) { localization in
            let controller = EditorWindowController(localization: localization)
            let contentView = try #require(controller.window?.contentView)
            let editor = try #require(view(withIdentifier: "editor.text", in: contentView))
            let status = try #require(
                view(withIdentifier: "editor.status", in: contentView) as? NSTextField
            )

            #expect(controller.window?.title == "Ohne Titel - MacPad")
            #expect(editor.accessibilityLabel() == "Dokumenttext")
            #expect(status.accessibilityLabel() == "Dokumentstatus")
            #expect(status.stringValue.hasPrefix("Z. 1, Sp. 1"))
        }
    }

    @Test("main editor wins while a utility panel is key")
    func resolvesMainEditorBeforeFallback() {
        let mainEditor = EditorWindowController(localization: englishLocalization)
        let fallbackEditor = EditorWindowController(localization: englishLocalization)
        let utilityPanel = NSPanel()

        let resolved = EditorWindowResolver.resolve(
            controllers: [mainEditor, fallbackEditor],
            mainWindow: mainEditor.window,
            keyWindow: utilityPanel,
            lastActive: fallbackEditor
        )

        #expect(resolved === mainEditor)
    }

    @Test("find window is a non-main utility panel")
    func findUsesUtilityPanel() {
        let controller = FindPanelController(
            localization: englishLocalization,
            onFindNext: { _, _ in },
            onFindPrevious: { _, _ in },
            onReplace: { _, _, _ in },
            onReplaceAll: { _, _, _ in }
        )

        #expect(controller.window is NSPanel)
        #expect(controller.window?.canBecomeMain == false)
    }

    @Test("an already open file resolves to its existing editor")
    func resolvesExistingFile() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let fileURL = directory.appendingPathComponent("note.txt")
        try Data("MacPad".utf8).write(to: fileURL)

        let editor = EditorWindowController(localization: englishLocalization)
        try editor.loadFile(fileURL)

        let resolved = EditorWindowResolver.controller(
            opening: fileURL,
            controllers: [editor]
        )

        #expect(resolved === editor)
    }

    @Test("controller preparation throws before a failed file is presented")
    func rejectsInvalidFileBeforePresentation() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        #expect(throws: (any Error).self) {
            try EditorWindowResolver.makeController(
                opening: directory,
                localization: englishLocalization
            )
        }
    }

    @Test("a missing recent file fails before presentation")
    func rejectsMissingRecentFileBeforePresentation() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        #expect(throws: (any Error).self) {
            try EditorWindowResolver.makeController(
                opening: fileURL,
                localization: englishLocalization
            )
        }
    }

    @Test("standard document shortcuts keep distinct meanings")
    func standardDocumentShortcuts() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization
        )
        let newTab = try #require(menuItem(withIdentifier: "file.newTab", in: menu))
        let newWindow = try #require(menuItem(withIdentifier: "file.newWindow", in: menu))

        #expect(newTab.keyEquivalent == "t")
        #expect(newTab.keyEquivalentModifierMask == [.command])
        #expect(newTab.action == #selector(AppDelegate.openNewTab(_:)))
        #expect(newWindow.keyEquivalent == "n")
        #expect(newWindow.keyEquivalentModifierMask == [.command])
        #expect(newWindow.action == #selector(AppDelegate.openNewWindow(_:)))
    }

    @Test("View menu exposes the optional menu-bar launcher")
    func menuBarLauncherCommand() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization
        )
        let item = try #require(menuItem(withIdentifier: "view.menuBar", in: menu))

        #expect(item.action == #selector(AppDelegate.toggleMenuBarVisibility(_:)))
        #expect(item.state == .off)
    }

    @Test("menu-bar launcher is off by default and keeps the app running when enabled")
    func menuBarLauncherPreference() throws {
        let suiteName = "MacPadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let delegate = AppDelegate(defaults: defaults, localization: englishLocalization)

        #expect(!delegate.isMenuBarEnabled)
        #expect(delegate.menuBarStatusItem == nil)
        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(.shared))

        delegate.toggleMenuBarVisibility(nil)

        #expect(delegate.isMenuBarEnabled)
        let statusItem = try #require(delegate.menuBarStatusItem)
        #expect(statusItem.button?.action == #selector(AppDelegate.handleMenuBarStatusItem(_:)))
        #expect(!delegate.applicationShouldTerminateAfterLastWindowClosed(.shared))
        #expect(
            AppDelegate(defaults: defaults, localization: englishLocalization).isMenuBarEnabled
        )

        delegate.handleMenuBarStatusItem(nil)
        #expect(delegate.editorWindowCount == 1)

        delegate.toggleMenuBarVisibility(nil)

        #expect(!delegate.isMenuBarEnabled)
        #expect(delegate.menuBarStatusItem == nil)
        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(.shared))
        #expect(delegate.editorWindowCount == 1)
    }

    @Test("Dock reopen creates an editor after the last window closes")
    func dockReopenWithoutVisibleWindows() throws {
        let suiteName = "MacPadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let delegate = AppDelegate(defaults: defaults, localization: englishLocalization)
        delegate.toggleMenuBarVisibility(nil)
        defer {
            if delegate.isMenuBarEnabled {
                delegate.toggleMenuBarVisibility(nil)
            }
        }
        let applicationDelegate: any NSApplicationDelegate = delegate

        let handled = applicationDelegate.applicationShouldHandleReopen?(
            .shared,
            hasVisibleWindows: false
        )

        #expect(handled == false)
        #expect(delegate.editorWindowCount == 1)
    }

    @Test("disabling menu-bar mode without an editor restores a normal window")
    func disablingMenuBarWithoutWindow() throws {
        let suiteName = "MacPadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let delegate = AppDelegate(defaults: defaults, localization: englishLocalization)

        delegate.toggleMenuBarVisibility(nil)
        #expect(delegate.editorWindowCount == 0)

        delegate.toggleMenuBarVisibility(nil)
        #expect(delegate.editorWindowCount == 1)
    }

    @Test("activating a tab group moves the complete group to the recent end")
    func windowGroupRecency() throws {
        let first = EditorWindowController(localization: englishLocalization)
        let second = EditorWindowController(localization: englishLocalization)
        let third = EditorWindowController(localization: englishLocalization)
        let firstWindow = try #require(first.window)
        let secondWindow = try #require(second.window)
        firstWindow.addTabbedWindow(secondWindow, ordered: .above)

        let reordered = EditorWindowRecency.movingWindowGroupToEnd(
            containing: first,
            in: [first, second, third]
        )

        #expect(reordered.count == 3)
        #expect(reordered[0] === third)
        #expect(reordered[1] === second)
        #expect(reordered[2] === first)

        let secondReordered = EditorWindowRecency.movingWindowGroupToEnd(
            containing: second,
            in: reordered
        )
        #expect(secondReordered[0] === third)
        #expect(secondReordered[1] === first)
        #expect(secondReordered[2] === second)
    }

    @Test("File menu exposes native recent documents")
    func recentDocumentsMenu() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization
        )
        let recentItem = try #require(menuItem(withIdentifier: "file.openRecent", in: menu))
        let recentMenu = try #require(recentItem.submenu)

        #expect(recentMenu.delegate === delegate)
    }

    @Test("recent document menu routes files and clear command")
    func populatesRecentDocumentsMenu() throws {
        let target = appDelegate(localization: englishLocalization)
        let menu = NSMenu(title: "Open Recent")
        let firstURL = URL(fileURLWithPath: "/tmp/first.txt")
        let secondURL = URL(fileURLWithPath: "/tmp/second.txt")

        RecentDocumentsMenuBuilder.populate(
            menu,
            urls: [firstURL, secondURL],
            target: target,
            localization: englishLocalization
        )

        #expect(menu.items[0].title == "first.txt")
        #expect(menu.items[0].representedObject as? URL == firstURL)
        #expect(menu.items[0].action == #selector(AppDelegate.openRecentDocument(_:)))
        #expect(menu.items[1].title == "second.txt")
        let clearItem = try #require(
            menu.items.first { $0.identifier?.rawValue == "file.clearRecentMenu" }
        )
        #expect(clearItem.title == "Clear Menu")
        #expect(clearItem.action == #selector(AppDelegate.clearRecentDocuments(_:)))
    }

    @Test("empty recent document menu has a disabled placeholder")
    func emptyRecentDocumentsMenu() throws {
        let menu = NSMenu(title: "Open Recent")

        RecentDocumentsMenuBuilder.populate(
            menu,
            urls: [],
            target: appDelegate(localization: englishLocalization),
            localization: englishLocalization
        )

        let placeholder = try #require(menu.items.first)
        #expect(placeholder.title == "No Recent Documents")
        #expect(!placeholder.isEnabled)
    }

    @Test("successful saves report their final URL")
    func successfulSaveCallback() throws {
        let controller = EditorWindowController(localization: englishLocalization)
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        var reportedURL: URL?
        controller.onSuccessfulSave = { reportedURL = $0 }

        try controller.saveDocument(to: fileURL, encoding: .utf8)

        #expect(reportedURL == fileURL.resolvingSymlinksInPath().standardizedFileURL)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("preferred fonts apply without marking the document edited")
    func appliesPreferredFont() throws {
        let initialFont = try #require(NSFont(name: "Menlo-Regular", size: 14))
        let replacementFont = try #require(NSFont(name: "Courier", size: 16))
        let controller = EditorWindowController(
            baseFont: initialFont,
            localization: englishLocalization
        )

        controller.applyPreferredFont(replacementFont)

        let contentView = try #require(controller.window?.contentView)
        let editor = try #require(view(withIdentifier: "editor.text", in: contentView) as? NSTextView)
        #expect(editor.font?.fontName == replacementFont.fontName)
        #expect(editor.font?.pointSize == replacementFont.pointSize)
        #expect(controller.window?.isDocumentEdited == false)
    }

    @Test("text changes defer line-index rebuilding off the editing path")
    func defersLineIndexRebuild() async throws {
        let controller = EditorWindowController(localization: englishLocalization)
        let contentView = try #require(controller.window?.contentView)
        let editor = try #require(view(withIdentifier: "editor.text", in: contentView) as? NSTextView)
        let status = try #require(view(withIdentifier: "editor.status", in: contentView) as? NSTextField)
        let lineCount = 100_000
        let text = String(repeating: "line\n", count: lineCount)
        editor.string = text
        editor.setSelectedRange(NSRange(location: 495, length: 0))

        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))

        #expect(status.stringValue.hasPrefix("Ln 1,"))
        await controller.waitForPendingTextAnalysis()
        #expect(status.stringValue.hasPrefix("Ln 100,"))
    }

    @Test("rapid edits apply only the newest background text analysis")
    func coalescesLineIndexRebuilds() async throws {
        let controller = EditorWindowController(localization: englishLocalization)
        let contentView = try #require(controller.window?.contentView)
        let editor = try #require(view(withIdentifier: "editor.text", in: contentView) as? NSTextView)
        let status = try #require(view(withIdentifier: "editor.status", in: contentView) as? NSTextField)

        editor.string = String(repeating: "stale\n", count: 100_000)
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        editor.string = "one\ntwo"
        editor.setSelectedRange(NSRange(location: 7, length: 0))
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))

        await controller.waitForPendingTextAnalysis()

        #expect(status.stringValue.hasPrefix("Ln 2, Col 4"))
    }

    @Test("returning to the original text clears dirty state after analysis")
    func reconcilesDirtyStateOffTheEditingPath() async throws {
        let controller = EditorWindowController(localization: englishLocalization)
        let contentView = try #require(controller.window?.contentView)
        let editor = try #require(view(withIdentifier: "editor.text", in: contentView) as? NSTextView)

        editor.string = "changed"
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        #expect(controller.window?.isDocumentEdited == true)

        editor.string = ""
        controller.textDidChange(Notification(name: NSText.didChangeNotification, object: editor))
        #expect(controller.window?.isDocumentEdited == true)
        await controller.waitForPendingTextAnalysis()

        #expect(controller.window?.isDocumentEdited == false)
    }

    @Test("editor font persists through isolated user defaults")
    func persistsPreferredFont() throws {
        let suiteName = "MacPadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let font = try #require(NSFont(name: "Menlo-Regular", size: 15))

        try EditorFontPreferences.save(font, to: defaults)
        let restoredFont = try #require(try EditorFontPreferences.load(from: defaults))

        #expect(restoredFont.fontName == font.fontName)
        #expect(restoredFont.pointSize == font.pointSize)
    }

    @Test("Save As encoding control exposes VoiceOver metadata")
    func saveEncodingAccessibility() {
        let accessory = SaveEncodingAccessory(
            selectedEncoding: .utf8,
            localization: englishLocalization
        )

        #expect(accessory.picker.identifier?.rawValue == "save.encoding")
        #expect(accessory.picker.accessibilityLabel() == "Text encoding")
        #expect(accessory.selectedEncoding == .utf8)
    }

    @Test("menu has no duplicate keyboard shortcuts")
    func menuShortcutsAreUnique() {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization
        )
        let shortcuts = allMenuItems(in: menu).compactMap { item -> String? in
            guard !item.keyEquivalent.isEmpty else { return nil }
            return "\(item.keyEquivalentModifierMask.rawValue):\(item.keyEquivalent)"
        }

        #expect(Set(shortcuts).count == shortcuts.count)
    }

    @Test("Help menu exposes documentation and support commands")
    func helpMenuCommands() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization
        )

        #expect(
            try #require(menuItem(withIdentifier: "help.macPadHelp", in: menu)).action
                == #selector(AppDelegate.openHelp(_:))
        )
        #expect(
            try #require(menuItem(withIdentifier: "help.reportIssue", in: menu)).action
                == #selector(AppDelegate.reportIssue(_:))
        )
        #expect(
            try #require(menuItem(withIdentifier: "help.checkUpdates", in: menu)).action
                == #selector(AppDelegate.checkForUpdates(_:))
        )
    }

    @Test("editor controls expose accessibility metadata and initial focus")
    func editorAccessibility() throws {
        let controller = EditorWindowController(localization: englishLocalization)
        let contentView = try #require(controller.window?.contentView)
        let editor = try #require(view(withIdentifier: "editor.text", in: contentView))
        let status = try #require(view(withIdentifier: "editor.status", in: contentView))

        #expect(editor.accessibilityLabel() == "Document text")
        #expect(status.accessibilityLabel() == "Document status")
        #expect(controller.window?.initialFirstResponder === editor)
    }

    @Test("Find controls expose accessibility metadata and keyboard order")
    func findAccessibility() throws {
        let controller = FindPanelController(
            localization: englishLocalization,
            onFindNext: { _, _ in },
            onFindPrevious: { _, _ in },
            onReplace: { _, _, _ in },
            onReplaceAll: { _, _, _ in }
        )
        let contentView = try #require(controller.window?.contentView)
        controller.show(initialTerm: "MacPad", showReplace: true)
        defer { controller.close() }

        let findField = try #require(view(withIdentifier: "find.term", in: contentView))
        let replaceField = try #require(view(withIdentifier: "find.replacement", in: contentView))
        let matchCase = try #require(view(withIdentifier: "find.matchCase", in: contentView))
        let wrapAround = try #require(view(withIdentifier: "find.wrapAround", in: contentView))
        let findNext = try #require(view(withIdentifier: "find.next", in: contentView))
        let findPrevious = try #require(view(withIdentifier: "find.previous", in: contentView))
        let replace = try #require(view(withIdentifier: "find.replace", in: contentView))
        let replaceAll = try #require(view(withIdentifier: "find.replaceAll", in: contentView))

        #expect(findField.accessibilityLabel() == "Find what")
        #expect(replaceField.accessibilityLabel() == "Replace with")
        #expect(controller.window?.initialFirstResponder === findField)
        #expect(findField.nextKeyView === replaceField)
        #expect(replaceField.nextKeyView === matchCase)
        #expect(matchCase.nextKeyView === wrapAround)
        #expect(wrapAround.nextKeyView === findNext)
        #expect(findNext.nextKeyView === findPrevious)
        #expect(findPrevious.nextKeyView === replace)
        #expect(replace.nextKeyView === replaceAll)
        #expect(replaceAll.nextKeyView === findField)
    }

    private func menuItem(withIdentifier identifier: String, in menu: NSMenu) -> NSMenuItem? {
        allMenuItems(in: menu).first { $0.identifier?.rawValue == identifier }
    }

    private func allMenuItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { item in
            guard let submenu = item.submenu else { return [item] }
            return [item] + allMenuItems(in: submenu)
        }
    }

    private func allViews(in view: NSView) -> [NSView] {
        [view] + view.subviews.flatMap(allViews(in:))
    }

    private func view(withIdentifier identifier: String, in view: NSView) -> NSView? {
        allViews(in: view).first { $0.identifier?.rawValue == identifier }
    }

    private var englishLocalization: MacPadLocalization {
        MacPadLocalization(bundle: .main)
    }

    private var germanFindTranslations: [String: String] {
        [
            MacPadStringKey.findTitle.rawValue: "Suchen",
            MacPadStringKey.replaceTitle.rawValue: "Ersetzen",
            MacPadStringKey.findWhat.rawValue: "Suchen nach:",
            MacPadStringKey.replaceWith.rawValue: "Ersetzen durch:",
            MacPadStringKey.findWhatAccessibilityLabel.rawValue: "Suchtext",
            MacPadStringKey.replaceWithAccessibilityLabel.rawValue: "Ersatztext",
            MacPadStringKey.findNext.rawValue: "Weitersuchen",
            MacPadStringKey.findPrevious.rawValue: "Rückwärts suchen",
            MacPadStringKey.replace.rawValue: "Ersetzen …",
            MacPadStringKey.replaceAll.rawValue: "Alle ersetzen",
            MacPadStringKey.matchCase.rawValue: "Groß-/Kleinschreibung beachten",
            MacPadStringKey.wrapAround.rawValue: "Am Dokumentende weitersuchen"
        ]
    }

    private func appDelegate(localization: MacPadLocalization) -> AppDelegate {
        AppDelegate(defaults: .standard, localization: localization)
    }

    private func withLocalization<Result>(
        languageCode: String,
        strings: [String: String],
        body: (MacPadLocalization) throws -> Result
    ) throws -> Result {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("MacPadLocalization.bundle", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                Issue.record(error)
            }
        }

        let contents = root.appendingPathComponent("Contents", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let localizationDirectory = resources.appendingPathComponent(
            "\(languageCode).lproj",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: localizationDirectory,
            withIntermediateDirectories: true
        )

        let info = LocalizationBundleInfo(
            developmentRegion: languageCode,
            identifier: "local.macpad.tests.localization.\(UUID().uuidString)",
            localizations: [languageCode],
            packageType: "BNDL"
        )
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        try encoder.encode(info).write(
            to: contents.appendingPathComponent("Info.plist"),
            options: .atomic
        )
        try encoder.encode(strings).write(
            to: localizationDirectory.appendingPathComponent("Localizable.strings"),
            options: .atomic
        )

        let bundle = try #require(Bundle(path: root.path))
        return try body(MacPadLocalization(bundle: bundle))
    }
}

private struct LocalizationBundleInfo: Encodable {
    let developmentRegion: String
    let identifier: String
    let localizations: [String]
    let packageType: String

    private enum CodingKeys: String, CodingKey {
        case developmentRegion = "CFBundleDevelopmentRegion"
        case identifier = "CFBundleIdentifier"
        case localizations = "CFBundleLocalizations"
        case packageType = "CFBundlePackageType"
    }
}
