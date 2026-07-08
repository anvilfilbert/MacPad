import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var windows: [EditorWindowController] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.mainMenu = MainMenuFactory.makeMenu(target: self)
        openNewDocument(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        for controller in windows {
            if !controller.confirmDiscardIfNeeded() {
                return .terminateCancel
            }
        }
        return .terminateNow
    }

    func application(_ sender: NSApplication, open urls: [URL]) {
        for url in urls {
            openDocument(url: url)
        }
    }

    @objc func openNewDocument(_ sender: Any?) {
        let controller = EditorWindowController()
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windows.removeAll { $0 === controller }
        }
        windows.append(controller)
        controller.showWindow(nil)
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
        let controller = EditorWindowController()
        controller.onClose = { [weak self, weak controller] in
            guard let controller else { return }
            self?.windows.removeAll { $0 === controller }
        }
        windows.append(controller)
        controller.showWindow(nil)
        controller.loadFile(url)
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
}
