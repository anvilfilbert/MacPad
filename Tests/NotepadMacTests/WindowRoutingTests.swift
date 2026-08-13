import AppKit
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

    @Test("Find controls expose stable accessibility identifiers")
    func findAccessibilityIdentifiers() throws {
        let controller = FindPanelController(
            onFindNext: { _, _ in },
            onFindPrevious: { _, _ in },
            onReplace: { _, _, _ in },
            onReplaceAll: { _, _, _ in }
        )
        let contentView = try #require(controller.window?.contentView)
        let identifiers = Set(allViews(in: contentView).compactMap(\.identifier?.rawValue))

        #expect(identifiers.contains("find.term"))
        #expect(identifiers.contains("find.replacement"))
        #expect(identifiers.contains("find.matchCase"))
        #expect(identifiers.contains("find.wrapAround"))
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
}
