import AppKit

@MainActor
enum MainMenuFactory {
    static func makeMenu(target: AnyObject) -> NSMenu {
        let mainMenu = NSMenu(title: "Main Menu")

        let appMenu = NSMenu(title: "MacPad")
        addItem("About MacPad", to: appMenu, action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), target: NSApp)
        appMenu.addItem(.separator())
        addItem("Quit MacPad", to: appMenu, action: #selector(NSApplication.terminate(_:)), target: NSApp, key: "q")
        let appRoot = NSMenuItem()
        appRoot.submenu = appMenu
        mainMenu.addItem(appRoot)

        let fileMenu = NSMenu(title: "File")
        addItem("New Tab", to: fileMenu, action: #selector(AppDelegate.openNewTab(_:)), target: target, key: "n")
        addItem("New Window", to: fileMenu, action: #selector(AppDelegate.openNewWindow(_:)), target: target, key: "n", modifiers: [.command, .shift])
        addItem("Open...", to: fileMenu, action: #selector(AppDelegate.openDocument(_:)), target: target, key: "o")
        addItem("Close", to: fileMenu, action: #selector(NSWindow.performClose(_:)), target: nil, key: "w")
        fileMenu.addItem(.separator())
        addItem("Save", to: fileMenu, action: #selector(AppDelegate.save(_:)), target: target, key: "s")
        addItem("Save As...", to: fileMenu, action: #selector(AppDelegate.saveAs(_:)), target: target, key: "S")
        fileMenu.addItem(.separator())
        addItem("Print...", to: fileMenu, action: #selector(AppDelegate.printDocument(_:)), target: target, key: "p")
        mainMenu.addItem(rootItem(for: fileMenu))

        let editMenu = NSMenu(title: "Edit")
        addItem("Undo", to: editMenu, action: Selector(("undo:")), target: nil, key: "z")
        addItem("Redo", to: editMenu, action: Selector(("redo:")), target: nil, key: "Z")
        editMenu.addItem(.separator())
        addItem("Cut", to: editMenu, action: #selector(NSText.cut(_:)), target: nil, key: "x")
        addItem("Copy", to: editMenu, action: #selector(NSText.copy(_:)), target: nil, key: "c")
        addItem("Paste", to: editMenu, action: #selector(NSText.paste(_:)), target: nil, key: "v")
        addItem("Delete", to: editMenu, action: #selector(NSText.delete(_:)), target: nil)
        editMenu.addItem(.separator())
        addItem("Find...", to: editMenu, action: #selector(AppDelegate.showFind(_:)), target: target, key: "f")
        addItem("Find Next", to: editMenu, action: #selector(AppDelegate.findNext(_:)), target: target, key: "g")
        addItem("Find Previous", to: editMenu, action: #selector(AppDelegate.findPrevious(_:)), target: target, key: "G")
        addItem("Replace...", to: editMenu, action: #selector(AppDelegate.showReplace(_:)), target: target, key: "h")
        addItem("Go To...", to: editMenu, action: #selector(AppDelegate.goToLine(_:)), target: target, key: "l")
        editMenu.addItem(.separator())
        addItem("Select All", to: editMenu, action: #selector(NSText.selectAll(_:)), target: nil, key: "a")
        addItem("Time/Date", to: editMenu, action: #selector(AppDelegate.insertTimeDate(_:)), target: target, key: "t", modifiers: [])
        mainMenu.addItem(rootItem(for: editMenu))

        let formatMenu = NSMenu(title: "Format")
        addItem("Word Wrap", to: formatMenu, action: #selector(AppDelegate.toggleWordWrap(_:)), target: target, key: "w", modifiers: [.command, .option])
        addItem("Font...", to: formatMenu, action: #selector(AppDelegate.chooseFont(_:)), target: target, key: "f", modifiers: [.command, .option])
        mainMenu.addItem(rootItem(for: formatMenu))

        let viewMenu = NSMenu(title: "View")
        addItem("Zoom In", to: viewMenu, action: #selector(AppDelegate.zoomIn(_:)), target: target, key: "+")
        addItem("Zoom Out", to: viewMenu, action: #selector(AppDelegate.zoomOut(_:)), target: target, key: "-")
        addItem("Restore Default Zoom", to: viewMenu, action: #selector(AppDelegate.restoreZoom(_:)), target: target, key: "0")
        viewMenu.addItem(.separator())
        addItem("Status Bar", to: viewMenu, action: #selector(AppDelegate.toggleStatusBar(_:)), target: target, key: "/", modifiers: [.command])
        mainMenu.addItem(rootItem(for: viewMenu))

        let windowMenu = NSMenu(title: "Window")
        addItem("Minimize", to: windowMenu, action: #selector(NSWindow.miniaturize(_:)), target: nil, key: "m")
        addItem("Zoom", to: windowMenu, action: #selector(NSWindow.performZoom(_:)), target: nil)
        windowMenu.addItem(.separator())
        addItem("Show Previous Tab", to: windowMenu, action: #selector(NSWindow.selectPreviousTab(_:)), target: nil, key: "[", modifiers: [.command, .shift])
        addItem("Show Next Tab", to: windowMenu, action: #selector(NSWindow.selectNextTab(_:)), target: nil, key: "]", modifiers: [.command, .shift])
        mainMenu.addItem(rootItem(for: windowMenu))
        NSApp.windowsMenu = windowMenu

        return mainMenu
    }

    private static func rootItem(for submenu: NSMenu) -> NSMenuItem {
        let item = NSMenuItem()
        item.submenu = submenu
        return item
    }

    @discardableResult
    private static func addItem(
        _ title: String,
        to menu: NSMenu,
        action: Selector?,
        target: AnyObject?,
        key: String = "",
        modifiers: NSEvent.ModifierFlags = [.command]
    ) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: action, keyEquivalent: key)
        item.target = target
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
        return item
    }
}
