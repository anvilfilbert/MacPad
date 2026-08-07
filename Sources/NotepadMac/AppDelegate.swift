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
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sessionDefaultsKey = "MacPad.SessionState.v1"
    private let sessionLogger = Logger(subsystem: "local.macpad.app", category: "session")
    private var windows: [EditorWindowController] = []
    private var isRestoringSession = false
    private var pendingOpenURLs: [URL] = []
    private var hasFinishedLaunching = false
    private weak var lastActiveWindowController: EditorWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        let application = NSApplication.shared
        application.mainMenu = MainMenuFactory.makeMenu(target: self, application: application)

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
        true
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

    @objc func clearSessionData(_ sender: Any?) {
        cancelScheduledSessionSave()
        UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
        for controller in windows {
            controller.discardFromSessionRestore()
        }
    }

    private func openDocument(url: URL) {
        if let existingController = EditorWindowResolver.controller(
            opening: url,
            controllers: windows
        ) {
            lastActiveWindowController = existingController
            existingController.showWindow(nil)
            existingController.window?.makeKeyAndOrderFront(nil)
            return
        }

        let controller = makeWindowController()
        present(controller, asTab: keyWindowController != nil)
        controller.loadFile(url)
    }

    private func makeWindowController() -> EditorWindowController {
        let controller = EditorWindowController()
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windows.removeAll { $0 === controller }
            self?.saveSessionNow()
        }
        controller.onStateChange = { [weak self] in
            self?.scheduleSessionSave()
        }
        controller.onActivate = { [weak self, weak controller] in
            self?.lastActiveWindowController = controller
        }
        return controller
    }

    private func present(_ controller: EditorWindowController, asTab: Bool) {
        let parentWindow = asTab ? keyWindowController?.window : nil
        windows.append(controller)
        lastActiveWindowController = controller
        controller.showWindow(nil)

        if let parentWindow,
           let newWindow = controller.window,
           parentWindow !== newWindow {
            parentWindow.addTabbedWindow(newWindow, ordered: .above)
            newWindow.makeKeyAndOrderFront(nil)
        }

        saveSessionNow()
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

    private func restorePreviousSession() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: sessionDefaultsKey) else {
            return false
        }

        let session: AppSessionState
        do {
            session = try JSONDecoder().decode(AppSessionState.self, from: data)
        } catch {
            UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
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

        for windowSession in session.windows {
            var restoredTabs = 0
            for (index, tab) in windowSession.tabs.enumerated() {
                let controller = makeWindowController()
                do {
                    try controller.restoreSessionState(tab)
                    present(controller, asTab: index > 0 && restoredTabs > 0)
                    restoredTabs += 1
                } catch {
                    showSessionRestoreError(filePath: tab.filePath, error: error)
                }
            }
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
            UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
            return
        }

        do {
            let data = try JSONEncoder().encode(AppSessionState(windows: windowSessions))
            UserDefaults.standard.set(data, forKey: sessionDefaultsKey)
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

            let tabs = orderedWindows.compactMap { tabWindow in
                controllerByWindow[ObjectIdentifier(tabWindow)]?.sessionState
            }

            if !tabs.isEmpty {
                sessions.append(EditorWindowSessionState(tabs: tabs))
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
}
