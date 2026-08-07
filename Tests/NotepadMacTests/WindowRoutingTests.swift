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
            onFindNext: { _ in },
            onFindPrevious: { _ in },
            onReplace: { _, _ in },
            onReplaceAll: { _, _ in }
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
        editor.loadFile(fileURL)

        let resolved = EditorWindowResolver.controller(
            opening: fileURL,
            controllers: [editor]
        )

        #expect(resolved === editor)
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

    private func menuItem(titled title: String, in menu: NSMenu) -> NSMenuItem? {
        allMenuItems(in: menu).first { $0.title == title }
    }

    private func allMenuItems(in menu: NSMenu) -> [NSMenuItem] {
        menu.items.flatMap { item in
            guard let submenu = item.submenu else { return [item] }
            return [item] + allMenuItems(in: submenu)
        }
    }
}
