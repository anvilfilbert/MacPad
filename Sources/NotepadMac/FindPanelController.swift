import AppKit
import NotepadMacCore

final class FindPanelController: NSWindowController {
    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let replaceLabel = NSTextField(labelWithString: "Replace with:")
    private let findNextButton = NSButton(title: "Find Next", target: nil, action: nil)
    private let findPreviousButton = NSButton(title: "Find Previous", target: nil, action: nil)
    private let replaceButton = NSButton(title: "Replace", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "Replace All", target: nil, action: nil)
    private let matchCaseButton = NSButton(checkboxWithTitle: "Match case", target: nil, action: nil)
    private let wrapAroundButton = NSButton(checkboxWithTitle: "Wrap around", target: nil, action: nil)
    private let onFindNext: (String, FindOptions) -> Void
    private let onFindPrevious: (String, FindOptions) -> Void
    private let onReplace: (String, String, FindOptions) -> Void
    private let onReplaceAll: (String, String, FindOptions) -> Void

    init(
        onFindNext: @escaping (String, FindOptions) -> Void,
        onFindPrevious: @escaping (String, FindOptions) -> Void,
        onReplace: @escaping (String, String, FindOptions) -> Void,
        onReplaceAll: @escaping (String, String, FindOptions) -> Void
    ) {
        self.onFindNext = onFindNext
        self.onFindPrevious = onFindPrevious
        self.onReplace = onReplace
        self.onReplaceAll = onReplaceAll

        let window = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 204),
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.hidesOnDeactivate = false
        window.title = "Find"
        window.autorecalculatesKeyViewLoop = false
        super.init(window: window)
        setupUI()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show(initialTerm: String, showReplace: Bool) {
        findField.stringValue = initialTerm
        setReplaceVisible(showReplace)
        window?.title = showReplace ? "Replace" : "Find"
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(findField)
    }

    private func setupUI() {
        guard let contentView = window?.contentView else { return }

        let findLabel = NSTextField(labelWithString: "Find what:")
        findPreviousButton.target = self
        findPreviousButton.action = #selector(findPrevious)
        findNextButton.target = self
        findNextButton.action = #selector(findNext)
        replaceButton.target = self
        replaceButton.action = #selector(replace)
        replaceAllButton.target = self
        replaceAllButton.action = #selector(replaceAll)
        findField.identifier = NSUserInterfaceItemIdentifier("find.term")
        replaceField.identifier = NSUserInterfaceItemIdentifier("find.replacement")
        findNextButton.identifier = NSUserInterfaceItemIdentifier("find.next")
        findPreviousButton.identifier = NSUserInterfaceItemIdentifier("find.previous")
        replaceButton.identifier = NSUserInterfaceItemIdentifier("find.replace")
        replaceAllButton.identifier = NSUserInterfaceItemIdentifier("find.replaceAll")
        matchCaseButton.identifier = NSUserInterfaceItemIdentifier("find.matchCase")
        wrapAroundButton.identifier = NSUserInterfaceItemIdentifier("find.wrapAround")
        findField.setAccessibilityLabel("Find what")
        replaceField.setAccessibilityLabel("Replace with")
        findNextButton.setAccessibilityLabel("Find next")
        findPreviousButton.setAccessibilityLabel("Find previous")
        replaceButton.setAccessibilityLabel("Replace")
        replaceAllButton.setAccessibilityLabel("Replace all")
        matchCaseButton.setAccessibilityLabel("Match case")
        wrapAroundButton.setAccessibilityLabel("Wrap around")
        wrapAroundButton.state = .on

        let options = NSStackView(views: [matchCaseButton, wrapAroundButton])
        options.orientation = .horizontal
        options.spacing = 16

        let grid = NSGridView(views: [
            [findLabel, findField, findNextButton],
            [NSGridCell.emptyContentView, NSGridCell.emptyContentView, findPreviousButton],
            [NSGridCell.emptyContentView, options, NSGridCell.emptyContentView],
            [replaceLabel, replaceField, replaceButton],
            [NSGridCell.emptyContentView, NSGridCell.emptyContentView, replaceAllButton]
        ])
        grid.translatesAutoresizingMaskIntoConstraints = false
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        grid.column(at: 1).width = 220
        contentView.addSubview(grid)

        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -16),
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16)
        ])

        window?.defaultButtonCell = findNextButton.cell as? NSButtonCell
        window?.initialFirstResponder = findField
        setReplaceVisible(false)
    }

    private func setReplaceVisible(_ visible: Bool) {
        replaceLabel.isHidden = !visible
        replaceField.isHidden = !visible
        replaceButton.isHidden = !visible
        replaceAllButton.isHidden = !visible
        configureKeyViewLoop(showReplace: visible)
    }

    private func configureKeyViewLoop(showReplace: Bool) {
        let views: [NSView] = showReplace
            ? [
                findField,
                replaceField,
                matchCaseButton,
                wrapAroundButton,
                findNextButton,
                findPreviousButton,
                replaceButton,
                replaceAllButton
            ]
            : [
                findField,
                matchCaseButton,
                wrapAroundButton,
                findNextButton,
                findPreviousButton
            ]

        for (view, nextView) in zip(views, views.dropFirst() + [views[0]]) {
            view.nextKeyView = nextView
        }
    }

    @objc private func findNext() {
        onFindNext(findField.stringValue, findOptions)
    }

    @objc private func findPrevious() {
        onFindPrevious(findField.stringValue, findOptions)
    }

    @objc private func replace() {
        onReplace(findField.stringValue, replaceField.stringValue, findOptions)
    }

    @objc private func replaceAll() {
        onReplaceAll(findField.stringValue, replaceField.stringValue, findOptions)
    }

    private var findOptions: FindOptions {
        FindOptions(
            matchCase: matchCaseButton.state == .on,
            wrapAround: wrapAroundButton.state == .on
        )
    }
}
