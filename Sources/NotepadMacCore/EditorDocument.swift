import Foundation

public final class EditorDocument {
    public private(set) var id: String
    public private(set) var fileURL: URL?
    public private(set) var text: String
    public private(set) var originalText: String
    public private(set) var lineEnding: LineEnding
    public private(set) var shouldRestoreInSession: Bool

    public init(
        id: String = UUID().uuidString,
        fileURL: URL? = nil,
        text: String = "",
        originalText: String = "",
        lineEnding: LineEnding = .windows,
        shouldRestoreInSession: Bool = true
    ) {
        self.id = id
        self.fileURL = fileURL
        self.text = text
        self.originalText = originalText
        self.lineEnding = lineEnding
        self.shouldRestoreInSession = shouldRestoreInSession
    }

    public var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    public var hasUnsavedChanges: Bool {
        text != originalText
    }

    public func loadFile(_ url: URL) throws {
        let data = try Data(contentsOf: url)
        let loadedText = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
            ?? ""
        let normalizedText = TextMetrics.normalizedLineEndingsForEditing(loadedText)

        id = UUID().uuidString
        fileURL = url
        text = normalizedText
        originalText = normalizedText
        lineEnding = LineEnding.detected(in: loadedText)
        shouldRestoreInSession = true
    }

    public func updateText(_ text: String) {
        self.text = text
        shouldRestoreInSession = true
    }

    public func save(to url: URL) throws {
        let outputText = TextMetrics.textForSave(text, lineEnding: lineEnding)
        try outputText.write(to: url, atomically: true, encoding: .utf8)
        fileURL = url
        originalText = text
        shouldRestoreInSession = true
    }

    public func restoreSessionState(_ state: EditorSessionState) {
        id = state.id
        fileURL = state.filePath.map(URL.init(fileURLWithPath:))
        text = state.text
        originalText = state.originalText
        lineEnding = state.lineEnding
        shouldRestoreInSession = true
    }

    public func sessionState(
        selectedLocation: Int,
        wordWrapEnabled: Bool,
        statusBarVisible: Bool,
        zoomPercent: Int
    ) -> EditorSessionState? {
        guard shouldRestoreInSession else { return nil }
        return EditorSessionState(
            id: id,
            filePath: fileURL?.path,
            text: text,
            originalText: originalText,
            selectedLocation: selectedLocation,
            wordWrapEnabled: wordWrapEnabled,
            statusBarVisible: statusBarVisible,
            zoomPercent: zoomPercent,
            lineEnding: lineEnding
        )
    }

    public func discardFromSessionRestore() {
        shouldRestoreInSession = false
    }

    public func keepInSessionRestore() {
        shouldRestoreInSession = true
    }
}
