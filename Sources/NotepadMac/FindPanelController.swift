import AppKit

final class FindPanelController: NSWindowController {
    private let findField = NSTextField()
    private let replaceField = NSTextField()
    private let replaceLabel = NSTextField(labelWithString: "Replace with:")
    private let replaceButton = NSButton(title: "Replace", target: nil, action: nil)
    private let replaceAllButton = NSButton(title: "Replace All", target: nil, action: nil)
    private let onFindNext: (String) -> Void
    private let onFindPrevious: (String) -> Void
    private let onReplace: (String, String) -> Void
    private let onReplaceAll: (String, String) -> Void

    init(
        onFindNext: @escaping (String) -> Void,
        onFindPrevious: @escaping (String) -> Void,
        onReplace: @escaping (String, String) -> Void,
        onReplaceAll: @escaping (String, String) -> Void
    ) {
        self.onFindNext = onFindNext
        self.onFindPrevious = onFindPrevious
        self.onReplace = onReplace
        self.onReplaceAll = onReplaceAll

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 430, height: 164),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Find"
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
        let nextButton = NSButton(title: "Find Next", target: self, action: #selector(findNext))
        let previousButton = NSButton(title: "Find Previous", target: self, action: #selector(findPrevious))
        replaceButton.target = self
        replaceButton.action = #selector(replace)
        replaceAllButton.target = self
        replaceAllButton.action = #selector(replaceAll)

        let grid = NSGridView(views: [
            [findLabel, findField, nextButton],
            [NSGridCell.emptyContentView, NSGridCell.emptyContentView, previousButton],
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

        setReplaceVisible(false)
    }

    private func setReplaceVisible(_ visible: Bool) {
        replaceLabel.isHidden = !visible
        replaceField.isHidden = !visible
        replaceButton.isHidden = !visible
        replaceAllButton.isHidden = !visible
    }

    @objc private func findNext() {
        onFindNext(findField.stringValue)
    }

    @objc private func findPrevious() {
        onFindPrevious(findField.stringValue)
    }

    @objc private func replace() {
        onReplace(findField.stringValue, replaceField.stringValue)
    }

    @objc private func replaceAll() {
        onReplaceAll(findField.stringValue, replaceField.stringValue)
    }
}
