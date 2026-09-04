import AppKit
import NotepadMacCore
import UniformTypeIdentifiers

private struct EditorTextAnalysis: Sendable {
    let lineIndex: TextLineIndex
    let matchesOriginal: Bool
}

private actor EditorTextAnalyzer {
    func analyze(text: String, originalText: String) -> EditorTextAnalysis? {
        guard !Task.isCancelled else { return nil }
        let lineIndex = TextLineIndex(text: text)
        guard !Task.isCancelled else { return nil }
        return EditorTextAnalysis(
            lineIndex: lineIndex,
            matchesOriginal: text == originalText
        )
    }
}

final class EditorWindowController: NSWindowController, NSWindowDelegate, NSTextViewDelegate {
    static var defaultEditorFont: NSFont {
        NSFont.monospacedSystemFont(ofSize: 14, weight: .regular)
    }

    var onClose: (() -> Void)?
    var onStateChange: (() -> Void)?
    var onActivate: (() -> Void)?
    var onFontChange: ((NSFont) -> Void)?
    var onSuccessfulSave: ((URL) -> Void)?
    var onOpenDroppedFiles: (([URL]) -> Void)?

    private let scrollView = NSScrollView()
    private let textView = EditorTextView()
    private let statusBar = NSTextField(labelWithString: "")
    private let editorDocument = EditorDocument()
    private var lastFindTerm = ""
    private var lastFindOptions = FindOptions(matchCase: false, wrapAround: true)
    private var findPanelController: FindPanelController?
    private var wordWrapEnabled = true
    private var statusBarVisible = true
    private var zoomPercent = 100
    private var baseFont: NSFont
    private var lineIndex = TextLineIndex(text: "")
    private var lineIndexGeneration = 0
    private var appliedLineIndexGeneration = 0
    private let textAnalyzer = EditorTextAnalyzer()
    private var pendingTextAnalysisTask: Task<Void, Never>?

    convenience init() {
        self.init(baseFont: Self.defaultEditorFont)
    }

    init(baseFont: NSFont) {
        self.baseFont = baseFont
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

    var fileURL: URL? {
        editorDocument.fileURL
    }

    func loadFile(_ url: URL) throws {
        try editorDocument.loadFile(url)
        textView.string = editorDocument.text
        refreshLineIndexNow()
        updateTitle()
        updateStatusBar()
        notifyStateChanged()
    }

    var sessionState: EditorSessionState? {
        return editorDocument.sessionState(
            selectedLocation: textView.selectedRange().location,
            wordWrapEnabled: wordWrapEnabled,
            statusBarVisible: statusBarVisible,
            zoomPercent: zoomPercent
        )
    }

    func restoreSessionState(_ state: EditorSessionState) throws {
        try editorDocument.restoreSessionStateAndReloadFile(state)
        textView.string = editorDocument.text
        refreshLineIndexNow()
        wordWrapEnabled = state.wordWrapEnabled
        statusBarVisible = state.statusBarVisible
        statusBar.isHidden = !state.statusBarVisible
        zoomPercent = state.zoomPercent
        applyWordWrap()
        applyZoom()

        let location = min(max(0, state.selectedLocation), (textView.string as NSString).length)
        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        updateTitle()
        updateStatusBar()
    }

    @objc func save(_ sender: Any?) {
        if let fileURL = editorDocument.fileURL {
            write(to: fileURL)
        } else {
            saveAs(sender)
        }
    }

    @objc func saveAs(_ sender: Any?) {
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = editorDocument.fileURL?.lastPathComponent ?? "Untitled.txt"
        let encodingAccessory = SaveEncodingAccessory(selectedEncoding: editorDocument.textEncoding)
        panel.accessoryView = encodingAccessory.view

        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard let selectedEncoding = encodingAccessory.selectedEncoding else {
            showError("Could not save the file.", detail: "No valid text encoding was selected.")
            return
        }
        write(to: url, encoding: selectedEncoding)
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
        find(term: lastFindTerm, backwards: false, options: lastFindOptions)
    }

    @objc func findPrevious(_ sender: Any?) {
        find(term: lastFindTerm, backwards: true, options: lastFindOptions)
    }

    @objc func goToLine(_ sender: Any?) {
        refreshLineIndexNow()
        let alert = NSAlert()
        alert.messageText = "Go To Line"
        alert.informativeText = "Line number:"
        let input = NSTextField(frame: NSRect(x: 0, y: 0, width: 220, height: 24))
        input.stringValue = "\(lineIndex.cursorPosition(selectedLocation: textView.selectedRange().location).line)"
        input.identifier = NSUserInterfaceItemIdentifier("goTo.lineNumber")
        input.setAccessibilityLabel("Line number")
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
        let convertedFont = sender.convert(baseFont)
        do {
            _ = try EditorFontPreference(
                postScriptName: convertedFont.fontName,
                pointSize: Double(convertedFont.pointSize)
            )
            applyPreferredFont(convertedFont)
            onFontChange?(convertedFont)
        } catch {
            showError("Could not use the selected font.", detail: error.localizedDescription)
        }
    }

    func applyPreferredFont(_ font: NSFont) {
        baseFont = font
        applyZoom()
    }

    func confirmDiscardIfNeeded() -> Bool {
        editorDocument.updateText(textView.string)
        guard editorDocument.hasUnsavedChanges else { return true }

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
            return !editorDocument.hasUnsavedChanges
        case .alertSecondButtonReturn:
            editorDocument.discardFromSessionRestore()
            notifyStateChanged()
            return true
        default:
            return false
        }
    }

    func keepInSessionRestore() {
        editorDocument.keepInSessionRestore()
        notifyStateChanged()
    }

    func discardFromSessionRestore() {
        editorDocument.discardFromSessionRestore()
        notifyStateChanged()
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        confirmDiscardIfNeeded()
    }

    func windowWillClose(_ notification: Notification) {
        onClose?()
    }

    func windowDidBecomeMain(_ notification: Notification) {
        onActivate?()
    }

    func textDidChange(_ notification: Notification) {
        let text = textView.string
        let originalText = editorDocument.originalText
        editorDocument.recordEditedText(text)
        scheduleTextAnalysis(for: text, originalText: originalText)
        updateTitle()
        updateStatusBar()
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
        textView.identifier = NSUserInterfaceItemIdentifier("editor.text")
        textView.setAccessibilityLabel("Document text")
        textView.onOpenDroppedFiles = { [weak self] urls in
            self?.onOpenDroppedFiles?(urls)
        }

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
        statusBar.identifier = NSUserInterfaceItemIdentifier("editor.status")
        statusBar.setAccessibilityLabel("Document status")
        stack.addArrangedSubview(statusBar)

        applyWordWrap()
        window?.initialFirstResponder = textView
        textView.nextKeyView = textView
        window?.makeFirstResponder(textView)
    }

    private func write(to url: URL) {
        write(to: url, encoding: editorDocument.textEncoding)
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
                onFindNext: { [weak self] term, options in
                    self?.find(term: term, backwards: false, options: options)
                },
                onFindPrevious: { [weak self] term, options in
                    self?.find(term: term, backwards: true, options: options)
                },
                onReplace: { [weak self] term, replacement, options in
                    self?.replace(term: term, replacement: replacement, options: options)
                },
                onReplaceAll: { [weak self] term, replacement, options in
                    self?.replaceAll(term: term, replacement: replacement, options: options)
                }
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
    private func find(term: String, backwards: Bool, options: FindOptions) -> Bool {
        let effectiveTerm = term.isEmpty ? selectedOrLastFindTerm : term
        guard !effectiveTerm.isEmpty else {
            NSSound.beep()
            return false
        }

        lastFindTerm = effectiveTerm
        lastFindOptions = options
        let currentRange = textView.selectedRange()
        guard let foundRange = TextEditingOperations.findRange(
            in: textView.string,
            searchTerm: effectiveTerm,
            selectedRange: currentRange,
            backwards: backwards,
            options: options
        ) else {
            NSSound.beep()
            return false
        }

        textView.setSelectedRange(foundRange)
        textView.scrollRangeToVisible(foundRange)
        updateStatusBar()
        return true
    }

    private func replace(term: String, replacement: String, options: FindOptions) {
        let selectedRange = textView.selectedRange()
        let selectedText = selectedRange.length > 0 ? (textView.string as NSString).substring(with: selectedRange) : ""
        guard !term.isEmpty else {
            NSSound.beep()
            return
        }
        if TextEditingOperations.selectionMatches(
            selectedText: selectedText,
            searchTerm: term,
            matchCase: options.matchCase
        ) {
            textView.insertText(replacement, replacementRange: selectedRange)
        }
        _ = find(term: term, backwards: false, options: options)
    }

    private func replaceAll(term: String, replacement: String, options: FindOptions) {
        guard !term.isEmpty else { return }
        let replaced = TextEditingOperations.replacingAll(
            in: textView.string,
            searchTerm: term,
            replacement: replacement,
            matchCase: options.matchCase
        )
        let fullRange = NSRange(location: 0, length: (textView.string as NSString).length)
        guard replaced != textView.string,
              let textStorage = textView.textStorage,
              textView.shouldChangeText(in: fullRange, replacementString: replaced) else {
            return
        }

        textStorage.replaceCharacters(in: fullRange, with: replaced)
        textView.didChangeText()
    }

    private func selectLine(_ lineNumber: Int) {
        guard let location = lineIndex.location(ofLine: lineNumber) else {
            NSSound.beep()
            return
        }

        textView.setSelectedRange(NSRange(location: location, length: 0))
        textView.scrollRangeToVisible(NSRange(location: location, length: 0))
        updateStatusBar()
        notifyStateChanged()
    }

    private func updateTitle() {
        window?.title = "\(editorDocument.displayName) - MacPad"
        window?.representedURL = editorDocument.fileURL
        window?.isDocumentEdited = editorDocument.hasUnsavedChanges
    }

    private func updateStatusBar() {
        guard statusBarVisible,
              appliedLineIndexGeneration == lineIndexGeneration else { return }
        let position = lineIndex.cursorPosition(selectedLocation: textView.selectedRange().location)
        statusBar.stringValue = "Ln \(position.line), Col \(position.column)  |  \(zoomPercent)%  |  \(editorDocument.lineEnding.statusLabel)  |  \(editorDocument.textEncoding.statusLabel)"
    }

    private func scheduleTextAnalysis(for text: String, originalText: String) {
        lineIndexGeneration += 1
        let generation = lineIndexGeneration
        pendingTextAnalysisTask?.cancel()
        let analyzer = textAnalyzer

        pendingTextAnalysisTask = Task { @MainActor [weak self, analyzer] in
            do {
                try await Task.sleep(for: .milliseconds(100))
            } catch is CancellationError {
                return
            } catch {
                preconditionFailure("Text-analysis debounce failed: \(error)")
            }

            guard let analysis = await analyzer.analyze(
                text: text,
                originalText: originalText
            ),
            !Task.isCancelled,
            let self,
            self.lineIndexGeneration == generation else { return }

            self.lineIndex = analysis.lineIndex
            self.appliedLineIndexGeneration = generation
            self.pendingTextAnalysisTask = nil
            if analysis.matchesOriginal {
                self.editorDocument.markCurrentTextAsMatchingOriginal()
                self.updateTitle()
            }
            self.updateStatusBar()
        }
    }

    private func refreshLineIndexNow() {
        pendingTextAnalysisTask?.cancel()
        pendingTextAnalysisTask = nil
        lineIndexGeneration += 1
        lineIndex = TextLineIndex(text: textView.string)
        appliedLineIndexGeneration = lineIndexGeneration
    }

    func waitForPendingTextAnalysis() async {
        let task = pendingTextAnalysisTask
        await task?.value
    }

    private func resolveExternalFileChange(at url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "This file changed outside MacPad."
        alert.informativeText = "Save your MacPad edits to another file, reload the version on disk, or cancel to keep editing."
        alert.addButton(withTitle: "Save As...")
        alert.addButton(withTitle: "Reload from Disk")
        alert.addButton(withTitle: "Cancel")

        switch alert.runModal() {
        case .alertFirstButtonReturn:
            saveAs(nil)
        case .alertSecondButtonReturn:
            do {
                try loadFile(url)
            } catch {
                showError("Could not reload the file.", detail: error.localizedDescription)
            }
        default:
            break
        }
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

    var isWordWrapEnabled: Bool {
        wordWrapEnabled
    }

    var isStatusBarVisible: Bool {
        statusBarVisible
    }

    private func write(to url: URL, encoding: TextFileEncoding) {
        do {
            try saveDocument(to: url, encoding: encoding)
        } catch EditorDocumentError.fileChangedOnDisk {
            resolveExternalFileChange(at: url)
        } catch {
            showError("Could not save the file.", detail: error.localizedDescription)
        }
    }

    func saveDocument(to url: URL, encoding: TextFileEncoding) throws {
        editorDocument.updateText(textView.string)
        try editorDocument.save(to: url, encoding: encoding)
        updateTitle()
        updateStatusBar()
        notifyStateChanged()
        onSuccessfulSave?(editorDocument.fileURL ?? url.standardizedFileURL)
    }
}
