import AppKit
import NotepadMacCore
import Testing
@testable import NotepadMac

@Suite("Window routing")
@MainActor
struct WindowRoutingTests {
    @Test("source Info.plist advertises the native localization contract")
    func sourceInfoPlistLocalizationContract() throws {
        let repositoryRoot = URL(fileURLWithPath: #filePath, isDirectory: false)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let infoPlistURL = repositoryRoot
            .appendingPathComponent("Resources", isDirectory: true)
            .appendingPathComponent("Info.plist", isDirectory: false)
        let data = try Data(contentsOf: infoPlistURL)
        let contract = try PropertyListDecoder().decode(
            SourceInfoPlistContract.self,
            from: data
        )

        #expect(contract.developmentRegion == "en")
        #expect(contract.identifier == "local.macpad.app")
        #expect(contract.localizations == ["en", "de"])
        #expect(contract.applicationCategory == "public.app-category.utilities")
    }

    @Test("Open Recent uses a stable identifier")
    func openRecentUsesStableIdentifier() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct)
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
                MacPadStringKey.newDocument.rawValue: "Neues Dokument",
                MacPadStringKey.openRecent.rawValue: "Benutzte Dokumente",
                MacPadStringKey.showInMenuBar.rawValue: "MacPad in der Menüleiste anzeigen"
            ]
        ) { localization in
            let application = NSApplication.shared
            let delegate = appDelegate(localization: localization)
            let menu = MainMenuFactory.makeMenu(
                target: delegate,
                application: application,
                localization: localization,
                distributionChannel: .direct,
                customerRoutes: .current(for: .direct)
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
                menuItem(withIdentifier: "file.newDocument", in: menu)?.title
                    == "Neues Dokument"
            )
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
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct)
        )
        let expectedActions: [String: Selector] = [
            "file.save": #selector(AppDelegate.save(_:)),
            "file.saveAs": #selector(AppDelegate.saveAs(_:)),
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
        #expect(menuItem(withIdentifier: "file.clearSession", in: menu) == nil)
    }

    @Test("Edit uses a localized Find submenu and keeps Go To outside it")
    func editUsesLocalizedFindSubmenu() throws {
        try withLocalization(
            languageCode: "de",
            strings: [MacPadStringKey.findTitle.rawValue: "Suchen"]
        ) { localization in
            let application = NSApplication.shared
            let delegate = appDelegate(localization: localization)
            let menu = MainMenuFactory.makeMenu(
                target: delegate,
                application: application,
                localization: localization,
                distributionChannel: .direct,
                customerRoutes: .current(for: .direct)
            )
            let editMenu = try #require(
                menuItem(withIdentifier: MacPadStringKey.editMenu.rawValue, in: menu)?.submenu
            )
            let findMenuItem = try #require(
                editMenu.items.first { $0.identifier?.rawValue == "edit.findMenu" }
            )
            let findMenu = try #require(findMenuItem.submenu)

            #expect(findMenuItem.title == "Suchen")
            #expect(findMenu.title == "Suchen")
            #expect(
                findMenu.items.compactMap { $0.identifier?.rawValue }
                    == [
                        MacPadStringKey.find.rawValue,
                        MacPadStringKey.findNext.rawValue,
                        MacPadStringKey.findPrevious.rawValue,
                        MacPadStringKey.replace.rawValue
                    ]
            )
            #expect(
                findMenu.items.map(\.action)
                    == [
                        #selector(AppDelegate.showFind(_:)),
                        #selector(AppDelegate.findNext(_:)),
                        #selector(AppDelegate.findPrevious(_:)),
                        #selector(AppDelegate.showReplace(_:))
                    ]
            )
            #expect(
                editMenu.items.contains {
                    $0.identifier?.rawValue == MacPadStringKey.goTo.rawValue
                }
            )
            #expect(
                !editMenu.items.contains {
                    $0.identifier?.rawValue == MacPadStringKey.find.rawValue
                }
            )
        }
    }

    @Test("Find submenu parent uses the selected English title")
    func findSubmenuParentUsesEnglishTitle() throws {
        try withLocalization(
            languageCode: "en",
            strings: [MacPadStringKey.findTitle.rawValue: "Find"]
        ) { localization in
            let application = NSApplication.shared
            let delegate = appDelegate(localization: localization)
            let menu = MainMenuFactory.makeMenu(
                target: delegate,
                application: application,
                localization: localization,
                distributionChannel: .direct,
                customerRoutes: .current(for: .direct)
            )
            let findMenuItem = try #require(
                menuItem(withIdentifier: "edit.findMenu", in: menu)
            )

            #expect(findMenuItem.title == "Find")
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

    @Test("Find-only panel fits its German large-text content")
    func findOnlyPanelFitsGermanLargeTextContent() throws {
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
            let window = try #require(controller.window)
            let contentView = try #require(window.contentView)
            let visibleIdentifiers = [
                "find.termLabel",
                "find.term",
                "find.next",
                "find.previous",
                "find.matchCase",
                "find.wrapAround"
            ]
            for identifier in visibleIdentifiers {
                let visibleView = try #require(
                    view(withIdentifier: identifier, in: contentView)
                )
                if let textField = visibleView as? NSTextField {
                    textField.font = NSFont.systemFont(ofSize: 17)
                }
                if let button = visibleView as? NSButton {
                    button.font = NSFont.systemFont(ofSize: 17)
                }
            }

            controller.show(initialTerm: "MacPad", showReplace: false)
            defer { controller.close() }
            contentView.layoutSubtreeIfNeeded()

            let grid = try #require(
                view(withIdentifier: "find.grid", in: contentView) as? NSGridView
            )
            let findHeight = window.contentLayoutRect.height
            let replaceField = try #require(
                view(withIdentifier: "find.replacement", in: contentView)
            )
            let replaceButton = try #require(
                view(withIdentifier: "find.replace", in: contentView)
            )
            #expect(window.title == "Suchen")
            #expect(findHeight < 204)
            #expect(grid.frame.minY <= 17)
            #expect(replaceField.isHiddenOrHasHiddenAncestor)
            #expect(replaceButton.isHiddenOrHasHiddenAncestor)
            for identifier in visibleIdentifiers {
                let visibleView = try #require(
                    view(withIdentifier: identifier, in: contentView)
                )
                let frame = visibleView.convert(visibleView.bounds, to: contentView)
                #expect(contentView.bounds.contains(frame))
                #expect(visibleView.frame.width + 1 >= visibleView.intrinsicContentSize.width)
            }

            controller.show(initialTerm: "MacPad", showReplace: true)
            contentView.layoutSubtreeIfNeeded()
            #expect(window.contentLayoutRect.height >= 204)
            #expect(window.contentLayoutRect.height > findHeight)
            #expect(!replaceField.isHiddenOrHasHiddenAncestor)
            #expect(!replaceButton.isHiddenOrHasHiddenAncestor)

            controller.show(initialTerm: "MacPad", showReplace: false)
            contentView.layoutSubtreeIfNeeded()
            #expect(abs(window.contentLayoutRect.height - findHeight) < 1)
            #expect(replaceField.isHiddenOrHasHiddenAncestor)
            #expect(replaceButton.isHiddenOrHasHiddenAncestor)
        }
    }

    @Test("German editor values cross the injected localization boundary")
    func germanEditorValues() throws {
        try withLocalization(
            languageCode: "de",
            strings: [
                MacPadStringKey.untitled.rawValue: "Unbenannt",
                MacPadStringKey.untitledFileName.rawValue: "Unbenannt.txt",
                MacPadStringKey.windowTitle.rawValue: "%1$@ - MacPad",
                MacPadStringKey.documentText.rawValue: "Dokumenttext",
                MacPadStringKey.documentStatus.rawValue: "Dokumentstatus",
                MacPadStringKey.statusLine.rawValue:
                    "Z. %1$lld, Sp. %2$lld  |  %3$lld%%  |  %4$@  |  %5$@"
            ],
            technicalTerms: [
                "macpad.term.line-ending.windows-crlf": "Windows-Zeilenende (CRLF)",
                "macpad.term.encoding.utf8": "Technischer Begriff UTF-8"
            ]
        ) { localization in
            let controller = EditorWindowController(
                localization: localization,
                fileAccess: directFileAccess
            )
            let contentView = try #require(controller.window?.contentView)
            let editor = try #require(view(withIdentifier: "editor.text", in: contentView))
            let status = try #require(
                view(withIdentifier: "editor.status", in: contentView) as? NSTextField
            )

            #expect(controller.window?.title == "Unbenannt - MacPad")
            #expect(localization.string(.untitledFileName) == "Unbenannt.txt")
            #expect(editor.accessibilityLabel() == "Dokumenttext")
            #expect(status.accessibilityLabel() == "Dokumentstatus")
            #expect(
                status.stringValue
                    == "Z. 1, Sp. 1  |  100%  |  Windows-Zeilenende (CRLF)  |  Technischer Begriff UTF-8"
            )
        }
    }

    @Test("main editor wins while a utility panel is key")
    func resolvesMainEditorBeforeFallback() {
        let mainEditor = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
        let fallbackEditor = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
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

    @Test("Go To alert keeps balanced German large-text proportions and keyboard order")
    func goToAlertUsesBalancedGermanLargeTextLayout() throws {
        try withLocalization(
            languageCode: "de",
            strings: [
                MacPadStringKey.goToLineTitle.rawValue: "Gehe zu Zeile",
                MacPadStringKey.lineNumberLabel.rawValue: "Zeilennummer:",
                MacPadStringKey.lineNumber.rawValue: "Zeilennummer",
                MacPadStringKey.goToLine.rawValue: "Gehe zu",
                MacPadStringKey.cancel.rawValue: "Abbrechen"
            ]
        ) { localization in
            let presentation = GoToLineAlertFactory.makeAlert(
                currentLine: 2,
                localization: localization
            )
            let goToButton = try #require(presentation.alert.buttons.first)
            let cancelButton = try #require(presentation.alert.buttons.last)
            presentation.input.font = NSFont.systemFont(ofSize: 17)
            goToButton.font = NSFont.systemFont(ofSize: 17)
            cancelButton.font = NSFont.systemFont(ofSize: 17)
            presentation.prepareForPresentation()
            let window = presentation.alert.window

            #expect(presentation.alert.messageText == "Gehe zu Zeile")
            #expect(presentation.alert.informativeText == "Zeilennummer:")
            #expect(presentation.input.stringValue == "2")
            #expect(presentation.input.frame.width >= 320)
            #expect(window.frame.width >= 350)
            #expect(presentation.input.accessibilityLabel() == "Zeilennummer")
            #expect(goToButton.identifier?.rawValue == "goTo.action")
            #expect(goToButton.accessibilityLabel() == "Gehe zu")
            #expect(cancelButton.identifier?.rawValue == "action.cancel")
            #expect(window.initialFirstResponder === presentation.input)
            #expect(goToButton.keyEquivalent == "\r")
            #expect(cancelButton.keyEquivalent == "\u{1b}")
        }
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

        let editor = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
        try editor.loadGrantedFile(fileURL)

        let resolved = EditorWindowResolver.controller(
            opening: try directFileAccess.makeReference(for: fileURL),
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
                localization: englishLocalization,
                fileAccess: directFileAccess
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
                localization: englishLocalization,
                fileAccess: directFileAccess
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
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct)
        )
        let newDocument = try #require(
            menuItem(withIdentifier: "file.newDocument", in: menu)
        )
        let newTab = try #require(menuItem(withIdentifier: "file.newTab", in: menu))
        let newWindow = try #require(menuItem(withIdentifier: "file.newWindow", in: menu))

        #expect(newDocument.title == "New Document")
        #expect(newDocument.keyEquivalent == "n")
        #expect(newDocument.keyEquivalentModifierMask == [.command])
        #expect(newDocument.action == #selector(AppDelegate.openNewDocument(_:)))
        #expect(newTab.keyEquivalent == "t")
        #expect(newTab.keyEquivalentModifierMask == [.command])
        #expect(newTab.action == #selector(AppDelegate.openNewTab(_:)))
        #expect(newWindow.keyEquivalent.isEmpty)
        #expect(newWindow.action == #selector(AppDelegate.openNewWindow(_:)))
        let fileMenu = try #require(
            menuItem(withIdentifier: MacPadStringKey.fileMenu.rawValue, in: menu)?.submenu
        )
        #expect(
            Array(fileMenu.items.prefix(5)).map { item in
                item.isSeparatorItem ? "separator" : item.identifier?.rawValue ?? "missing"
            } == [
                "file.newDocument",
                MacPadStringKey.newTab.rawValue,
                MacPadStringKey.newWindow.rawValue,
                "separator",
                MacPadStringKey.open.rawValue
            ]
        )
    }

    @Test("New Document uses an active tab group while New Window stays separate")
    func newDocumentUsesAdaptivePlacement() throws {
        let delegate = appDelegate(localization: englishLocalization)
        let application = NSApplication.shared
        let existingWindows = Set(application.windows.map(ObjectIdentifier.init))
        defer {
            application.windows
                .filter { !existingWindows.contains(ObjectIdentifier($0)) }
                .forEach { $0.close() }
        }

        delegate.openNewDocument(nil)
        let firstWindow = try #require(
            editorWindows(excluding: existingWindows, in: application).first
        )
        let firstContentView = try #require(firstWindow.contentView)
        let firstEditor = try #require(
            view(withIdentifier: "editor.text", in: firstContentView)
                as? NSTextView
        )
        firstEditor.string = "Existing document"

        delegate.openNewDocument(nil)
        let afterAdaptiveDocument = editorWindows(
            excluding: existingWindows,
            in: application
        )
        let secondWindow = try #require(
            afterAdaptiveDocument.first { $0 !== firstWindow }
        )
        let activeGroup = firstWindow.tabbedWindows ?? [firstWindow]
        #expect(delegate.editorWindowCount == 2)
        #expect(activeGroup.contains { $0 === secondWindow })
        #expect(firstEditor.string == "Existing document")

        delegate.openNewTab(nil)
        let afterExplicitTab = editorWindows(
            excluding: existingWindows,
            in: application
        )
        let thirdWindow = try #require(
            afterExplicitTab.first {
                $0 !== firstWindow && $0 !== secondWindow
            }
        )
        #expect(delegate.editorWindowCount == 3)
        #expect((firstWindow.tabbedWindows ?? [firstWindow]).contains { $0 === thirdWindow })

        delegate.openNewWindow(nil)
        let afterSeparateWindow = editorWindows(
            excluding: existingWindows,
            in: application
        )
        let fourthWindow = try #require(
            afterSeparateWindow.first {
                $0 !== firstWindow && $0 !== secondWindow && $0 !== thirdWindow
            }
        )
        #expect(delegate.editorWindowCount == 4)
        #expect(!(fourthWindow.tabbedWindows ?? [fourthWindow]).contains { $0 === firstWindow })
        #expect(
            afterSeparateWindow
                .filter { $0 !== firstWindow }
                .allSatisfy { window in
                    guard let contentView = window.contentView,
                          let editor = view(
                            withIdentifier: "editor.text",
                            in: contentView
                          ) as? NSTextView else {
                        return false
                    }
                    return editor.string.isEmpty
                }
        )
    }

    @Test("View menu exposes the optional menu-bar launcher")
    func menuBarLauncherCommand() throws {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct)
        )
        let item = try #require(menuItem(withIdentifier: "view.menuBar", in: menu))

        #expect(item.action == #selector(AppDelegate.toggleMenuBarVisibility(_:)))
        #expect(item.state == .off)
    }

    @Test("Normal launch opens one blank document and preserves Open Recent")
    func normalLaunchIgnoresLegacySession() throws {
        try withTemporaryDirectory { directory in
            let savedURL = directory.appendingPathComponent("Welcome.txt")
            try Data("Saved owner fixture".utf8).write(to: savedURL)
            let suiteName = "MacPadLaunchTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let recentKey = "MacPad.RecentDocumentBookmarks.v1"
            let recentStore = RecentDocumentStore(
                defaults: defaults,
                defaultsKey: recentKey,
                maximumCount: 20
            )
            let savedReference = PersistedFileReference(
                path: savedURL.path,
                bookmarkData: nil
            )
            try recentStore.add(savedReference)
            let legacySession = AppSessionState(tabs: [
                EditorSessionState(
                    id: "legacy-saved-tab",
                    fileReference: savedReference,
                    selectedLocation: 3,
                    wordWrapEnabled: false,
                    statusBarVisible: false,
                    zoomPercent: 130,
                    lineEnding: .unix
                )
            ])
            defaults.set(
                try JSONEncoder().encode(legacySession),
                forKey: "MacPad.SessionState.v1"
            )
            let delegate = AppDelegate(
                defaults: defaults,
                localization: englishLocalization,
                distributionChannel: .direct,
                customerRoutes: .current(for: .direct),
                fileAccess: directFileAccess,
                recentDocumentStore: recentStore
            )
            let application = NSApplication.shared
            let existingWindows = Set(application.windows.map(ObjectIdentifier.init))

            delegate.applicationDidFinishLaunching(
                Notification(
                    name: NSApplication.didFinishLaunchingNotification,
                    object: application
                )
            )

            let launchedWindows = application.windows.filter {
                !existingWindows.contains(ObjectIdentifier($0))
            }
            let launchedEditorWindows = launchedWindows.filter { window in
                guard let contentView = window.contentView else { return false }
                return view(withIdentifier: "editor.text", in: contentView) != nil
            }
            defer { launchedEditorWindows.forEach { $0.close() } }
            let window = try #require(launchedEditorWindows.first)
            let contentView = try #require(window.contentView)
            let editor = try #require(
                view(withIdentifier: "editor.text", in: contentView) as? NSTextView
            )
            #expect(delegate.editorWindowCount == 1)
            #expect(launchedEditorWindows.count == 1)
            #expect(window.representedURL == nil)
            #expect(editor.string.isEmpty)
            #expect(defaults.object(forKey: "MacPad.SessionState.v1") == nil)
            #expect(try recentStore.references() == [savedReference])
        }
    }

    @Test("quit cancellation stops before later dirty documents")
    func quitCancellationStopsAtFirstRejection() {
        var confirmationOrder: [String] = []
        let reply = ApplicationTermination.reply(
            confirmDiscardActions: [
                {
                    confirmationOrder.append("first")
                    return true
                },
                {
                    confirmationOrder.append("second")
                    return false
                },
                {
                    confirmationOrder.append("third")
                    return true
                }
            ]
        )

        #expect(reply == .terminateCancel)
        #expect(confirmationOrder == ["first", "second"])
    }

    @Test("menu-bar launcher is off by default and keeps the app running when enabled")
    func menuBarLauncherPreference() throws {
        let suiteName = "MacPadTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let delegate = AppDelegate(
            defaults: defaults,
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct),
            fileAccess: directFileAccess,
            recentDocumentStore: testRecentDocumentStore(defaults: defaults)
        )

        #expect(!delegate.isMenuBarEnabled)
        #expect(delegate.menuBarStatusItem == nil)
        #expect(delegate.applicationShouldTerminateAfterLastWindowClosed(.shared))

        delegate.toggleMenuBarVisibility(nil)

        #expect(delegate.isMenuBarEnabled)
        let statusItem = try #require(delegate.menuBarStatusItem)
        #expect(statusItem.button?.action == #selector(AppDelegate.handleMenuBarStatusItem(_:)))
        #expect(!delegate.applicationShouldTerminateAfterLastWindowClosed(.shared))
        #expect(
            AppDelegate(
                defaults: defaults,
                localization: englishLocalization,
                distributionChannel: .direct,
                customerRoutes: .current(for: .direct),
                fileAccess: directFileAccess,
                recentDocumentStore: testRecentDocumentStore(defaults: defaults)
            ).isMenuBarEnabled
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
        let delegate = AppDelegate(
            defaults: defaults,
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct),
            fileAccess: directFileAccess,
            recentDocumentStore: testRecentDocumentStore(defaults: defaults)
        )
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
        let delegate = AppDelegate(
            defaults: defaults,
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct),
            fileAccess: directFileAccess,
            recentDocumentStore: testRecentDocumentStore(defaults: defaults)
        )

        delegate.toggleMenuBarVisibility(nil)
        #expect(delegate.editorWindowCount == 0)

        delegate.toggleMenuBarVisibility(nil)
        #expect(delegate.editorWindowCount == 1)
    }

    @Test("activating a tab group moves the complete group to the recent end")
    func windowGroupRecency() throws {
        let first = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
        let second = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
        let third = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
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
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct)
        )
        let recentItem = try #require(menuItem(withIdentifier: "file.openRecent", in: menu))
        let recentMenu = try #require(recentItem.submenu)

        #expect(recentMenu.delegate === delegate)
    }

    @Test("recent document menu routes files and clear command")
    func populatesRecentDocumentsMenu() throws {
        let target = appDelegate(localization: englishLocalization)
        let menu = NSMenu(title: "Open Recent")
        let firstReference = PersistedFileReference(
            path: "/tmp/first.txt",
            bookmarkData: Data([1])
        )
        let secondReference = PersistedFileReference(
            path: "/tmp/second.txt",
            bookmarkData: Data([2])
        )

        RecentDocumentsMenuBuilder.populate(
            menu,
            references: [firstReference, secondReference],
            target: target,
            localization: englishLocalization
        )

        #expect(menu.items[0].title == "first.txt")
        #expect(
            menu.items[0].representedObject as? PersistedFileReference == firstReference
        )
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
            references: [],
            target: appDelegate(localization: englishLocalization),
            localization: englishLocalization
        )

        let placeholder = try #require(menu.items.first)
        #expect(placeholder.title == "No Recent Documents")
        #expect(!placeholder.isEnabled)
    }

    @Test("corrupt recent data remains visibly clearable")
    func unavailableRecentDocumentsMenu() throws {
        let menu = NSMenu(title: "Open Recent")

        RecentDocumentsMenuBuilder.populateUnavailable(
            menu,
            target: appDelegate(localization: englishLocalization),
            localization: englishLocalization
        )

        let placeholder = try #require(menu.items.first)
        #expect(placeholder.title == "Recent documents are unavailable")
        #expect(!placeholder.isEnabled)
        let clearItem = try #require(
            menu.items.first { $0.identifier?.rawValue == "file.clearRecentMenu" }
        )
        #expect(clearItem.isEnabled)
    }

    @Test("successful Save As reports an attached typed file transition")
    func successfulSaveCallback() throws {
        let controller = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
        let fileURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("txt")
        var reportedTransition: SuccessfulFileTransition?
        var referenceAtStateNotification: PersistedFileReference?
        controller.onStateChange = {
            referenceAtStateNotification = controller.fileReference
        }
        controller.onSuccessfulSave = { reportedTransition = $0 }

        try controller.saveDocument(to: fileURL, encoding: .utf8)

        let currentReference = try #require(controller.fileReference)
        #expect(reportedTransition?.previousReference == nil)
        #expect(reportedTransition?.currentReference == currentReference)
        #expect(referenceAtStateNotification == currentReference)
        #expect(currentReference.path == fileURL.resolvingSymlinksInPath().standardizedFileURL.path)
        #expect(FileManager.default.fileExists(atPath: fileURL.path))
    }

    @Test("failed Save As emits no state or file transition")
    func failedSaveIsSilent() throws {
        let controller = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
        let directoryURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        var stateNotificationCount = 0
        var transitionCount = 0
        controller.onStateChange = { stateNotificationCount += 1 }
        controller.onSuccessfulSave = { _ in transitionCount += 1 }

        #expect(throws: (any Error).self) {
            try controller.saveDocument(to: directoryURL, encoding: .utf8)
        }

        #expect(stateNotificationCount == 0)
        #expect(transitionCount == 0)
    }

    @Test("Save As stays attached to its previous state when bookmark persistence fails")
    func saveAsPersistenceFailureKeepsPreviousState() throws {
        try withTemporaryDirectory { directory in
            let originalURL = directory.appendingPathComponent("original.txt")
            let fileURL = directory.appendingPathComponent("written-without-access.txt")
            try Data("original".utf8).write(to: originalURL)
            try Data("before".utf8).write(to: fileURL)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o000],
                ofItemAtPath: fileURL.path
            )
            defer {
                try? FileManager.default.setAttributes(
                    [.posixPermissions: 0o600],
                    ofItemAtPath: fileURL.path
                )
            }
            let fileAccess = SecurityScopedFileAccess(requiresBookmark: true)
            let originalReference = try fileAccess.makeReference(for: originalURL)
            let controller = EditorWindowController(
                localization: englishLocalization,
                fileAccess: fileAccess
            )
            try controller.loadFile(originalReference)
            let contentView = try #require(controller.window?.contentView)
            let editor = try #require(
                view(withIdentifier: "editor.text", in: contentView) as? NSTextView
            )
            editor.string = "after"
            var stateNotificationCount = 0
            var transitionCount = 0
            var accessError: SecurityScopedFileAccessError?
            controller.onStateChange = { stateNotificationCount += 1 }
            controller.onSuccessfulSave = { _ in transitionCount += 1 }

            do {
                try controller.saveDocument(to: fileURL, encoding: .utf8)
                Issue.record("Expected bookmark creation to fail after the write.")
            } catch let error as SecurityScopedFileAccessError {
                accessError = error
            }
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: fileURL.path
            )

            #expect(accessError != nil)
            #expect(try String(contentsOf: fileURL, encoding: .utf8) == "after")
            #expect(controller.fileReference == originalReference)
            #expect(controller.sessionState?.fileReference == originalReference)
            #expect(stateNotificationCount == 0)
            #expect(transitionCount == 0)
        }
    }

    @Test("Store open attaches the refreshed bookmark before state notification")
    func storeOpenAttachesRefreshedBookmarkBeforeNotification() throws {
        try withTemporaryDirectory { directory in
            let originalURL = directory.appendingPathComponent("original.txt")
            let movedURL = directory.appendingPathComponent("moved.txt")
            try Data("MacPad".utf8).write(to: originalURL)
            let fileAccess = SecurityScopedFileAccess(requiresBookmark: true)
            let reference = try fileAccess.makeReference(for: originalURL)
            try FileManager.default.moveItem(at: originalURL, to: movedURL)
            let controller = EditorWindowController(
                localization: englishLocalization,
                fileAccess: fileAccess
            )
            var referenceAtNotification: PersistedFileReference?
            controller.onStateChange = {
                referenceAtNotification = controller.fileReference
            }

            try controller.loadFile(reference)

            let attached = try #require(controller.fileReference)
            #expect(attached.path == movedURL.resolvingSymlinksInPath().standardizedFileURL.path)
            #expect(attached.bookmarkData?.isEmpty == false)
            #expect(referenceAtNotification == attached)
        }
    }

    @Test("current Store save uses the attached bookmark and reports one transition")
    func currentStoreSaveTransition() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("current.txt")
            try Data("before".utf8).write(to: fileURL)
            let fileAccess = SecurityScopedFileAccess(requiresBookmark: true)
            let initialReference = try fileAccess.makeReference(for: fileURL)
            let controller = EditorWindowController(
                localization: englishLocalization,
                fileAccess: fileAccess
            )
            try controller.loadFile(initialReference)
            let contentView = try #require(controller.window?.contentView)
            let editor = try #require(
                view(withIdentifier: "editor.text", in: contentView) as? NSTextView
            )
            editor.string = "after"
            var transitions: [SuccessfulFileTransition] = []
            controller.onSuccessfulSave = { transitions.append($0) }

            try controller.saveCurrentDocument(encoding: .utf8)

            let currentReference = try #require(controller.fileReference)
            #expect(transitions.count == 1)
            #expect(transitions[0].previousReference == initialReference)
            #expect(transitions[0].currentReference == currentReference)
            #expect(currentReference.bookmarkData?.isEmpty == false)
            #expect(try String(contentsOf: fileURL, encoding: .utf8) == "after")
        }
    }

    @Test("current Store save rejects an external edit after bookmark-tracked move")
    func currentStoreSaveRejectsExternalEditAfterMove() throws {
        try withTemporaryDirectory { directory in
            let originalURL = directory.appendingPathComponent("save-original.txt")
            let movedURL = directory.appendingPathComponent("save-moved.txt")
            try Data("original".utf8).write(to: originalURL)
            let fileAccess = SecurityScopedFileAccess(requiresBookmark: true)
            let initialReference = try fileAccess.makeReference(for: originalURL)
            let controller = EditorWindowController(
                localization: englishLocalization,
                fileAccess: fileAccess
            )
            try controller.loadFile(initialReference)
            let openedReference = try #require(controller.fileReference)
            let contentView = try #require(controller.window?.contentView)
            let editor = try #require(
                view(withIdentifier: "editor.text", in: contentView) as? NSTextView
            )
            editor.string = "MacPad edit"
            try FileManager.default.moveItem(at: originalURL, to: movedURL)
            try Data("external edit".utf8).write(to: movedURL)
            var stateNotificationCount = 0
            var transitionCount = 0
            controller.onStateChange = { stateNotificationCount += 1 }
            controller.onSuccessfulSave = { _ in transitionCount += 1 }

            do {
                try controller.saveCurrentDocument(encoding: .utf8)
                Issue.record("Expected the external edit to reject the moved-file save.")
            } catch EditorDocumentError.fileChangedOnDisk(let path) {
                #expect(path == movedURL.resolvingSymlinksInPath().standardizedFileURL.path)
            }

            #expect(try String(contentsOf: movedURL, encoding: .utf8) == "external edit")
            #expect(editor.string == "MacPad edit")
            #expect(controller.fileReference == openedReference)
            #expect(controller.sessionState?.fileReference == openedReference)
            #expect(stateNotificationCount == 0)
            #expect(transitionCount == 0)
        }
    }

    @Test("reload resolves the current bookmark after a file move")
    func reloadUsesCurrentReference() throws {
        try withTemporaryDirectory { directory in
            let originalURL = directory.appendingPathComponent("reload-original.txt")
            let movedURL = directory.appendingPathComponent("reload-moved.txt")
            try Data("before".utf8).write(to: originalURL)
            let fileAccess = SecurityScopedFileAccess(requiresBookmark: true)
            let reference = try fileAccess.makeReference(for: originalURL)
            try FileManager.default.moveItem(at: originalURL, to: movedURL)
            let controller = EditorWindowController(
                localization: englishLocalization,
                fileAccess: fileAccess
            )
            try controller.loadFile(reference)
            try Data("after".utf8).write(to: movedURL, options: .atomic)

            try controller.reloadDocument()

            let contentView = try #require(controller.window?.contentView)
            let editor = try #require(
                view(withIdentifier: "editor.text", in: contentView) as? NSTextView
            )
            #expect(editor.string == "after")
            #expect(
                controller.fileReference?.path
                    == movedURL.resolvingSymlinksInPath().standardizedFileURL.path
            )
        }
    }

    @Test("session restoration uses bookmarked access and preserves tab metadata")
    func bookmarkedSessionRestore() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("session.txt")
            try Data("one\r\ntwo".utf8).write(to: fileURL)
            let fileAccess = SecurityScopedFileAccess(requiresBookmark: true)
            let reference = try fileAccess.makeReference(for: fileURL)
            let state = EditorSessionState(
                id: "session-id",
                fileReference: reference,
                selectedLocation: 5,
                wordWrapEnabled: false,
                statusBarVisible: false,
                zoomPercent: 130,
                lineEnding: .unix
            )
            let controller = EditorWindowController(
                localization: englishLocalization,
                fileAccess: fileAccess
            )

            try controller.restoreSessionState(state)

            let restored = try #require(controller.sessionState)
            #expect(restored.id == state.id)
            #expect(restored.fileReference == reference)
            #expect(restored.selectedLocation == state.selectedLocation)
            #expect(restored.wordWrapEnabled == state.wordWrapEnabled)
            #expect(restored.statusBarVisible == state.statusBarVisible)
            #expect(restored.zoomPercent == state.zoomPercent)
            #expect(restored.lineEnding == state.lineEnding)
        }
    }

    @Test("Finder-granted Store open creates and attaches a bookmark")
    func finderGrantedStoreOpen() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("finder.txt")
            try Data("Finder".utf8).write(to: fileURL)
            let fileAccess = SecurityScopedFileAccess(requiresBookmark: true)

            let controller = try EditorWindowResolver.makeController(
                opening: fileURL,
                localization: englishLocalization,
                fileAccess: fileAccess
            )

            #expect(controller.fileReference?.bookmarkData?.isEmpty == false)
            #expect(
                controller.fileReference?.path
                    == fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            )
        }
    }

    @Test("preferred fonts apply without marking the document edited")
    func appliesPreferredFont() throws {
        let initialFont = try #require(NSFont(name: "Menlo-Regular", size: 14))
        let replacementFont = try #require(NSFont(name: "Courier", size: 16))
        let controller = EditorWindowController(
            baseFont: initialFont,
            localization: englishLocalization,
            fileAccess: directFileAccess
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
        let controller = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
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
        let controller = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
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
        let controller = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
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

    @Test("Save As encoding row keeps native horizontal inset without clipping")
    func saveEncodingLayoutUsesNativeInsets() throws {
        try withLocalization(
            languageCode: "de",
            strings: [
                MacPadStringKey.encodingLabel.rawValue: "Zeichenkodierung:",
                MacPadStringKey.textEncoding.rawValue: "Textkodierung"
            ],
            technicalTerms: [
                "macpad.term.encoding.utf8": "UTF-8",
                "macpad.term.encoding.utf8-bom": "UTF-8 BOM",
                "macpad.term.encoding.utf16-le": "UTF-16 LE",
                "macpad.term.encoding.utf16-be": "UTF-16 BE",
                "macpad.term.encoding.windows-1252": "Windows-1252",
                "macpad.term.encoding.iso-8859-1": "ISO-8859-1"
            ]
        ) { localization in
            let accessory = SaveEncodingAccessory(
                selectedEncoding: .utf8,
                localization: localization
            )
            let label = try #require(
                view(withIdentifier: "save.encodingLabel", in: accessory.view)
                    as? NSTextField
            )
            label.font = NSFont.systemFont(ofSize: 17)
            accessory.view.frame.size = accessory.view.fittingSize
            accessory.view.layoutSubtreeIfNeeded()

            #expect(label.frame.minX >= 32)
            #expect(label.frame.width >= label.intrinsicContentSize.width)
            #expect(accessory.picker.frame.minX >= label.frame.maxX + 6)
            #expect(accessory.picker.frame.maxX <= accessory.view.bounds.maxX - 20)
        }
    }

    @Test("Save As sentence and technical terms use the same German bundle")
    func saveEncodingUsesGermanTechnicalTerms() throws {
        try withLocalization(
            languageCode: "de",
            strings: [
                MacPadStringKey.encodingLabel.rawValue: "Zeichenkodierung:",
                MacPadStringKey.textEncoding.rawValue: "Textkodierung"
            ],
            technicalTerms: [
                "macpad.term.encoding.utf8": "Technischer Begriff UTF-8",
                "macpad.term.encoding.utf8-bom": "Technischer Begriff UTF-8 BOM",
                "macpad.term.encoding.utf16-le": "Technischer Begriff UTF-16 LE",
                "macpad.term.encoding.utf16-be": "Technischer Begriff UTF-16 BE",
                "macpad.term.encoding.windows-1252": "Technischer Begriff Windows-1252",
                "macpad.term.encoding.iso-8859-1": "Technischer Begriff ISO-8859-1"
            ]
        ) { localization in
            let accessory = SaveEncodingAccessory(
                selectedEncoding: .utf16LittleEndian,
                localization: localization
            )

            #expect(accessory.picker.accessibilityLabel() == "Textkodierung")
            #expect(
                accessory.picker.itemTitles
                    == [
                        "Technischer Begriff UTF-8",
                        "Technischer Begriff UTF-8 BOM",
                        "Technischer Begriff UTF-16 LE",
                        "Technischer Begriff UTF-16 BE",
                        "Technischer Begriff Windows-1252",
                        "Technischer Begriff ISO-8859-1"
                    ]
            )
            #expect(accessory.selectedEncoding == .utf16LittleEndian)
        }
    }

    @Test("menu has no duplicate keyboard shortcuts")
    func menuShortcutsAreUnique() {
        let application = NSApplication.shared
        let delegate = appDelegate(localization: englishLocalization)
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct)
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
            localization: englishLocalization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct)
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

    @Test("current Store menu exposes permanent support and privacy only")
    func currentStoreMenuExposesPermanentSupportAndPrivacyOnly() throws {
        let application = NSApplication.shared
        let routes = CustomerRoutes.current(for: .appStore)
        let delegate = AppDelegate(
            defaults: .standard,
            localization: englishLocalization,
            distributionChannel: .appStore,
            customerRoutes: routes,
            fileAccess: SecurityScopedFileAccess(requiresBookmark: true),
            recentDocumentStore: testRecentDocumentStore(defaults: .standard)
        )
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization,
            distributionChannel: .appStore,
            customerRoutes: routes
        )

        #expect(menuItem(withIdentifier: "help.macPadHelp", in: menu) == nil)
        #expect(
            try #require(menuItem(withIdentifier: "help.reportIssue", in: menu)).action
                == #selector(AppDelegate.reportIssue(_:))
        )
        #expect(
            try #require(menuItem(withIdentifier: "help.privacy", in: menu)).action
                == #selector(AppDelegate.openPrivacy(_:))
        )
        #expect(menuItem(withIdentifier: "help.security", in: menu) == nil)
        #expect(menuItem(withIdentifier: "help.checkUpdates", in: menu) == nil)
    }

    @Test("configured Store routes expose support but never direct updates")
    func configuredStoreCustomerCommands() throws {
        let application = NSApplication.shared
        let routes = storeFixtureRoutes
        let delegate = AppDelegate(
            defaults: .standard,
            localization: englishLocalization,
            distributionChannel: .appStore,
            customerRoutes: routes,
            fileAccess: SecurityScopedFileAccess(requiresBookmark: true),
            recentDocumentStore: testRecentDocumentStore(defaults: .standard)
        )
        let menu = MainMenuFactory.makeMenu(
            target: delegate,
            application: application,
            localization: englishLocalization,
            distributionChannel: .appStore,
            customerRoutes: routes
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
            try #require(menuItem(withIdentifier: "help.privacy", in: menu)).action
                == #selector(AppDelegate.openPrivacy(_:))
        )
        #expect(
            try #require(menuItem(withIdentifier: "help.security", in: menu)).action
                == #selector(AppDelegate.openSecurity(_:))
        )
        #expect(menuItem(withIdentifier: "help.checkUpdates", in: menu) == nil)
    }

    @Test("Store About exposes permanent localized contact links only")
    func storeAboutExposesPermanentLocalizedContactLinksOnly() {
        let delegate = AppDelegate(
            defaults: .standard,
            localization: englishLocalization,
            distributionChannel: .appStore,
            customerRoutes: .current(for: .appStore),
            fileAccess: SecurityScopedFileAccess(requiresBookmark: true),
            recentDocumentStore: testRecentDocumentStore(defaults: .standard)
        )

        let credits = delegate.aboutCredits()

        #expect(credits.string.contains("Website: macpad.net"))
        #expect(credits.string.contains("Support: macpad.net/support"))
        #expect(credits.string.contains("Privacy Policy"))
        #expect(!credits.string.contains("Created by"))
        #expect(!credits.string.contains("anvilfilbert"))
        #expect(!credits.string.contains("@"))
        #expect(!credits.string.contains("Source Code"))
        #expect(!credits.string.contains("Public repo"))
        #expect(
            linkDestinations(in: credits) == Set([
                "https://macpad.net",
                "https://macpad.net/support",
                "https://macpad.net/privacy"
            ])
        )
    }

    #if !MACPAD_APP_STORE
    @Test("direct About exposes the same permanent customer links without source information")
    func directAboutExposesPermanentCustomerLinksWithoutSourceInformation() {
        let delegate = appDelegate(localization: englishLocalization)

        let credits = delegate.aboutCredits()

        #expect(credits.string.contains("Website: macpad.net"))
        #expect(credits.string.contains("Support: macpad.net/support"))
        #expect(credits.string.contains("Privacy Policy"))
        #expect(!credits.string.contains("Created by"))
        #expect(!credits.string.contains("anvilfilbert"))
        #expect(!credits.string.contains("@"))
        #expect(!credits.string.contains("Source Code"))
        #expect(
            linkDestinations(in: credits) == Set([
                "https://macpad.net",
                "https://macpad.net/support",
                "https://macpad.net/privacy"
            ])
        )
    }

    @Test("German About uses German labels with the same permanent destinations")
    func germanAboutUsesGermanLabelsWithSamePermanentDestinations() throws {
        try withLocalization(
            languageCode: "de",
            strings: germanAboutTranslations
        ) { localization in
            let credits = appDelegate(localization: localization).aboutCredits()

            #expect(credits.string.contains("Website: macpad.net"))
            #expect(credits.string.contains("Support: macpad.net/support"))
            #expect(credits.string.contains("Datenschutzerklärung"))
            #expect(!credits.string.contains("Erstellt von"))
            #expect(!credits.string.contains("anvilfilbert"))
            #expect(!credits.string.contains("@"))
            #expect(!credits.string.contains("Quellcode"))
            #expect(
                linkDestinations(in: credits) == Set([
                    "https://macpad.net",
                    "https://macpad.net/support",
                    "https://macpad.net/privacy"
                ])
            )
        }
    }
    #endif

    @Test("recent menu carries persisted references and clearing removes stored bookmarks")
    func appDelegateRecentMenuPopulationAndClear() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("recent.txt")
            try Data("recent".utf8).write(to: fileURL)
            let suiteName = "MacPadRecentRoutingTests.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let recentStore = RecentDocumentStore(
                defaults: defaults,
                defaultsKey: "MacPadTests.RecentRouting",
                maximumCount: 20
            )
            let reference = try directFileAccess.makeReference(for: fileURL)
            try recentStore.add(reference)
            let delegate = AppDelegate(
                defaults: defaults,
                localization: englishLocalization,
                distributionChannel: .direct,
                customerRoutes: .current(for: .direct),
                fileAccess: directFileAccess,
                recentDocumentStore: recentStore
            )
            let menu = NSMenu(title: "Open Recent")
            menu.identifier = NSUserInterfaceItemIdentifier("file.openRecent")

            delegate.populateRecentDocumentsMenu(menu, nativeURLs: [fileURL])

            #expect(menu.items.first?.representedObject as? PersistedFileReference == reference)

            delegate.clearRecentDocuments(nil)

            let storedAfterClear = try recentStore.references()
            #expect(storedAfterClear.isEmpty)
        }
    }

    @Test("editor controls expose accessibility metadata and initial focus")
    func editorAccessibility() throws {
        let controller = EditorWindowController(
            localization: englishLocalization,
            fileAccess: directFileAccess
        )
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

    private func editorWindows(
        excluding existingWindows: Set<ObjectIdentifier>,
        in application: NSApplication
    ) -> [NSWindow] {
        application.windows.filter { window in
            guard !existingWindows.contains(ObjectIdentifier(window)),
                  let contentView = window.contentView else {
                return false
            }
            return view(withIdentifier: "editor.text", in: contentView) != nil
        }
    }

    private func linkDestinations(in credits: NSAttributedString) -> Set<String> {
        var destinations: Set<String> = []
        credits.enumerateAttribute(
            NSAttributedString.Key.link,
            in: NSRange(location: 0, length: credits.length)
        ) { value, _, _ in
            if let url = value as? URL {
                destinations.insert(url.absoluteString)
            }
        }
        return destinations
    }

    private var englishLocalization: MacPadLocalization {
        MacPadLocalization(bundle: .main)
    }

    private var directFileAccess: SecurityScopedFileAccess {
        SecurityScopedFileAccess(requiresBookmark: false)
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

    private var germanAboutTranslations: [String: String] {
        [
            MacPadStringKey.aboutWebsite.rawValue: "Website: %1$@",
            MacPadStringKey.aboutSupport.rawValue: "Support: %1$@",
            MacPadStringKey.aboutPrivacyPolicy.rawValue: "Datenschutzerklärung"
        ]
    }

    private var storeFixtureRoutes: CustomerRoutes {
        CustomerRoutes(
            productURL: URL(string: "https://product.example/macpad"),
            helpURL: URL(string: "https://help.example/macpad"),
            supportURL: URL(string: "https://support.example/macpad"),
            privacyURL: URL(string: "https://privacy.example/macpad"),
            securityURL: URL(string: "https://security.example/macpad"),
            updateURL: URL(string: "https://updates.example/macpad"),
            migrationURL: URL(string: "https://migration.example/macpad")
        )
    }

    private func appDelegate(localization: MacPadLocalization) -> AppDelegate {
        AppDelegate(
            defaults: .standard,
            localization: localization,
            distributionChannel: .direct,
            customerRoutes: .current(for: .direct),
            fileAccess: directFileAccess,
            recentDocumentStore: testRecentDocumentStore(defaults: .standard)
        )
    }

    private func storeAppDelegate(defaults: UserDefaults) -> AppDelegate {
        AppDelegate(
            defaults: defaults,
            localization: englishLocalization,
            distributionChannel: .appStore,
            customerRoutes: .current(for: .appStore),
            fileAccess: SecurityScopedFileAccess(requiresBookmark: true),
            recentDocumentStore: testRecentDocumentStore(defaults: defaults)
        )
    }

    private func testRecentDocumentStore(defaults: UserDefaults) -> RecentDocumentStore {
        RecentDocumentStore(
            defaults: defaults,
            defaultsKey: "MacPadTests.RecentDocuments.\(UUID().uuidString)",
            maximumCount: 20
        )
    }

    private func missingStoreSessionState(id: String) -> EditorSessionState {
        EditorSessionState(
            id: id,
            fileReference: PersistedFileReference(
                path: "/private/tmp/does-not-have-a-bookmark-\(UUID().uuidString).txt",
                bookmarkData: nil
            ),
            selectedLocation: 2,
            wordWrapEnabled: false,
            statusBarVisible: false,
            zoomPercent: 130,
            lineEnding: .unix
        )
    }

    private func withTemporaryDirectory<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacPadWindowTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        defer {
            do {
                try FileManager.default.removeItem(at: directory)
            } catch {
                Issue.record(error)
            }
        }
        return try body(directory)
    }

    private func withLocalization<Result>(
        languageCode: String,
        strings: [String: String],
        body: (MacPadLocalization) throws -> Result
    ) throws -> Result {
        try withLocalization(
            languageCode: languageCode,
            tables: ["Localizable": strings],
            body: body
        )
    }

    private func withLocalization<Result>(
        languageCode: String,
        strings: [String: String],
        technicalTerms: [String: String],
        body: (MacPadLocalization) throws -> Result
    ) throws -> Result {
        try withLocalization(
            languageCode: languageCode,
            tables: ["Localizable": strings, "TechnicalTerms": technicalTerms],
            body: body
        )
    }

    private func withLocalization<Result>(
        languageCode: String,
        tables: [String: [String: String]],
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
        for (table, strings) in tables {
            try encoder.encode(strings).write(
                to: localizationDirectory.appendingPathComponent("\(table).strings"),
                options: .atomic
            )
        }

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

private struct SourceInfoPlistContract: Decodable {
    let developmentRegion: String
    let identifier: String
    let localizations: [String]
    let applicationCategory: String

    private enum CodingKeys: String, CodingKey {
        case developmentRegion = "CFBundleDevelopmentRegion"
        case identifier = "CFBundleIdentifier"
        case localizations = "CFBundleLocalizations"
        case applicationCategory = "LSApplicationCategoryType"
    }
}
