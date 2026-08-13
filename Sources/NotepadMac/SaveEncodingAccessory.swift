import AppKit
import NotepadMacCore

@MainActor
final class SaveEncodingAccessory {
    let view: NSView
    let picker: NSPopUpButton
    private let encodingOptions = TextFileEncoding.allCases

    init(selectedEncoding: TextFileEncoding) {
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        picker.addItems(withTitles: encodingOptions.map(\.statusLabel))
        picker.selectItem(at: encodingOptions.firstIndex(of: selectedEncoding) ?? 0)
        picker.identifier = NSUserInterfaceItemIdentifier("save.encoding")
        picker.setAccessibilityLabel("Text encoding")
        self.picker = picker

        let encodingLabel = NSTextField(labelWithString: "Encoding:")
        let stack = NSStackView(views: [encodingLabel, picker])
        stack.orientation = .horizontal
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 0, bottom: 8, right: 0)
        view = stack
    }

    var selectedEncoding: TextFileEncoding? {
        let selectedIndex = picker.indexOfSelectedItem
        guard encodingOptions.indices.contains(selectedIndex) else { return nil }
        return encodingOptions[selectedIndex]
    }
}
