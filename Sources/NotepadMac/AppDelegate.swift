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
        opening url: URL,
        controllers: [EditorWindowController]
    ) -> EditorWindowController? {
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        return controllers.first { controller in
            controller.fileURL?.standardizedFileURL == resolvedURL
        }
    }

    static func makeController(opening url: URL) throws -> EditorWindowController {
        let controller = EditorWindowController()
        try controller.loadFile(url)
        return controller
    }

    static func makeController(opening url: URL, baseFont: NSFont) throws -> EditorWindowController {
        let controller = EditorWindowController(baseFont: baseFont)
        try controller.loadFile(url)
        return controller
    }
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
    private let sessionLogger = Logger(subsystem: "local.macpad.app", category: "session")
    private var windows: [EditorWindowController] = []
    private var isRestoringSession = false
    private var pendingOpenURLs: [URL] = []
    private var hasFinishedLaunching = false
    private weak var lastActiveWindowController: EditorWindowController?
    private var preferredFont = EditorWindowController.defaultEditorFont
    private(set) var menuBarStatusItem: NSStatusItem?

    override init() {
        defaults = .standard
        super.init()
        preferredFont = Self.loadPreferredFont()
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
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
        application.mainMenu = MainMenuFactory.makeMenu(target: self, application: application)
        updateMenuBarStatusItem()

        let launchURLs = pendingOpenURLs
        pendingOpenURLs.removeAll()
        hasFinishedLaunching = true

        if !launchURLs.isEmpty {
            for url in launchURLs {
                openDocument(url: url)
            }
        } else if !restorePreviousSession() {
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
              let url = item.representedObject as? URL else {
            assertionFailure("Open Recent requires a menu item containing a file URL.")
            return
        }
        openDocument(url: url)
    }

    @objc func clearRecentDocuments(_ sender: Any?) {
        NSDocumentController.shared.clearRecentDocuments(sender)
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        guard menu.title == "Open Recent" else { return }
        RecentDocumentsMenuBuilder.populate(
            menu,
            urls: NSDocumentController.shared.recentDocumentURLs,
            target: self
        )
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
        if let existingController = EditorWindowResolver.controller(
            opening: url,
            controllers: windows
        ) {
            recordWindowActivity(existingController)
            existingController.showWindow(nil)
            existingController.window?.makeKeyAndOrderFront(nil)
            noteRecentDocument(existingController.fileURL ?? url)
            return
        }

        do {
            let controller = try EditorWindowResolver.makeController(
                opening: url,
                baseFont: preferredFont
            )
            configure(controller)
            present(controller, asTab: keyWindowController != nil)
            noteRecentDocument(controller.fileURL ?? url)
        } catch {
            showOpenError(url: url, error: error)
        }
    }

    private func makeWindowController() -> EditorWindowController {
        let controller = EditorWindowController(baseFont: preferredFont)
        configure(controller)
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
        controller.onSuccessfulSave = { [weak self] url in
            self?.noteRecentDocument(url)
        }
        controller.onOpenDroppedFiles = { [weak self] urls in
            guard let self else { return }
            for url in urls {
                self.openDocument(url: url)
            }
        }
    }

    private func present(_ controller: EditorWindowController, asTab: Bool) {
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
        saveSessionNow()
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

    private func aboutCredits() -> NSAttributedString {
        let text = "Created by anvilfilbert\nPublic repo: anvilfilbert/MacPad"
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
        addLink(
            to: "anvilfilbert",
            in: credits,
            url: "https://github.com/anvilfilbert"
        )
        addLink(
            to: "anvilfilbert/MacPad",
            in: credits,
            url: "https://github.com/anvilfilbert/MacPad"
        )
        return credits
    }

    private func addLink(to substring: String, in credits: NSMutableAttributedString, url: String) {
        let range = (credits.string as NSString).range(of: substring)
        guard range.location != NSNotFound, let url = URL(string: url) else { return }
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
        openProjectURL("https://github.com/anvilfilbert/MacPad/wiki")
    }

    @objc func reportIssue(_ sender: Any?) {
        openProjectURL("https://github.com/anvilfilbert/MacPad/issues/new/choose")
    }

    @objc func checkForUpdates(_ sender: Any?) {
        openProjectURL("https://github.com/anvilfilbert/MacPad/releases/latest")
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
                alert.messageText = "Could not add MacPad to the menu bar."
                alert.informativeText = "macOS did not provide a menu-bar button."
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
            button.toolTip = "Open a new MacPad window"
            button.setAccessibilityLabel("Open a new MacPad window")
            menuBarStatusItem = statusItem
            return
        }

        if let statusItem = menuBarStatusItem {
            NSStatusBar.system.removeStatusItem(statusItem)
            menuBarStatusItem = nil
        }
    }

    private func restorePreviousSession() -> Bool {
        guard let data = defaults.data(forKey: sessionDefaultsKey) else {
            return false
        }

        let session: AppSessionState
        do {
            session = try JSONDecoder().decode(AppSessionState.self, from: data)
        } catch {
            defaults.removeObject(forKey: sessionDefaultsKey)
            sessionLogger.error(
                "Discarded invalid session state: \(error.localizedDescription, privacy: .public)"
            )
            showSessionRestoreError(filePath: nil, error: error)
            return false
        }
        guard !session.windows.isEmpty else { return false }

        isRestoringSession = true
        defer {
            isRestoringSession = false
            saveSessionNow()
        }

        var restoreFailures: [String] = []
        for windowSession in session.windows {
            var restoredControllers: [(originalIndex: Int, controller: EditorWindowController)] = []
            for (index, tab) in windowSession.tabs.enumerated() {
                let controller = makeWindowController()
                do {
                    try controller.restoreSessionState(tab)
                    present(controller, asTab: !restoredControllers.isEmpty)
                    restoredControllers.append((index, controller))
                } catch {
                    restoreFailures.append("\(tab.filePath ?? "Untitled"): \(error.localizedDescription)")
                }
            }

            if let firstWindow = restoredControllers.first?.controller.window {
                restoreFrame(windowSession.frame, to: firstWindow)
            }
            let selectedController = restoredControllers.first {
                $0.originalIndex == windowSession.selectedTabIndex
            }?.controller ?? restoredControllers.first?.controller
            selectedController?.window?.makeKeyAndOrderFront(nil)
        }

        if !restoreFailures.isEmpty {
            showSessionRestoreErrors(restoreFailures)
        }

        return !windows.isEmpty
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
        alert.messageText = "Could not restore a previous MacPad tab."
        alert.informativeText = "\(filePath ?? "Untitled")\n\n\(error.localizedDescription)"
        alert.runModal()
    }

    private func showSessionRestoreErrors(_ failures: [String]) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Some previous MacPad tabs could not be restored."
        alert.informativeText = failures.joined(separator: "\n")
        alert.runModal()
    }

    private func showOpenError(url: URL, error: Error) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = "Could not open \(url.lastPathComponent)."
        alert.informativeText = error.localizedDescription
        alert.runModal()
    }

    private func openProjectURL(_ value: String) {
        guard let url = URL(string: value) else {
            assertionFailure("Invalid project URL: \(value)")
            return
        }
        guard NSWorkspace.shared.open(url) else {
            let alert = NSAlert()
            alert.alertStyle = .warning
            alert.messageText = "Could not open the link."
            alert.informativeText = value
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
            alert.messageText = "Could not save the editor font."
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
    }

    private func noteRecentDocument(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(
            url.resolvingSymlinksInPath().standardizedFileURL
        )
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
