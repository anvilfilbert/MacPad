import AppKit
import NotepadMacCore

@MainActor
final class SaveEncodingAccessory {
    let view: NSView
    let picker: NSPopUpButton
    private let encodingOptions = TextFileEncoding.allCases

    init(
        selectedEncoding: TextFileEncoding,
        localization: MacPadLocalization
    ) {
        let picker = NSPopUpButton(frame: .zero, pullsDown: false)
        picker.addItems(
            withTitles: encodingOptions.map { $0.statusLabel(using: localization) }
        )
        picker.selectItem(at: encodingOptions.firstIndex(of: selectedEncoding) ?? 0)
        picker.identifier = NSUserInterfaceItemIdentifier("save.encoding")
        picker.setAccessibilityLabel(localization.string(.textEncoding))
        self.picker = picker

        let encodingLabel = NSTextField(labelWithString: localization.string(.encodingLabel))
        encodingLabel.identifier = NSUserInterfaceItemIdentifier("save.encodingLabel")
        encodingLabel.setContentCompressionResistancePriority(.required, for: .horizontal)
        picker.setContentCompressionResistancePriority(.required, for: .horizontal)
        let stack = NSStackView(views: [encodingLabel, picker])
        stack.orientation = .horizontal
        stack.spacing = 12
        stack.edgeInsets = NSEdgeInsets(top: 8, left: 40, bottom: 8, right: 24)
        view = stack
    }

    var selectedEncoding: TextFileEncoding? {
        let selectedIndex = picker.indexOfSelectedItem
        guard encodingOptions.indices.contains(selectedIndex) else { return nil }
        return encodingOptions[selectedIndex]
    }
}
