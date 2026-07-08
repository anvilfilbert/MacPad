import AppKit
import NotepadMacCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let sessionDefaultsKey = "MacPad.SessionState.v1"
    private var windows: [EditorWindowController] = []
    private var isRestoringSession = false

    func applicationDidFinishLaunching(_ notification: Notification) {
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
        panel.allowedContentTypes = [.plainText, .text, .data]
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false

        guard panel.runModal() == .OK else { return }
        for url in panel.urls {
            openDocument(url: url)
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
            for (index, tab) in windowSession.tabs.enumerated() {
                let controller = makeWindowController()
                controller.restoreSessionState(tab)
                present(controller, asTab: index > 0)
            }
        }

        return true
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
}
