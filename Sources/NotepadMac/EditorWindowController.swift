import AppKit
import NotepadMacCore
import UniformTypeIdentifiers

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    var onClose: (() -> Void)?
    var onStateChange: (() -> Void)?

    private let scrollView = NSScrollView()
    private let textView = NSTextView()
    private let statusBar = NSTextField(labelWithString: "")
    private let defaultFontSize: CGFloat = 14
    private var stateID = UUID().uuidString
    private var fileURL: URL?
    private var originalText = ""
    private var lastFindTerm = ""
    private var findPanelController: FindPanelController?
    private var wordWrapEnabled = true
    private var statusBarVisible = true
    private var zoomPercent = 100
    private var baseFont: NSFont
    private var shouldRestoreInSession = true

    init() {
        baseFont = NSFont.monospacedSystemFont(ofSize: defaultFontSize, weight: .regular)
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 820, height: 580),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        super.init(window: window)
        window.title = "Untitled - MacPad"
        window.delegate = self
        window.tabbingMode = .preferred
        window.tabbingIdentifier = "MacPadEditor"
        window.center()
        setupUI()
        updateStatusBar()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadFile(_ url: URL) {
        do {
            let data = try Data(contentsOf: url)
            let text = String(data: data, encoding: .utf8)
                ?? String(data: data, encoding: .isoLatin1)
                ?? ""
            textView.string = text
            originalText = text
            fileURL = url
            shouldRestoreInSession = true
            updateTitle()
            updateStatusBar()
            notifyStateChanged()
        } catch {
            showError("Could not open the file.", detail: error.localizedDescription)
        }
    }

    var sessionState: EditorSessionState? {
        guard shouldRestoreInSession else { return nil }
        return EditorSessionState(
            id: stateID,
            filePath: fileURL?.path,
            text: textView.string,
            originalText: originalText,
            selectedLocation: textView.selectedRange().location,
            wordWrapEnabled: wordWrapEnabled,
            statusBarVisible: statusBarVisible,
            zoomPercent: zoomPercent
        )
    }

    func restoreSessionState(_ state: EditorSessionState) {
        stateID = state.id
        fileURL = state.filePath.map(URL.init(fileURLWithPath:))
        textView.string = state.text
        originalText = state.originalText
        wordWrapEnabled = state.wordWrapEnabled
        statusBarVisible = state.statusBarVisible
        statusBar.isHidden = !state.statusBarVisible
        zoomPercent = state.zoomPercent
        shouldRestoreInSession = true
        applyWordWrap()
        applyZoom()

        let location = min(max(0, state.selectedLocation), (textView.string as NSString).length)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        updateTitle()
        updateStatusBar()
    }

    @objc func save(_ sender: Any?) {
        if let fileURL {
            write(to: fileURL)
        } else {
            saveAs(sender)
        }
    }

    @objc func saveAs(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = fileURL?.lastPathComponent ?? "Untitled.txt"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        write(to: url)
    }

    @objc func printDocument(_ sender: Any?) {
        NSPrintOperation(view: textView).run()
    }

    @objc func toggleWordWrap(_ sender: Any?) {
        wordWrapEnabled.toggle()
        applyWordWrap()
        updateStatusBar()
        notifyStateChanged()
    }

    @objc func toggleStatusBar(_ sender: Any?) {
        statusBarVisible.toggle()
        statusBar.isHidden = !statusBarVisible
        updateStatusBar()
        notifyStateChanged()
    }

    @objc func showFind(_ sender: Any?) {
        makeFindPanel(showReplace: false)
    }

    @objc func showReplace(_ sender: Any?) {
        makeFindPanel(showReplace: true)
    }

    @objc func findNext(_ sender: Any?) {
        find(term: lastFindTerm, backwards: false)
    }

    @objc func findPrevious(_ sender: Any?) {
        find(term: lastFindTerm, backwards: true)
    }

    @objc func goToLine(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "Go To Line"
        alert.informativeText = "Line number:"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = "\(TextMetrics.cursorPosition(in: textView.string, selectedLocation: textView.selectedRange().location).line)"
        alert.accessoryView = input
        alert.addButton(withTitle: "Go To")
        alert.addButton(withTitle: "Cancel")

        guard alert.runModal() == .alertFirstButtonReturn,
              let lineNumber = Int(input.stringValue),
              lineNumber > 0 else { return }
        selectLine(lineNumber)
    }

    @objc func insertTimeDate(_ sender: Any?) {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        textView.insertText(formatter.string(from: Date()), replacementRange: textView.selectedRange())
    }

    @objc func zoomIn(_ sender: Any?) {
        zoomPercent = min(500, zoomPercent + 10)
        applyZoom()
        notifyStateChanged()
    }

    @objc func zoomOut(_ sender: Any?) {
        zoomPercent = max(10, zoomPercent - 10)
        applyZoom()
        notifyStateChanged()
    }

    @objc func restoreZoom(_ sender: Any?) {
        zoomPercent = 100
        applyZoom()
        notifyStateChanged()
    }

    @objc func chooseFont(_ sender: Any?) {
        NSFontManager.shared.target = self
        NSFontManager.shared.setSelectedFont(baseFont, isMultiple: false)
        NSFontManager.shared.orderFrontFontPanel(sender)
    }

    @objc func changeFont(_ sender: NSFontManager?) {
        guard let sender else { return }
        baseFont = sender.convert(baseFont)
        applyZoom()
        notifyStateChanged()
    }

    func confirmDiscardIfNeeded() -> Bool {
        guard hasUnsavedChanges else { return true }

        let alert = NSAlert()
        alert.messageText = "Do you want to save changes to this document?"
        alert.informativeText = "Your changes will be lost if you do not save them."
        alert.addButton(withTitle: "Save")
        alert.addButton(withTitle: "Don't Save")
        alert.addButton(withTitle: "Cancel")
        alert.alertStyle = .warning

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            save(nil)
            return !hasUnsavedChanges
        case .alertSecondButtonReturn:
            shouldRestoreInSession = false
            notifyStateChanged()
            return true
        default:
            return false
        }
    }

    func keepInSessionRestore() {
        shouldRestoreInSession = true
        notifyStateChanged()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmDiscardIfNeeded()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func textDidChange(_ notification: Notification) {
        shouldRestoreInSession = true
        updateTitle()
        updateStatusBar()
        notifyStateChanged()
    }

    func textViewDidChangeSelection(_ notification: Notification) {
        updateStatusBar()
        notifyStateChanged()
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.spacing = 0
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor)
        ])

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .noBorder
        scrollView.autohidesScrollers = false
        scrollView.drawsBackground = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isRichText = false
        textView.importsGraphics = false
        textView.allowsUndo = true
        textView.usesFindPanel = false
        textView.font = baseFont
        textView.textColor = .textColor
        textView.backgroundColor = .textBackgroundColor
        textView.insertionPointColor = .textColor
        textView.delegate = self
        textView.textContainerInset = NSSize(width: 6, height: 6)
        textView.autoresizingMask = [.width]
        textView.enabledTextCheckingTypes = NSTextCheckingResult.CheckingType.spelling.rawValue

        scrollView.documentView = textView
        stack.addArrangedSubview(scrollView)

        statusBar.font = .monospacedSystemFont(ofSize: 12, weight: .regular)
        statusBar.textColor = .secondaryLabelColor
        statusBar.backgroundColor = .windowBackgroundColor
        statusBar.isBordered = false
        statusBar.isEditable = false
        statusBar.alignment = .right
        statusBar.lineBreakMode = .byTruncatingHead
        statusBar.setContentHuggingPriority(.required, for: .vertical)
        statusBar.heightAnchor.constraint(equalToConstant: 24).isActive = true
        stack.addArrangedSubview(statusBar)

        applyWordWrap()
        window?.makeFirstResponder(textView)
    }

    private func write(to url: URL) {
        do {
            let text = TextMetrics.normalizedLineEndingsForSave(textView.string)
            try text.write(to: url, atomically: true, encoding: .utf8)
            fileURL = url
            originalText = textView.string
            shouldRestoreInSession = true
            updateTitle()
            updateStatusBar()
            notifyStateChanged()
        } catch {
            showError("Could not save the file.", detail: error.localizedDescription)
        }
    }

    private func applyWordWrap() {
        guard let textContainer = textView.textContainer else { return }
        if wordWrapEnabled {
            scrollView.hasHorizontalScroller = false
            textContainer.widthTracksTextView = true
            textContainer.containerSize = NSSize(width: scrollView.contentSize.width, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = false
            textView.autoresizingMask = [.width]
        } else {
            scrollView.hasHorizontalScroller = true
            textContainer.widthTracksTextView = false
            textContainer.containerSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
            textView.isHorizontallyResizable = true
            textView.autoresizingMask = [.width, .height]
            textView.frame.size.width = max(scrollView.contentSize.width, 4000)
        }
    }

    private func applyZoom() {
        let size = max(6, baseFont.pointSize * CGFloat(zoomPercent) / 100)
        textView.font = NSFontManager.shared.convert(baseFont, toSize: size)
        updateStatusBar()
    }

    private func makeFindPanel(showReplace: Bool) {
        if findPanelController == nil {
            findPanelController = FindPanelController(
                onFindNext: { [weak self] term in self?.find(term: term, backwards: false) },
                onFindPrevious: { [weak self] term in self?.find(term: term, backwards: true) },
                onReplace: { [weak self] term, replacement in self?.replace(term: term, replacement: replacement) },
                onReplaceAll: { [weak self] term, replacement in self?.replaceAll(term: term, replacement: replacement) }
            )
        }
        findPanelController?.show(initialTerm: selectedOrLastFindTerm, showReplace: showReplace)
    }

    private var selectedOrLastFindTerm: String {
        let range = textView.selectedRange()
        if range.length > 0 {
            return (textView.string as NSString).substring(with: range)
        }
        return lastFindTerm
    }

    @discardableResult
    private func find(term: String, backwards: Bool) -> Bool {
        let effectiveTerm = term.isEmpty ? selectedOrLastFindTerm : term
        guard !effectiveTerm.isEmpty else {
            NSSound.beep()
            return false
        }

        lastFindTerm = effectiveTerm
        let nsText = textView.string as NSString
        let currentRange = textView.selectedRange()
        let searchRange: NSRange
        let options: NSString.CompareOptions = backwards ? [.backwards, .caseInsensitive] : [.caseInsensitive]

        if backwards {
            searchRange = NSRange(location: 0, length: currentRange.location)
        } else {
            let start = min(currentRange.location + currentRange.length, nsText.length)
            searchRange = NSRange(location: start, length: nsText.length - start)
        }

        var foundRange = nsText.range(of: effectiveTerm, options: options, range: searchRange)
        if foundRange.location == NSNotFound {
            foundRange = nsText.range(
                of: effectiveTerm,
                options: options,
                range: NSRange(location: 0, length: nsText.length)
            )
        }

        guard foundRange.location != NSNotFound else {
            NSSound.beep()
            return false
        }

        textView.setSelectedRange(foundRange)
        textView.scrollRangeToVisible(foundRange)
        updateStatusBar()
        return true
    }

    private func replace(term: String, replacement: String) {
        let selectedRange = textView.selectedRange()
        let selectedText = selectedRange.length > 0 ? (textView.string as NSString).substring(with: selectedRange) : ""
        if selectedText.caseInsensitiveCompare(term) == .orderedSame {
            textView.insertText(replacement, replacementRange: selectedRange)
        }
        _ = find(term: term, backwards: false)
    }

    private func replaceAll(term: String, replacement: String) {
        guard !term.isEmpty else { return }
        let replaced = textView.string.replacingOccurrences(
            of: term,
            with: replacement,
            options: [.caseInsensitive, .literal],
            range: nil
        )
        textView.string = replaced
        shouldRestoreInSession = true
        updateTitle()
        updateStatusBar()
        notifyStateChanged()
    }

    private func selectLine(_ lineNumber: Int) {
        let nsText = textView.string as NSString
        var currentLine = 1
        var location = 0

        while currentLine < lineNumber && location < nsText.length {
            let range = nsText.range(of: "\n", options: [], range: NSRange(location: location, length: nsText.length - location))
            if range.location == NSNotFound {
                NSSound.beep()
                return
            }
            location = range.location + range.length
            currentLine += 1
        }

        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        updateStatusBar()
        notifyStateChanged()
    }

    private var hasUnsavedChanges: Bool {
        textView.string != originalText
    }

    private func updateTitle() {
        let name = fileURL?.lastPathComponent ?? "Untitled"
        window?.title = "\(name) - MacPad"
        window?.representedURL = fileURL
        window?.isDocumentEdited = hasUnsavedChanges
    }

    private func updateStatusBar() {
        guard statusBarVisible else { return }
        let position = TextMetrics.cursorPosition(in: textView.string, selectedLocation: textView.selectedRange().location)
        let wrap = wordWrapEnabled ? "Word Wrap" : "No Wrap"
        statusBar.stringValue = "Ln \(position.line), Col \(position.column)  |  \(zoomPercent)%  |  \(wrap)  |  UTF-8"
    }

    private func showError(_ message: String, detail: String) {
        let alert = NSAlert()
        alert.alertStyle = .critical
        alert.messageText = message
        alert.informativeText = detail
        alert.runModal()
    }

    private func notifyStateChanged() {
        onStateChange?()
    }
}
