import AppKit
import NotepadMacCore

@MainActor
enum RecentDocumentsMenuBuilder {
    static func populate(
        _ menu: NSMenu,
        references: [PersistedFileReference],
        target: AnyObject,
        localization: MacPadLocalization
    ) {
        menu.removeAllItems()

        if references.isEmpty {
            let placeholder = NSMenuItem(
                title: localization.string(.noRecentDocuments),
                action: nil,
                keyEquivalent: ""
            )
            placeholder.identifier = NSUserInterfaceItemIdentifier(
                MacPadStringKey.noRecentDocuments.rawValue
            )
            placeholder.isEnabled = false
            menu.addItem(placeholder)
        } else {
            for reference in references {
                let url = URL(fileURLWithPath: reference.path)
                let item = NSMenuItem(
                    title: url.lastPathComponent,
                    action: #selector(AppDelegate.openRecentDocument(_:)),
                    keyEquivalent: ""
                )
                item.target = target
                item.representedObject = reference
                item.toolTip = url.path
                menu.addItem(item)
            }
        }

        addClearItem(
            to: menu,
            enabled: !references.isEmpty,
            target: target,
            localization: localization
        )
    }

    static func populateUnavailable(
        _ menu: NSMenu,
        target: AnyObject,
        localization: MacPadLocalization
    ) {
        menu.removeAllItems()
        let placeholder = NSMenuItem(
            title: localization.string(.recentDocumentsUnavailable),
            action: nil,
            keyEquivalent: ""
        )
        placeholder.identifier = NSUserInterfaceItemIdentifier(
            MacPadStringKey.recentDocumentsUnavailable.rawValue
        )
        placeholder.isEnabled = false
        menu.addItem(placeholder)
        addClearItem(
            to: menu,
            enabled: true,
            target: target,
            localization: localization
        )
    }

    private static func addClearItem(
        to menu: NSMenu,
        enabled: Bool,
        target: AnyObject,
        localization: MacPadLocalization
    ) {
        menu.addItem(.separator())
        let clearItem = NSMenuItem(
            title: localization.string(.clearRecentMenu),
            action: #selector(AppDelegate.clearRecentDocuments(_:)),
            keyEquivalent: ""
        )
        clearItem.identifier = NSUserInterfaceItemIdentifier(
            MacPadStringKey.clearRecentMenu.rawValue
        )
        clearItem.target = target
        clearItem.isEnabled = enabled
        menu.addItem(clearItem)
    }
}

@MainActor
enum MainMenuFactory {
    static func makeMenu(
        target: AnyObject,
        application: NSApplication,
        localization: MacPadLocalization,
        distributionChannel: DistributionChannel,
        customerRoutes: CustomerRoutes
    ) -> NSMenu {
        let mainMenu = NSMenu(title: localization.string(.mainMenu))
        mainMenu.identifier = NSUserInterfaceItemIdentifier(MacPadStringKey.mainMenu.rawValue)

        let appMenu = NSMenu(title: "MacPad")
        addItem(.aboutMacPad, MacPadStringKey.aboutMacPad.rawValue, appMenu, #selector(AppDelegate.showAbout(_:)), target, "", [.command], localization)
        appMenu.addItem(.separator())
        let servicesMenu = NSMenu(title: localization.string(.services))
        servicesMenu.identifier = NSUserInterfaceItemIdentifier(
            MacPadStringKey.services.rawValue
        )
        let servicesItem = NSMenuItem(
            title: localization.string(.services),
            action: nil,
            keyEquivalent: ""
        )
        servicesItem.identifier = NSUserInterfaceItemIdentifier(
            MacPadStringKey.services.rawValue
        )
        servicesItem.submenu = servicesMenu
        appMenu.addItem(servicesItem)
        application.servicesMenu = servicesMenu
        appMenu.addItem(.separator())
        addItem(.hideMacPad, MacPadStringKey.hideMacPad.rawValue, appMenu, #selector(NSApplication.hide(_:)), application, "h", [.command], localization)
        addItem(.hideOthers, MacPadStringKey.hideOthers.rawValue, appMenu, #selector(NSApplication.hideOtherApplications(_:)), application, "h", [.command, .option], localization)
        addItem(.showAll, MacPadStringKey.showAll.rawValue, appMenu, #selector(NSApplication.unhideAllApplications(_:)), application, "", [.command], localization)
        appMenu.addItem(.separator())
        addItem(.quitMacPad, MacPadStringKey.quitMacPad.rawValue, appMenu, #selector(NSApplication.terminate(_:)), application, "q", [.command], localization)
        mainMenu.addItem(rootItem(for: appMenu, identifier: "menu.app"))

        let fileMenu = NSMenu(title: localization.string(.fileMenu))
        addItem(.newDocument, "file.newDocument", fileMenu, #selector(AppDelegate.openNewDocument(_:)), target, "n", [.command], localization)
        addItem(.newTab, MacPadStringKey.newTab.rawValue, fileMenu, #selector(AppDelegate.openNewTab(_:)), target, "t", [.command], localization)
        addItem(.newWindow, MacPadStringKey.newWindow.rawValue, fileMenu, #selector(AppDelegate.openNewWindow(_:)), target, "", [.command], localization)
        fileMenu.addItem(.separator())
        addItem(.open, MacPadStringKey.open.rawValue, fileMenu, #selector(AppDelegate.openDocument(_:)), target, "o", [.command], localization)
        let recentMenu = NSMenu(title: localization.string(.openRecent))
        recentMenu.identifier = NSUserInterfaceItemIdentifier("file.openRecent")
        recentMenu.delegate = target as? NSMenuDelegate
        RecentDocumentsMenuBuilder.populate(
            recentMenu,
            references: [],
            target: target,
            localization: localization
        )
        let recentItem = NSMenuItem(
            title: localization.string(.openRecent),
            action: nil,
            keyEquivalent: ""
        )
        recentItem.identifier = NSUserInterfaceItemIdentifier("file.openRecent")
        recentItem.submenu = recentMenu
        fileMenu.addItem(recentItem)
        addItem(.close, MacPadStringKey.close.rawValue, fileMenu, #selector(NSWindow.performClose(_:)), nil, "w", [.command], localization)
        fileMenu.addItem(.separator())
        addItem(.save, "file.save", fileMenu, #selector(AppDelegate.save(_:)), target, "s", [.command], localization)
        addItem(.saveAs, "file.saveAs", fileMenu, #selector(AppDelegate.saveAs(_:)), target, "s", [.command, .shift], localization)
        fileMenu.addItem(.separator())
        addItem(.print, MacPadStringKey.print.rawValue, fileMenu, #selector(AppDelegate.printDocument(_:)), target, "p", [.command], localization)
        mainMenu.addItem(rootItem(for: fileMenu, identifier: MacPadStringKey.fileMenu.rawValue))

        let editMenu = NSMenu(title: localization.string(.editMenu))
        addItem(.undo, MacPadStringKey.undo.rawValue, editMenu, Selector(("undo:")), nil, "z", [.command], localization)
        addItem(.redo, MacPadStringKey.redo.rawValue, editMenu, Selector(("redo:")), nil, "z", [.command, .shift], localization)
        editMenu.addItem(.separator())
        addItem(.cut, MacPadStringKey.cut.rawValue, editMenu, #selector(NSText.cut(_:)), nil, "x", [.command], localization)
        addItem(.copy, MacPadStringKey.copy.rawValue, editMenu, #selector(NSText.copy(_:)), nil, "c", [.command], localization)
        addItem(.paste, MacPadStringKey.paste.rawValue, editMenu, #selector(NSText.paste(_:)), nil, "v", [.command], localization)
        addItem(.delete, MacPadStringKey.delete.rawValue, editMenu, #selector(NSText.delete(_:)), nil, "", [.command], localization)
        editMenu.addItem(.separator())
        let findMenu = NSMenu(title: localization.string(.findTitle))
        addItem(.find, MacPadStringKey.find.rawValue, findMenu, #selector(AppDelegate.showFind(_:)), target, "f", [.command], localization)
        addItem(.findNext, MacPadStringKey.findNext.rawValue, findMenu, #selector(AppDelegate.findNext(_:)), target, "g", [.command], localization)
        addItem(.findPrevious, MacPadStringKey.findPrevious.rawValue, findMenu, #selector(AppDelegate.findPrevious(_:)), target, "g", [.command, .shift], localization)
        addItem(.replace, MacPadStringKey.replace.rawValue, findMenu, #selector(AppDelegate.showReplace(_:)), target, "f", [.command, .option], localization)
        editMenu.addItem(rootItem(for: findMenu, identifier: "edit.findMenu"))
        addItem(.goTo, MacPadStringKey.goTo.rawValue, editMenu, #selector(AppDelegate.goToLine(_:)), target, "l", [.command], localization)
        editMenu.addItem(.separator())
        addItem(.selectAll, MacPadStringKey.selectAll.rawValue, editMenu, #selector(NSText.selectAll(_:)), nil, "a", [.command], localization)
        addItem(.timeDate, MacPadStringKey.timeDate.rawValue, editMenu, #selector(AppDelegate.insertTimeDate(_:)), target, f5KeyEquivalent, [], localization)
        mainMenu.addItem(rootItem(for: editMenu, identifier: MacPadStringKey.editMenu.rawValue))

        let formatMenu = NSMenu(title: localization.string(.formatMenu))
        let wordWrapItem = addItem(.wordWrap, MacPadStringKey.wordWrap.rawValue, formatMenu, #selector(AppDelegate.toggleWordWrap(_:)), target, "w", [.command, .option], localization)
        wordWrapItem.state = .on
        addItem(.font, MacPadStringKey.font.rawValue, formatMenu, #selector(AppDelegate.chooseFont(_:)), target, "", [.command], localization)
        mainMenu.addItem(rootItem(for: formatMenu, identifier: MacPadStringKey.formatMenu.rawValue))

        let viewMenu = NSMenu(title: localization.string(.viewMenu))
        addItem(.zoomIn, MacPadStringKey.zoomIn.rawValue, viewMenu, #selector(AppDelegate.zoomIn(_:)), target, "+", [.command], localization)
        addItem(.zoomOut, MacPadStringKey.zoomOut.rawValue, viewMenu, #selector(AppDelegate.zoomOut(_:)), target, "-", [.command], localization)
        addItem(.restoreDefaultZoom, MacPadStringKey.restoreDefaultZoom.rawValue, viewMenu, #selector(AppDelegate.restoreZoom(_:)), target, "0", [.command], localization)
        viewMenu.addItem(.separator())
        let statusBarItem = addItem(.statusBar, MacPadStringKey.statusBar.rawValue, viewMenu, #selector(AppDelegate.toggleStatusBar(_:)), target, "/", [.command], localization)
        statusBarItem.state = .on
        viewMenu.addItem(.separator())
        addItem(.showInMenuBar, "view.menuBar", viewMenu, #selector(AppDelegate.toggleMenuBarVisibility(_:)), target, "", [.command], localization)
        mainMenu.addItem(rootItem(for: viewMenu, identifier: MacPadStringKey.viewMenu.rawValue))

        let windowMenu = NSMenu(title: localization.string(.windowMenu))
        addItem(.minimize, MacPadStringKey.minimize.rawValue, windowMenu, #selector(NSWindow.miniaturize(_:)), nil, "m", [.command], localization)
        addItem(.zoom, MacPadStringKey.zoom.rawValue, windowMenu, #selector(NSWindow.performZoom(_:)), nil, "", [.command], localization)
        windowMenu.addItem(.separator())
        addItem(.showPreviousTab, MacPadStringKey.showPreviousTab.rawValue, windowMenu, #selector(NSWindow.selectPreviousTab(_:)), nil, "[", [.command, .shift], localization)
        addItem(.showNextTab, MacPadStringKey.showNextTab.rawValue, windowMenu, #selector(NSWindow.selectNextTab(_:)), nil, "]", [.command, .shift], localization)
        windowMenu.addItem(.separator())
        addItem(.bringAllToFront, MacPadStringKey.bringAllToFront.rawValue, windowMenu, #selector(NSApplication.arrangeInFront(_:)), application, "", [.command], localization)
        mainMenu.addItem(rootItem(for: windowMenu, identifier: MacPadStringKey.windowMenu.rawValue))
        application.windowsMenu = windowMenu

        let helpMenu = NSMenu(title: localization.string(.helpMenu))
        if customerRoutes.helpURL != nil {
            addItem(.macPadHelp, "help.macPadHelp", helpMenu, #selector(AppDelegate.openHelp(_:)), target, "", [.command], localization)
        }
        if customerRoutes.supportURL != nil {
            addItem(.reportIssue, "help.reportIssue", helpMenu, #selector(AppDelegate.reportIssue(_:)), target, "", [.command], localization)
        }
        if customerRoutes.privacyURL != nil {
            addItem(.privacy, "help.privacy", helpMenu, #selector(AppDelegate.openPrivacy(_:)), target, "", [.command], localization)
        }
        if customerRoutes.securityURL != nil {
            addItem(.security, "help.security", helpMenu, #selector(AppDelegate.openSecurity(_:)), target, "", [.command], localization)
        }
        if customerRoutes.updateURL != nil, distributionChannel.showsDirectUpdateCommand {
            if !helpMenu.items.isEmpty {
                helpMenu.addItem(.separator())
            }
            addItem(.checkForUpdates, "help.checkUpdates", helpMenu, #selector(AppDelegate.checkForUpdates(_:)), target, "", [.command], localization)
        }
        mainMenu.addItem(rootItem(for: helpMenu, identifier: MacPadStringKey.helpMenu.rawValue))
        application.helpMenu = helpMenu

        return mainMenu
    }

    private static func rootItem(for submenu: NSMenu, identifier: String) -> NSMenuItem {
        submenu.identifier = NSUserInterfaceItemIdentifier(identifier)
        let item = NSMenuItem(
            title: submenu.title,
            action: nil,
            keyEquivalent: ""
        )
        item.identifier = NSUserInterfaceItemIdentifier(identifier)
        item.submenu = submenu
        return item
    }

    private static var f5KeyEquivalent: String {
        String(UnicodeScalar(NSF5FunctionKey)!)
    }

    @discardableResult
    private static func addItem(
        _ titleKey: MacPadStringKey,
        _ identifier: String,
        _ menu: NSMenu,
        _ action: Selector?,
        _ target: AnyObject?,
        _ keyEquivalent: String,
        _ modifiers: NSEvent.ModifierFlags,
        _ localization: MacPadLocalization
    ) -> NSMenuItem {
        let item = NSMenuItem(
            title: localization.string(titleKey),
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.identifier = NSUserInterfaceItemIdentifier(identifier)
        item.target = target
        item.keyEquivalentModifierMask = modifiers
        menu.addItem(item)
        return item
    }
}
