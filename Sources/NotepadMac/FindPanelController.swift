import AppKit
import NotepadMacCore

final class FindPanelController: NSWindowController {
    private let localization: MacPadLocalization
    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let replaceLabel: NSTextField
    private let findNextButton: NSButton
    private let findPreviousButton: NSButton
    private let replaceButton: NSButton
    private let replaceAllButton: NSButton
    private let matchCaseButton: NSButton
    private let wrapAroundButton: NSButton
    private var replaceRows: [NSGridRow] = []
    private let onFindNext: (String, FindOptions) -> Void
    private let onFindPrevious: (String, FindOptions) -> Void
    private let onReplace: (String, String, FindOptions) -> Void
    private let onReplaceAll: (String, String, FindOptions) -> Void

    init(
        localization: MacPadLocalization,
        onFindNext: @escaping (String, FindOptions) -> Void,
        onFindPrevious: @escaping (String, FindOptions) -> Void,
        onReplace: @escaping (String, String, FindOptions) -> Void,
        onReplaceAll: @escaping (String, String, FindOptions) -> Void
    ) {
        self.localization = localization
        replaceLabel = NSTextField(labelWithString: localization.string(.replaceWith))
        findNextButton = NSButton(
            title: localization.string(.findNext),
            target: nil,
            action: nil
        )
        findPreviousButton = NSButton(
            title: localization.string(.findPrevious),
            target: nil,
            action: nil
        )
        replaceButton = NSButton(
            title: localization.string(.replaceTitle),
            target: nil,
            action: nil
        )
        replaceAllButton = NSButton(
            title: localization.string(.replaceAll),
            target: nil,
            action: nil
        )
        matchCaseButton = NSButton(
            checkboxWithTitle: localization.string(.matchCase),
            target: nil,
            action: nil
        )
        wrapAroundButton = NSButton(
            checkboxWithTitle: localization.string(.wrapAround),
            target: nil,
            action: nil
        )
        self.onFindNext = onFindNext
        self.onFindPrevious = onFindPrevious
        self.onReplace = onReplace
        self.onReplaceAll = onReplaceAll

        let window = NSPanel(
            contentRect: .zero,
            styleMask: [.titled, .closable, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        window.hidesOnDeactivate = false
        window.title = localization.string(.findTitle)
        window.contentMinSize = NSSize(width: 500, height: 204)
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
        window?.contentView?.layoutSubtreeIfNeeded()
        window?.title = localization.string(showReplace ? .replaceTitle : .findTitle)
        window?.center()
        showWindow(nil)
        window?.makeKeyAndOrderFront(nil)
        window?.makeFirstResponder(findField)
    }

    private func setupUI() {
        guard let window, let contentView = window.contentView else {
            preconditionFailure("Find panel requires a content view.")
        }

        let findLabel = NSTextField(labelWithString: localization.string(.findWhat))
        findLabel.identifier = NSUserInterfaceItemIdentifier("find.termLabel")
        replaceLabel.identifier = NSUserInterfaceItemIdentifier("find.replacementLabel")
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
        findField.setAccessibilityLabel(localization.string(.findWhatAccessibilityLabel))
        replaceField.setAccessibilityLabel(
            localization.string(.replaceWithAccessibilityLabel)
        )
        findNextButton.setAccessibilityLabel(localization.string(.findNext))
        findPreviousButton.setAccessibilityLabel(localization.string(.findPrevious))
        replaceButton.setAccessibilityLabel(localization.string(.replaceTitle))
        replaceAllButton.setAccessibilityLabel(localization.string(.replaceAll))
        matchCaseButton.setAccessibilityLabel(localization.string(.matchCase))
        wrapAroundButton.setAccessibilityLabel(localization.string(.wrapAround))
        wrapAroundButton.state = .on

        for button in [
            findNextButton,
            findPreviousButton,
            replaceButton,
            replaceAllButton,
            matchCaseButton,
            wrapAroundButton
        ] {
            button.setContentCompressionResistancePriority(.required, for: .horizontal)
        }

        let options = NSStackView(views: [matchCaseButton, wrapAroundButton])
        options.orientation = .horizontal
        options.spacing = 16
        options.setContentCompressionResistancePriority(.required, for: .horizontal)

        let grid = NSGridView(views: [
            [findLabel, findField, findNextButton],
            [NSGridCell.emptyContentView, NSGridCell.emptyContentView, findPreviousButton],
            [NSGridCell.emptyContentView, options, NSGridCell.emptyContentView],
            [replaceLabel, replaceField, replaceButton],
            [NSGridCell.emptyContentView, NSGridCell.emptyContentView, replaceAllButton]
        ])
        grid.identifier = NSUserInterfaceItemIdentifier("find.grid")
        grid.rowSpacing = 10
        grid.columnSpacing = 10
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 1).width = 220
        grid.column(at: 1).xPlacement = .fill
        grid.column(at: 2).xPlacement = .fill
        for rowIndex in 0..<grid.numberOfRows {
            grid.row(at: rowIndex).yPlacement = .center
        }
        grid.mergeCells(
            inHorizontalRange: NSRange(location: 1, length: 2),
            verticalRange: NSRange(location: 2, length: 1)
        )
        replaceRows = [grid.row(at: 3), grid.row(at: 4)]
        contentView.addSubview(grid)

        setReplaceVisible(true)
        let fittingSize = grid.fittingSize
        window.setContentSize(
            NSSize(
                width: max(window.contentMinSize.width, fittingSize.width + 32),
                height: max(window.contentMinSize.height, fittingSize.height + 32)
            )
        )
        grid.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            grid.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 16),
            grid.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -16),
            grid.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 16),
            grid.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -16)
        ])
        contentView.layoutSubtreeIfNeeded()

        window.defaultButtonCell = findNextButton.cell as? NSButtonCell
        window.initialFirstResponder = findField
        setReplaceVisible(false)
    }

    private func setReplaceVisible(_ visible: Bool) {
        for row in replaceRows {
            row.isHidden = !visible
        }
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
