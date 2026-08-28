import AppKit
import NotepadMacCore
import OSLog

@MainActor
enum EditorWindowResolver {
    static func resolve(
        controllers: [EditorWindowController],
        mainWindow: NSWindow?,
        keyWindow: NSWindow?,
        lastActive: EditorWindowController?
    ) -> EditorWindowController? {
        if let controller = controllers.first(where: { $0.window === mainWindow }) {
            return controller
        }
        if let controller = controllers.first(where: { $0.window === keyWindow }) {
            return controller
        }
        if let lastActive,
           controllers.contains(where: { $0 === lastActive }) {
            return lastActive
        }
        return controllers.last
    }

    static func controller(
        opening reference: PersistedFileReference,
        controllers: [EditorWindowController]
    ) -> EditorWindowController? {
        let resolvedURL = URL(fileURLWithPath: reference.path)
            .resolvingSymlinksInPath()
            .standardizedFileURL
        return controllers.first { controller in
            guard let path = controller.fileReference?.path else { return false }
            return URL(fileURLWithPath: path)
                .resolvingSymlinksInPath()
                .standardizedFileURL == resolvedURL
        }
    }

    static func makeController(
        opening url: URL,
        localization: MacPadLocalization,
        fileAccess: SecurityScopedFileAccess
    ) throws -> EditorWindowController {
        let controller = EditorWindowController(
            localization: localization,
            fileAccess: fileAccess
        )
        try controller.loadGrantedFile(url)
        return controller
    }

    static func makeController(
        opening url: URL,
        baseFont: NSFont,
        localization: MacPadLocalization,
        fileAccess: SecurityScopedFileAccess
    ) throws -> EditorWindowController {
        let controller = EditorWindowController(
            baseFont: baseFont,
            localization: localization,
            fileAccess: fileAccess
        )
        try controller.loadGrantedFile(url)
        return controller
    }

    static func makeController(
        opening reference: PersistedFileReference,
        baseFont: NSFont,
        localization: MacPadLocalization,
        fileAccess: SecurityScopedFileAccess
    ) throws -> EditorWindowController {
        let controller = EditorWindowController(
            baseFont: baseFont,
            localization: localization,
            fileAccess: fileAccess
        )
        try controller.loadFile(reference)
        return controller
    }
}

enum SessionRestoreOutcome: Equatable {
    case noSession
    case restored
    case cancelled
}

enum SessionRestoreRecoveryDecision: Equatable {
    case locate
    case skip
    case cancel
}

struct SessionRestoreFailure: Equatable {
    let windowIndex: Int
    let tabIndex: Int
    let state: EditorSessionState
    let errorDescription: String
}

@MainActor
enum SessionRestoreAlertFactory {
    static func makeAlert(
        failure: SessionRestoreFailure,
        localization: MacPadLocalization
    ) -> NSAlert {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.string(.sessionRestoreSingleFailure)
        let fileName = failure.state.fileReference.map {
            URL(fileURLWithPath: $0.path).lastPathComponent
        } ?? localization.string(.untitled)
        alert.informativeText = localization.sessionRestoreDetail(
            fileName: fileName,
            errorDescription: failure.errorDescription
        )
        let locateButton = alert.addButton(withTitle: localization.string(.locate))
        locateButton.identifier = NSUserInterfaceItemIdentifier("sessionRestore.locate")
        let skipButton = alert.addButton(withTitle: localization.string(.skip))
        skipButton.identifier = NSUserInterfaceItemIdentifier("sessionRestore.skip")
        let cancelButton = alert.addButton(withTitle: localization.string(.cancelRestore))
        cancelButton.identifier = NSUserInterfaceItemIdentifier("sessionRestore.cancel")
        return alert
    }
}

private struct PreflightRestoredTab {
    let originalIndex: Int
    let controller: EditorWindowController
}

private struct PreflightRestoredWindow {
    let session: EditorWindowSessionState
    var tabs: [PreflightRestoredTab]
}

@MainActor
enum EditorWindowRecency {
    static func movingWindowGroupToEnd(
        containing activeController: EditorWindowController,
        in controllers: [EditorWindowController]
    ) -> [EditorWindowController] {
        guard let activeWindow = activeController.window else { return controllers }
        let groupWindows: [NSWindow]
        if let tabbedWindows = activeWindow.tabbedWindows, !tabbedWindows.isEmpty {
            groupWindows = tabbedWindows
        } else {
            groupWindows = [activeWindow]
        }
        let groupIdentifiers = Set(groupWindows.map(ObjectIdentifier.init))
        let inactiveControllers = controllers.filter { controller in
            guard let window = controller.window else { return true }
            return !groupIdentifiers.contains(ObjectIdentifier(window))
        }
        var activeGroupControllers = controllers.filter { controller in
            guard let window = controller.window else { return false }
            return groupIdentifiers.contains(ObjectIdentifier(window))
        }
        if let activeIndex = activeGroupControllers.firstIndex(where: { $0 === activeController }) {
            let active = activeGroupControllers.remove(at: activeIndex)
            activeGroupControllers.append(active)
        }
        return inactiveControllers + activeGroupControllers
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuItemValidation, NSMenuDelegate {
    private static let preferencesLogger = Logger(
        subsystem: "local.macpad.app",
        category: "preferences"
    )
    private let sessionDefaultsKey = "MacPad.SessionState.v1"
    private let menuBarDefaultsKey = "MacPad.ShowInMenuBar"
    private let defaults: UserDefaults
    private let localization: MacPadLocalization
    private let distributionChannel: DistributionChannel
    private let customerRoutes: CustomerRoutes
    private let fileAccess: SecurityScopedFileAccess
    private let recentDocumentStore: RecentDocumentStore
    private let sessionLogger = Logger(subsystem: "local.macpad.app", category: "session")
    private let recentDocumentLogger = Logger(
        subsystem: "local.macpad.app",
        category: "recent-documents"
    )
    private var windows: [EditorWindowController] = []
    private var isRestoringSession = false
    private var pendingOpenURLs: [URL] = []
    private var hasFinishedLaunching = false
    private weak var lastActiveWindowController: EditorWindowController?
    private var preferredFont = EditorWindowController.defaultEditorFont
    private(set) var menuBarStatusItem: NSStatusItem?

    override init() {
        defaults = .standard
        localization = MacPadLocalization(bundle: .main)
        distributionChannel = .current
        customerRoutes = .current(for: .current)
        fileAccess = SecurityScopedFileAccess(
            requiresBookmark: DistributionChannel.current.requiresPersistentSecurityScope
        )
        recentDocumentStore = RecentDocumentStore(
            defaults: .standard,
            defaultsKey: "MacPad.RecentDocumentBookmarks.v1",
            maximumCount: 20
        )
        super.init()
        preferredFont = Self.loadPreferredFont()
    }

    init(
        defaults: UserDefaults,
        localization: MacPadLocalization,
        distributionChannel: DistributionChannel,
        customerRoutes: CustomerRoutes,
        fileAccess: SecurityScopedFileAccess,
        recentDocumentStore: RecentDocumentStore
    ) {
        self.defaults = defaults
        self.localization = localization
        self.distributionChannel = distributionChannel
        self.customerRoutes = customerRoutes
        self.fileAccess = fileAccess
        self.recentDocumentStore = recentDocumentStore
        super.init()
        preferredFont = Self.loadPreferredFont()
    }

    var isMenuBarEnabled: Bool {
        defaults.bool(forKey: menuBarDefaultsKey)
    }

    var editorWindowCount: Int {
        windows.count
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let application = NSApplication.shared
        application.mainMenu = MainMenuFactory.makeMenu(
            target: self,
            application: application,
            localization: localization,
            distributionChannel: distributionChannel,
            customerRoutes: customerRoutes
        )
        updateMenuBarStatusItem()

        let launchURLs = pendingOpenURLs
        pendingOpenURLs.removeAll()
        hasFinishedLaunching = true

        if !launchURLs.isEmpty {
            for url in launchURLs {
                openDocument(url: url)
            }
        } else if restorePreviousSession() == .noSession {
            openNewDocument(nil)
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        !isMenuBarEnabled
    }

    func applicationShouldHandleReopen(
        _ sender: NSApplication,
        hasVisibleWindows flag: Bool
    ) -> Bool {
        if !flag {
            openNewWindow(nil)
        }
        return false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        var confirmedControllers: [EditorWindowController] = []
        for controller in windows {
            if !controller.confirmDiscardIfNeeded() {
                for confirmedController in confirmedControllers {
                    confirmedController.keepInSessionRestore()
                }
                saveSessionNow()
                return .terminateCancel
            }
            confirmedControllers.append(controller)
        }
        saveSessionNow()
        return .terminateNow
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        guard hasFinishedLaunching else {
            pendingOpenURLs.append(contentsOf: urls)
            return
        }

        for url in urls {
            openDocument(url: url)
        }
    }

    @objc func showAbout(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(options: [
            .credits: aboutCredits()
        ])
    }

    @objc func openNewDocument(_ sender: Any?) {
        openNewWindow(sender)
    }

    @objc func openNewWindow(_ sender: Any?) {
        present(makeWindowController(), asTab: false)
    }

    @objc func openNewTab(_ sender: Any?) {
        present(makeWindowController(), asTab: keyWindowController != nil)
    }

    @objc func openDocument(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            openDocument(url: url)
        }
    }

    @objc func openRecentDocument(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let reference = item.representedObject as? PersistedFileReference else {
            assertionFailure("Open Recent requires a persisted file reference.")
            return
        }
        openDocument(reference: reference)
    }

    @objc func clearRecentDocuments(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(sender)
        recentDocumentStore.clear()
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.identifier == NSUserInterfaceItemIdentifier("file.openRecent") else { return }
        populateRecentDocumentsMenu(
            menu,
            nativeURLs: NSDocumentController.shared.recentDocumentURLs
        )
    }

    func populateRecentDocumentsMenu(_ menu: NSMenu, nativeURLs: [URL]) {
        do {
            let references = if distributionChannel == .direct {
                try recentDocumentStore.directReferences(inNativeOrder: nativeURLs)
            } else {
                try recentDocumentStore.references(inNativeOrder: nativeURLs)
            }
            RecentDocumentsMenuBuilder.populate(
                menu,
                references: references,
                target: self,
                localization: localization
            )
        } catch {
            recentDocumentLogger.error(
                "Could not load recent documents: \(error.localizedDescription, privacy: .public)"
            )
            RecentDocumentsMenuBuilder.populateUnavailable(
                menu,
                target: self,
                localization: localization
            )
        }
    }

    @objc func clearSessionData(_ sender: Any?) {
        cancelScheduledSessionSave()
        defaults.removeObject(forKey: sessionDefaultsKey)
        for controller in windows {
            controller.discardFromSessionRestore()
        }
    }

    @objc func toggleMenuBarVisibility(_ sender: Any?) {
        let enabled = !isMenuBarEnabled
        defaults.set(enabled, forKey: menuBarDefaultsKey)
        updateMenuBarStatusItem()
        if !enabled, windows.isEmpty {
            openNewWindow(sender)
        }
    }

    @objc func handleMenuBarStatusItem(_ sender: Any?) {
        openNewWindow(sender)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openDocument(url: URL) {
        do {
            let reference = try fileAccess.makeReference(for: url)
            openDocument(reference: reference)
        } catch {
            showOpenError(url: url, error: error)
        }
    }

    private func openDocument(reference: PersistedFileReference) {
        if let existingController = EditorWindowResolver.controller(
            opening: reference,
            controllers: windows
        ) {
            recordWindowActivity(existingController)
            existingController.showWindow(nil)
            existingController.window?.makeKeyAndOrderFront(nil)
            if let currentReference = existingController.fileReference {
                recordRecentDocument(currentReference)
            }
            return
        }

        do {
            let controller = try EditorWindowResolver.makeController(
                opening: reference,
                baseFont: preferredFont,
                localization: localization,
                fileAccess: fileAccess
            )
            configure(controller)
            present(controller, asTab: keyWindowController != nil)
            if let currentReference = controller.fileReference {
                recordRecentDocument(currentReference)
            }
        } catch {
            showOpenError(
                url: URL(fileURLWithPath: reference.path),
                error: error
            )
        }
    }

    private func makeWindowController() -> EditorWindowController {
        let controller = makeUnconfiguredWindowController()
        configure(controller)
        return controller
    }

    private func makeUnconfiguredWindowController() -> EditorWindowController {
        let controller = EditorWindowController(
            baseFont: preferredFont,
            localization: localization,
            fileAccess: fileAccess
        )
        return controller
    }

    private func configure(_ controller: EditorWindowController) {
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windows.removeAll { $0 === controller }
            self?.saveSessionNow()
        }
        controller.onStateChange = { [weak self] in
            self?.scheduleSessionSave()
        }
        controller.onActivate = { [weak self, weak controller] in
            guard let controller else { return }
            self?.recordWindowActivity(controller)
        }
        controller.onFontChange = { [weak self] font in
            self?.storePreferredFont(font)
        }
        controller.onSuccessfulSave = { [weak self] transition in
            self?.recordSuccessfulFileTransition(transition)
        }
    }

    private func present(_ controller: EditorWindowController, asTab: Bool) {
        presentWithoutSessionSave(controller, asTab: asTab)
        saveSessionNow()
    }

    private func presentWithoutSessionSave(
        _ controller: EditorWindowController,
        asTab: Bool
    ) {
        let parentWindow = asTab ? keyWindowController?.window : nil
        windows.append(controller)
        controller.showWindow(nil)

        if let parentWindow,
           let newWindow = controller.window,
           parentWindow !== newWindow {
            parentWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        }

        recordWindowActivity(controller)
    }

    private func recordWindowActivity(_ controller: EditorWindowController) {
        windows = EditorWindowRecency.movingWindowGroupToEnd(
            containing: controller,
            in: windows
        )
        lastActiveWindowController = controller
    }

    private var keyWindowController: EditorWindowController? {
        EditorWindowResolver.resolve(
            controllers: windows,
            mainWindow: NSApp.mainWindow,
            keyWindow: NSApp.keyWindow,
            lastActive: lastActiveWindowController
        )
    }

    func aboutCredits() -> NSAttributedString {
        let creator = "anvilfilbert"
        let repository = "anvilfilbert/MacPad"
        let text: String
        if distributionChannel == .direct {
            text = [
                localization.aboutCreatedBy(creator: creator),
                localization.aboutPublicRepository(repository: repository)
            ].joined(separator: "\n")
        } else {
            text = localization.aboutCreatedBy(creator: creator)
        }
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let credits = NSMutableAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: 11),
                .foregroundColor: NSColor.secondaryLabelColor,
                .paragraphStyle: paragraph
            ]
        )
        if distributionChannel == .direct {
            addLink(to: creator, in: credits, url: customerRoutes.creatorProfileURL)
            addLink(to: repository, in: credits, url: customerRoutes.productURL)
        }
        return credits
    }

    private func addLink(
        to substring: String,
        in credits: NSMutableAttributedString,
        url: URL?
    ) {
        let range = (credits.string as NSString).range(of: substring)
        guard range.location != NSNotFound, let url else { return }
        credits.addAttributes(
            [
                .link: url,
                .foregroundColor: NSColor.linkColor,
                .underlineStyle: NSUnderlineStyle.single.rawValue
            ],
            range: range
        )
    }

    @objc func save(_ sender: Any?) { keyWindowController?.save(sender) }
    @objc func saveAs(_ sender: Any?) { keyWindowController?.saveAs(sender) }
    @objc func printDocument(_ sender: Any?) { keyWindowController?.printDocument(sender) }
    @objc func toggleWordWrap(_ sender: Any?) { keyWindowController?.toggleWordWrap(sender) }
    @objc func toggleStatusBar(_ sender: Any?) { keyWindowController?.toggleStatusBar(sender) }
    @objc func showFind(_ sender: Any?) { keyWindowController?.showFind(sender) }
    @objc func showReplace(_ sender: Any?) { keyWindowController?.showReplace(sender) }
    @objc func findNext(_ sender: Any?) { keyWindowController?.findNext(sender) }
    @objc func findPrevious(_ sender: Any?) { keyWindowController?.findPrevious(sender) }
    @objc func goToLine(_ sender: Any?) { keyWindowController?.goToLine(sender) }
    @objc func insertTimeDate(_ sender: Any?) { keyWindowController?.insertTimeDate(sender) }
    @objc func zoomIn(_ sender: Any?) { keyWindowController?.zoomIn(sender) }
    @objc func zoomOut(_ sender: Any?) { keyWindowController?.zoomOut(sender) }
    @objc func restoreZoom(_ sender: Any?) { keyWindowController?.restoreZoom(sender) }
    @objc func chooseFont(_ sender: Any?) { keyWindowController?.chooseFont(sender) }

    @objc func openHelp(_ sender: Any?) {
        openCustomerURL(customerRoutes.helpURL, routeName: "Help")
    }

    @objc func reportIssue(_ sender: Any?) {
        openCustomerURL(customerRoutes.supportURL, routeName: "support")
    }

    @objc func openPrivacy(_ sender: Any?) {
        openCustomerURL(customerRoutes.privacyURL, routeName: "privacy")
    }

    @objc func openSecurity(_ sender: Any?) {
        openCustomerURL(customerRoutes.securityURL, routeName: "security")
    }

    @objc func checkForUpdates(_ sender: Any?) {
        guard distributionChannel.showsDirectUpdateCommand else {
            assertionFailure("The App Store channel cannot open direct updates.")
            return
        }
        openCustomerURL(customerRoutes.updateURL, routeName: "update")
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        if menuItem.action == #selector(toggleWordWrap(_:)) {
            menuItem.state = keyWindowController?.isWordWrapEnabled == true ? .on : .off
            return keyWindowController != nil
        }
        if menuItem.action == #selector(toggleStatusBar(_:)) {
            menuItem.state = keyWindowController?.isStatusBarVisible == true ? .on : .off
            return keyWindowController != nil
        }
        if menuItem.action == #selector(toggleMenuBarVisibility(_:)) {
            menuItem.state = isMenuBarEnabled ? .on : .off
            return true
        }
        return true
    }

    private func updateMenuBarStatusItem() {
        if isMenuBarEnabled {
            guard menuBarStatusItem == nil else { return }
            let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            guard let button = statusItem.button else {
                NSStatusBar.system.removeStatusItem(statusItem)
                defaults.set(false, forKey: menuBarDefaultsKey)
                let alert = NSAlert()
                alert.alertStyle = .warning
                alert.messageText = localization.string(.menuBarCreationFailure)
                alert.informativeText = localization.string(.menuBarButtonUnavailable)
                alert.runModal()
                return
            }

            let icon = NSApp.applicationIconImage.copy() as? NSImage
            icon?.size = NSSize(width: 18, height: 18)
            button.image = icon
            button.imageScaling = .scaleProportionallyDown
            button.target = self
            button.action = #selector(handleMenuBarStatusItem(_:))
            button.sendAction(on: [.leftMouseUp])
            let openWindowDescription = localization.string(.menuBarOpenNewWindow)
            button.toolTip = openWindowDescription
            button.setAccessibilityLabel(openWindowDescription)
            menuBarStatusItem = statusItem
            return
        }

        if let statusItem = menuBarStatusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            menuBarStatusItem = nil
        }
    }

    private func restorePreviousSession() -> SessionRestoreOutcome {
        restorePreviousSession(
            recoveryDecision: { failure in
                self.showSessionRestoreRecovery(failure)
            },
            locateURL: {
                self.locateSessionRestoreFile()
            }
        )
    }

    func restorePreviousSession(
        recoveryDecision: (SessionRestoreFailure) -> SessionRestoreRecoveryDecision,
        locateURL: () -> URL?
    ) -> SessionRestoreOutcome {
        guard let data = defaults.data(forKey: sessionDefaultsKey) else {
            return .noSession
        }

        let session: AppSessionState
        do {
            session = try AppSessionState.decode(data: data, localization: localization)
        } catch {
            defaults.removeObject(forKey: sessionDefaultsKey)
            sessionLogger.error(
                "Discarded invalid session state: \(error.localizedDescription, privacy: .public)"
            )
            showSessionRestoreError(filePath: nil, error: error)
            return .noSession
        }
        guard !session.windows.isEmpty else { return .noSession }

        isRestoringSession = true

        var preflightWindows = session.windows.map {
            PreflightRestoredWindow(session: $0, tabs: [])
        }
        var failures: [SessionRestoreFailure] = []
        for (windowIndex, windowSession) in session.windows.enumerated() {
            for (tabIndex, tab) in windowSession.tabs.enumerated() {
                let controller = makeUnconfiguredWindowController()
                do {
                    try controller.restoreSessionState(tab)
                    preflightWindows[windowIndex].tabs.append(
                        PreflightRestoredTab(
                            originalIndex: tabIndex,
                            controller: controller
                        )
                    )
                } catch {
                    failures.append(
                        SessionRestoreFailure(
                            windowIndex: windowIndex,
                            tabIndex: tabIndex,
                            state: tab,
                            errorDescription: macPadLocalizedDescription(
                                error,
                                using: localization
                            )
                        )
                    )
                }
            }
        }

        while let failure = failures.first {
            switch recoveryDecision(failure) {
            case .cancel:
                isRestoringSession = false
                return .cancelled
            case .skip:
                failures.removeFirst()
            case .locate:
                guard let url = locateURL() else { continue }
                do {
                    let reference = try fileAccess.makeReference(for: url)
                    let locatedState = replacingFileReference(
                        in: failure.state,
                        with: reference
                    )
                    let controller = makeUnconfiguredWindowController()
                    try controller.restoreSessionState(locatedState)
                    preflightWindows[failure.windowIndex].tabs.append(
                        PreflightRestoredTab(
                            originalIndex: failure.tabIndex,
                            controller: controller
                        )
                    )
                    failures.removeFirst()
                } catch {
                    failures[0] = SessionRestoreFailure(
                        windowIndex: failure.windowIndex,
                        tabIndex: failure.tabIndex,
                        state: failure.state,
                        errorDescription: macPadLocalizedDescription(
                            error,
                            using: localization
                        )
                    )
                }
            }
        }

        for preflightWindow in preflightWindows {
            let orderedTabs = preflightWindow.tabs.sorted {
                $0.originalIndex < $1.originalIndex
            }
            for (index, tab) in orderedTabs.enumerated() {
                configure(tab.controller)
                presentWithoutSessionSave(tab.controller, asTab: index > 0)
            }
            if let firstWindow = orderedTabs.first?.controller.window {
                restoreFrame(preflightWindow.session.frame, to: firstWindow)
            }
            let selectedController = orderedTabs.first {
                $0.originalIndex == preflightWindow.session.selectedTabIndex
            }?.controller ?? orderedTabs.first?.controller
            selectedController?.window?.makeKeyAndOrderFront(nil)
        }

        isRestoringSession = false
        saveSessionNow()
        return .restored
    }

    private func showSessionRestoreRecovery(
        _ failure: SessionRestoreFailure
    ) -> SessionRestoreRecoveryDecision {
        let alert = SessionRestoreAlertFactory.makeAlert(
            failure: failure,
            localization: localization
        )
        switch alert.runModal() {
        case .alertFirstButtonReturn:
            return .locate
        case .alertSecondButtonReturn:
            return .skip
        default:
            return .cancel
        }
    }

    private func locateSessionRestoreFile() -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.plainText, .text]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK else { return nil }
        return panel.url
    }

    private func replacingFileReference(
        in state: EditorSessionState,
        with reference: PersistedFileReference
    ) -> EditorSessionState {
        EditorSessionState(
            id: state.id,
            fileReference: reference,
            selectedLocation: state.selectedLocation,
            wordWrapEnabled: state.wordWrapEnabled,
            statusBarVisible: state.statusBarVisible,
            zoomPercent: state.zoomPercent,
            lineEnding: state.lineEnding
        )
    }

    private func scheduleSessionSave() {
        guard !isRestoringSession else { return }
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(persistScheduledSession),
            object: nil
        )
        perform(#selector(persistScheduledSession), with: nil, afterDelay: 0.25)
    }

    private func saveSessionNow() {
        cancelScheduledSessionSave()
        writeSession()
    }

    private func cancelScheduledSessionSave() {
        NSObject.cancelPreviousPerformRequests(
            withTarget: self,
            selector: #selector(persistScheduledSession),
            object: nil
        )
    }

    @objc private func persistScheduledSession() {
        writeSession()
    }

    private func writeSession() {
        guard !isRestoringSession else { return }

        let windowSessions = currentWindowSessions()
        guard !windowSessions.isEmpty else {
            defaults.removeObject(forKey: sessionDefaultsKey)
            return
        }
        if windowSessions.count > AppSessionState.maximumWindowCount {
            sessionLogger.warning(
                "Session window limit exceeded; total: \(windowSessions.count, privacy: .public), retained: \(AppSessionState.maximumWindowCount, privacy: .public)"
            )
        }

        do {
            let data = try JSONEncoder().encode(AppSessionState(windows: windowSessions))
            defaults.set(data, forKey: sessionDefaultsKey)
        } catch {
            sessionLogger.error(
                "Could not encode session state: \(error.localizedDescription, privacy: .public)"
            )
        }
    }

    private func currentWindowSessions() -> [EditorWindowSessionState] {
        let controllerByWindow = Dictionary(
            uniqueKeysWithValues: windows.compactMap { controller -> (ObjectIdentifier, EditorWindowController)? in
                guard let window = controller.window else { return nil }
                return (ObjectIdentifier(window), controller)
            }
        )
        var seenWindows = Set<ObjectIdentifier>()
        var sessions: [EditorWindowSessionState] = []

        for controller in windows {
            guard let window = controller.window else { continue }
            let tabbedWindows = window.tabbedWindows ?? [window]
            let orderedWindows = tabbedWindows.isEmpty ? [window] : tabbedWindows
            let identifiers = orderedWindows.map(ObjectIdentifier.init)

            if identifiers.contains(where: seenWindows.contains) {
                continue
            }

            for identifier in identifiers {
                seenWindows.insert(identifier)
            }

            let tabEntries: [(window: NSWindow, state: EditorSessionState)] = orderedWindows.compactMap { tabWindow in
                guard let state = controllerByWindow[ObjectIdentifier(tabWindow)]?.sessionState else {
                    return nil
                }
                return (tabWindow, state)
            }
            let tabs = tabEntries.map(\.state)
            if tabs.count > AppSessionState.maximumTabsPerWindow {
                sessionLogger.warning(
                    "Session tab limit exceeded; total: \(tabs.count, privacy: .public), retained: \(AppSessionState.maximumTabsPerWindow, privacy: .public)"
                )
            }

            if !tabs.isEmpty {
                let selectedWindow = window.tabGroup?.selectedWindow ?? window
                let selectedIndex = tabEntries.firstIndex { $0.window === selectedWindow } ?? 0
                let frame = orderedWindows.first.map { windowFrameState($0.frame) }
                let visualIndexByWindow = Dictionary(
                    uniqueKeysWithValues: tabEntries.enumerated().map { index, entry in
                        (ObjectIdentifier(entry.window), index)
                    }
                )
                let recentlyUsedTabIndices = windows.compactMap { recentController -> Int? in
                    guard let recentWindow = recentController.window else { return nil }
                    return visualIndexByWindow[ObjectIdentifier(recentWindow)]
                }
                sessions.append(
                    EditorWindowSessionState(
                        tabs: tabs,
                        selectedTabIndex: selectedIndex,
                        frame: frame,
                        recentlyUsedTabIndices: recentlyUsedTabIndices
                    )
                )
            }
        }

        return sessions
    }

    private func showSessionRestoreError(filePath: String?, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.string(.sessionRestoreSingleFailure)
        alert.informativeText = localization.sessionRestoreDetail(
            fileName: filePath ?? localization.string(.untitled),
            errorDescription: macPadLocalizedDescription(error, using: localization)
        )
        alert.runModal()
    }

    private func showSessionRestoreErrors(_ failures: [String]) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.string(.sessionRestoreMultipleFailure)
        alert.informativeText = failures.joined(separator: "\n")
        alert.runModal()
    }

    private func showOpenError(url: URL, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = localization.openFailure(fileName: url.lastPathComponent)
        alert.informativeText = macPadLocalizedDescription(error, using: localization)
        alert.runModal()
    }

    private func openCustomerURL(_ url: URL?, routeName: String) {
        guard let url else {
            assertionFailure("No customer route is configured for \(routeName).")
            return
        }
        guard NSWorkspace.shared.open(url) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = localization.string(.linkOpenFailure)
            alert.informativeText = url.absoluteString
            alert.runModal()
            return
        }
    }

    private static func loadPreferredFont() -> NSFont {
        do {
            return try EditorFontPreferences.load(from: .standard)
                ?? EditorWindowController.defaultEditorFont
        } catch {
            UserDefaults.standard.removeObject(forKey: EditorFontPreferences.defaultsKey)
            preferencesLogger.error(
                "Discarded invalid editor font preference: \(error.localizedDescription, privacy: .public)"
            )
            return EditorWindowController.defaultEditorFont
        }
    }

    private func storePreferredFont(_ font: NSFont) {
        do {
            try EditorFontPreferences.save(font, to: .standard)
            preferredFont = font
            for controller in windows {
                controller.applyPreferredFont(font)
            }
        } catch {
            Self.preferencesLogger.error(
                "Could not save editor font preference: \(error.localizedDescription, privacy: .public)"
            )
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = localization.string(.fontSaveFailure)
            alert.informativeText = macPadLocalizedDescription(error, using: localization)
            alert.runModal()
        }
    }

    private func recordRecentDocument(_ reference: PersistedFileReference) {
        do {
            try recentDocumentStore.add(reference)
            noteNativeRecentDocument(reference)
        } catch {
            showRecentDocumentError(error)
        }
    }

    private func recordSuccessfulFileTransition(_ transition: SuccessfulFileTransition) {
        do {
            try recentDocumentStore.replace(
                transition.previousReference,
                with: transition.currentReference
            )
            noteNativeRecentDocument(transition.currentReference)
        } catch {
            showRecentDocumentError(error)
        }
    }

    private func noteNativeRecentDocument(_ reference: PersistedFileReference) {
        NSDocumentController.shared.noteNewRecentDocumentURL(
            URL(fileURLWithPath: reference.path)
                .resolvingSymlinksInPath()
                .standardizedFileURL
        )
    }

    private func showRecentDocumentError(_ error: any Error) {
        recentDocumentLogger.error(
            "Could not update recent documents: \(error.localizedDescription, privacy: .public)"
        )
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = localization.string(.recentDocumentsUnavailable)
        alert.informativeText = macPadLocalizedDescription(error, using: localization)
        alert.runModal()
    }

    private func windowFrameState(_ frame: NSRect) -> WindowFrameState {
        WindowFrameState(
            x: frame.origin.x,
            y: frame.origin.y,
            width: frame.size.width,
            height: frame.size.height
        )
    }

    private func restoreFrame(_ frameState: WindowFrameState?, to window: NSWindow) {
        guard let frameState else { return }
        let frame = NSRect(
            x: frameState.x,
            y: frameState.y,
            width: frameState.width,
            height: frameState.height
        )
        let targetScreen = NSScreen.screens.first { $0.frame.intersects(frame) } ?? NSScreen.main
        let constrainedFrame = targetScreen.map { window.constrainFrameRect(frame, to: $0) } ?? frame
        window.setFrame(constrainedFrame, display: false)
    }
}
