import AppKit
import NotepadMacCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sessionDefaultsKey = "MacPad.SessionState.v1"
    private var windows: [EditorWindowController] = []
    private var isRestoringSession = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.mainMenu = MainMenuFactory.makeMenu(target: self)
        if !restorePreviousSession() {
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
                saveSession()
                return .terminateCancel
            }
            confirmedControllers.append(controller)
        }
        saveSession()
        return .terminateNow
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
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
        openNewTab(sender)
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
        UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
        for controller in windows {
            controller.discardFromSessionRestore()
        }
    }

    private func openDocument(url: URL) {
        let controller = makeWindowController()
        present(controller, asTab: keyWindowController != nil)
        controller.loadFile(url)
    }

    private func makeWindowController() -> EditorWindowController {
        let controller = EditorWindowController()
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windows.removeAll { $0 === controller }
            self?.saveSession()
        }
        controller.onStateChange = { [weak self] in
            self?.saveSession()
        }
        return controller
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

        saveSession()
    }

    private var keyWindowController: EditorWindowController? {
        windows.first { $0.window?.isKeyWindow == true } ?? windows.last
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
        guard let data = UserDefaults.standard.data(forKey: sessionDefaultsKey),
              let session = try? JSONDecoder().decode(AppSessionState.self, from: data),
              !session.windows.isEmpty else {
            return false
        }

        isRestoringSession = true
        defer {
            isRestoringSession = false
            saveSession()
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

    private func saveSession() {
        guard !isRestoringSession else { return }

        let windowSessions = currentWindowSessions()
        guard !windowSessions.isEmpty else {
            UserDefaults.standard.removeObject(forKey: sessionDefaultsKey)
            return
        }

        if let data = try? JSONEncoder().encode(AppSessionState(windows: windowSessions)) {
            UserDefaults.standard.set(data, forKey: sessionDefaultsKey)
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
