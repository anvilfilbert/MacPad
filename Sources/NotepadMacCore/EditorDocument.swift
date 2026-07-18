import Foundation

public enum EditorDocumentError: LocalizedError {
    case fileTooLarge(path: String, sizeBytes: Int64, maximumBytes: Int64)
    case unsupportedTextEncoding(path: String)

    public var errorDescription: String? {
        switch self {
        case let .fileTooLarge(path, sizeBytes, maximumBytes):
            return "File is too large to open safely: \(path) is \(sizeBytes) bytes, maximum is \(maximumBytes) bytes."
        case let .unsupportedTextEncoding(path):
            return "File is not readable as supported plain text: \(path)."
        }
    }
}

public final class EditorDocument {
    public static let maximumReadableFileBytes: Int64 = 25 * 1024 * 1024

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
        try validateReadableFile(url)
        let data = try Data(contentsOf: url)
        if data.contains(0) {
            throw EditorDocumentError.unsupportedTextEncoding(path: url.path)
        }
        let loadedText = String(data: data, encoding: .utf8)
            ?? String(data: data, encoding: .isoLatin1)
        guard let loadedText else {
            throw EditorDocumentError.unsupportedTextEncoding(path: url.path)
        }
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
        text = ""
        originalText = ""
        lineEnding = state.lineEnding
        shouldRestoreInSession = true
    }

    public func restoreSessionStateAndReloadFile(_ state: EditorSessionState) throws {
        guard let filePath = state.filePath else {
            restoreSessionState(state)
            return
        }

        try loadFile(URL(fileURLWithPath: filePath))
        id = state.id
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

    private func validateReadableFile(_ url: URL) throws {
        let values = try url.resourceValues(forKeys: [.fileSizeKey])
        guard let fileSize = values.fileSize else { return }
        let sizeBytes = Int64(fileSize)
        if sizeBytes > Self.maximumReadableFileBytes {
            throw EditorDocumentError.fileTooLarge(
                path: url.path,
                sizeBytes: sizeBytes,
                maximumBytes: Self.maximumReadableFileBytes
            )
        }
    }
}
