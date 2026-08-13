import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@Suite("Window routing")
@MainActor
struct WindowRoutingTests {
    @Test("main editor wins while a utility panel is key")
    func resolvesMainEditorBeforeFallback() {
        let mainEditor = EditorWindowController()
        let fallbackEditor = EditorWindowController()
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

        let editor = EditorWindowController()
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
            try EditorWindowResolver.makeController(opening: directory)
        }
    }

    @Test("a missing recent file fails before presentation")
    func rejectsMissingRecentFileBeforePresentation() {
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")

        #expect(throws: (any Error).self) {
            try EditorWindowResolver.makeController(opening: fileURL)
        }
    }

    @Test("standard document shortcuts keep distinct meanings")
    func standardDocumentShortcuts() throws {
        let application = NSApplication.shared
        let menu = MainMenuFactory.makeMenu(target: AppDelegate(), application: application)
        let newTab = try #require(menuItem(titled: "New Tab", in: menu))
        let newWindow = try #require(menuItem(titled: "New Window", in: menu))

        #expect(newTab.keyEquivalent == "t")
        #expect(newTab.keyEquivalentModifierMask == [.command])
        #expect(newTab.action == #selector(AppDelegate.openNewTab(_:)))
        #expect(newWindow.keyEquivalent == "n")
        #expect(newWindow.keyEquivalentModifierMask == [.command])
        #expect(newWindow.action == #selector(AppDelegate.openNewWindow(_:)))
    }

    @Test("File menu exposes native recent documents")
    func recentDocumentsMenu() throws {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        let menu = MainMenuFactory.makeMenu(target: delegate, application: application)
        let recentItem = try #require(menuItem(titled: "Open Recent", in: menu))
        let recentMenu = try #require(recentItem.submenu)

        #expect(recentMenu.delegate === delegate)
    }

    @Test("recent document menu routes files and clear command")
    func populatesRecentDocumentsMenu() throws {
        let target = AppDelegate()
        let menu = NSMenu(title: "Open Recent")
        let firstURL = URL(fileURLWithPath: "/tmp/first.txt")
        let secondURL = URL(fileURLWithPath: "/tmp/second.txt")

        RecentDocumentsMenuBuilder.populate(
            menu,
            urls: [firstURL, secondURL],
            target: target
        )

        #expect(menu.items[0].title == "first.txt")
        #expect(menu.items[0].representedObject as? URL == firstURL)
        #expect(menu.items[0].action == #selector(AppDelegate.openRecentDocument(_:)))
        #expect(menu.items[1].title == "second.txt")
        #expect(menu.items.last?.title == "Clear Menu")
        #expect(menu.items.last?.action == #selector(AppDelegate.clearRecentDocuments(_:)))
    }

    @Test("empty recent document menu has a disabled placeholder")
    func emptyRecentDocumentsMenu() throws {
        let menu = NSMenu(title: "Open Recent")

        RecentDocumentsMenuBuilder.populate(menu, urls: [], target: AppDelegate())

        let placeholder = try #require(menu.items.first)
        #expect(placeholder.title == "No Recent Documents")
        #expect(!placeholder.isEnabled)
    }

    @Test("successful saves report their final URL")
    func successfulSaveCallback() throws {
        let controller = EditorWindowController()
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
        let controller = EditorWindowController(baseFont: initialFont)

        controller.applyPreferredFont(replacementFont)

        let contentView = try #require(controller.window?.contentView)
        let editor = try #require(view(withIdentifier: "editor.text", in: contentView) as? NSTextView)
        #expect(editor.font?.fontName == replacementFont.fontName)
        #expect(editor.font?.pointSize == replacementFont.pointSize)
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
        let accessory = SaveEncodingAccessory(selectedEncoding: .utf8)

        #expect(accessory.picker.identifier?.rawValue == "save.encoding")
        #expect(accessory.picker.accessibilityLabel() == "Text encoding")
        #expect(accessory.selectedEncoding == .utf8)
    }

    @Test("menu has no duplicate keyboard shortcuts")
    func menuShortcutsAreUnique() {
        let application = NSApplication.shared
        let menu = MainMenuFactory.makeMenu(target: AppDelegate(), application: application)
        let shortcuts = allMenuItems(in: menu).compactMap { item -> String? in
            guard !item.keyEquivalent.isEmpty else { return nil }
            return "\(item.keyEquivalentModifierMask.rawValue):\(item.keyEquivalent)"
        }

        #expect(Set(shortcuts).count == shortcuts.count)
    }

    @Test("Help menu exposes documentation and support commands")
    func helpMenuCommands() throws {
        let application = NSApplication.shared
        let menu = MainMenuFactory.makeMenu(target: AppDelegate(), application: application)

        #expect(try #require(menuItem(titled: "MacPad Help", in: menu)).action == #selector(AppDelegate.openHelp(_:)))
        #expect(try #require(menuItem(titled: "Report an Issue", in: menu)).action == #selector(AppDelegate.reportIssue(_:)))
        #expect(try #require(menuItem(titled: "Check for Updates...", in: menu)).action == #selector(AppDelegate.checkForUpdates(_:)))
    }

    @Test("editor controls expose accessibility metadata and initial focus")
    func editorAccessibility() throws {
        let controller = EditorWindowController()
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

    private func menuItem(titled title: String, in menu: NSMenu) -> NSMenuItem? {
        allMenuItems(in: menu).first { $0.title == title }
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
}
