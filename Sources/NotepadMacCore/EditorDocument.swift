import CryptoKit
import Darwin
import Foundation

public enum EditorDocumentError: LocalizedError {
    case fileTooLarge(path: String, sizeBytes: Int64, maximumBytes: Int64)
    case fileIsNotRegular(path: String)
    case fileChangedOnDisk(path: String)
    case unsupportedTextEncoding(path: String)
    case textCannotBeSaved(path: String, encoding: String)

    public var errorDescription: String? {
        switch self {
        case let .fileTooLarge(path, sizeBytes, maximumBytes):
            return "File is too large to open safely: \(path) is \(sizeBytes) bytes, maximum is \(maximumBytes) bytes."
        case let .fileIsNotRegular(path):
            return "Only regular files can be opened safely: \(path)."
        case let .fileChangedOnDisk(path):
            return "The file changed on disk after MacPad opened it: \(path). Reload it or use Save As to avoid overwriting another edit."
        case let .unsupportedTextEncoding(path):
            return "File is not readable as supported plain text: \(path)."
        case let .textCannotBeSaved(path, encoding):
            return "The document contains text that cannot be represented as \(encoding): \(path)."
        }
    }
}

public enum TextFileEncoding: CaseIterable, Equatable, Sendable {
    case utf8
    case utf8WithByteOrderMark
    case utf16LittleEndian
    case utf16BigEndian
    case windows1252
    case isoLatin1

    public var statusLabel: String {
        switch self {
        case .utf8:
            return "UTF-8"
        case .utf8WithByteOrderMark:
            return "UTF-8 BOM"
        case .utf16LittleEndian:
            return "UTF-16 LE"
        case .utf16BigEndian:
            return "UTF-16 BE"
        case .windows1252:
            return "Windows-1252"
        case .isoLatin1:
            return "ISO-8859-1"
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
    public private(set) var textEncoding: TextFileEncoding
    public private(set) var shouldRestoreInSession: Bool
    public private(set) var hasUnsavedChanges: Bool
    private var originalFileDigest: Data?

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
        self.textEncoding = .utf8
        self.shouldRestoreInSession = shouldRestoreInSession
        self.hasUnsavedChanges = text != originalText
        self.originalFileDigest = nil
    }

    public var displayName: String {
        fileURL?.lastPathComponent ?? "Untitled"
    }

    public func loadFile(_ url: URL) throws {
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        let data = try Self.readBoundedRegularFile(resolvedURL)
        let decodedText = try Self.decodeText(data, path: resolvedURL.path)
        let loadedText = decodedText.text
        let normalizedText = TextMetrics.normalizedLineEndingsForEditing(loadedText)

        id = UUID().uuidString
        fileURL = resolvedURL
        text = normalizedText
        originalText = normalizedText
        lineEnding = LineEnding.detected(in: loadedText)
        textEncoding = decodedText.encoding
        shouldRestoreInSession = true
        hasUnsavedChanges = false
        originalFileDigest = Self.digest(data)
    }

    public func updateText(_ text: String) {
        self.text = text
        shouldRestoreInSession = true
        hasUnsavedChanges = text != originalText
    }

    public func save(to url: URL) throws {
        try save(to: url, encoding: textEncoding)
    }

    public func save(to url: URL, encoding: TextFileEncoding) throws {
        let resolvedURL = url.resolvingSymlinksInPath().standardizedFileURL
        let isCurrentFile = fileURL?.standardizedFileURL == resolvedURL
        let outputData = try encodedData(path: resolvedURL.path, encoding: encoding)

        if isCurrentFile {
            try verifyFileHasNotChanged(resolvedURL)
        }

        try outputData.write(to: resolvedURL, options: .atomic)
        let savedData = try Self.readBoundedRegularFile(resolvedURL)
        fileURL = resolvedURL
        originalText = text
        textEncoding = encoding
        shouldRestoreInSession = true
        hasUnsavedChanges = false
        originalFileDigest = Self.digest(savedData)
    }

    public func restoreSessionState(_ state: EditorSessionState) {
        id = state.id
        fileURL = state.filePath.map(URL.init(fileURLWithPath:))
        text = ""
        originalText = ""
        lineEnding = state.lineEnding
        textEncoding = .utf8
        shouldRestoreInSession = true
        hasUnsavedChanges = false
        originalFileDigest = nil
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

    private func encodedData(path: String, encoding: TextFileEncoding) throws -> Data {
        let outputText = TextMetrics.textForSave(text, lineEnding: lineEnding)
        switch encoding {
        case .utf8:
            return Data(outputText.utf8)
        case .utf8WithByteOrderMark:
            return Data([0xEF, 0xBB, 0xBF]) + Data(outputText.utf8)
        case .utf16LittleEndian:
            guard let data = outputText.data(using: .utf16LittleEndian, allowLossyConversion: false) else {
                throw EditorDocumentError.textCannotBeSaved(path: path, encoding: encoding.statusLabel)
            }
            return Data([0xFF, 0xFE]) + data
        case .utf16BigEndian:
            guard let data = outputText.data(using: .utf16BigEndian, allowLossyConversion: false) else {
                throw EditorDocumentError.textCannotBeSaved(path: path, encoding: encoding.statusLabel)
            }
            return Data([0xFE, 0xFF]) + data
        case .windows1252:
            guard let data = outputText.data(using: .windowsCP1252, allowLossyConversion: false) else {
                throw EditorDocumentError.textCannotBeSaved(path: path, encoding: encoding.statusLabel)
            }
            return data
        case .isoLatin1:
            guard let data = outputText.data(using: .isoLatin1, allowLossyConversion: false) else {
                throw EditorDocumentError.textCannotBeSaved(
                    path: path,
                    encoding: encoding.statusLabel
                )
            }
            return data
        }
    }

    private func verifyFileHasNotChanged(_ url: URL) throws {
        guard FileManager.default.fileExists(atPath: url.path),
              let originalFileDigest else {
            throw EditorDocumentError.fileChangedOnDisk(path: url.path)
        }
        let currentData = try Self.readBoundedRegularFile(url)
        guard Self.digest(currentData) == originalFileDigest else {
            throw EditorDocumentError.fileChangedOnDisk(path: url.path)
        }
    }

    private static func readBoundedRegularFile(_ url: URL) throws -> Data {
        let handle = try FileHandle(forReadingFrom: url)
        defer { handle.closeFile() }

        var fileStatus = stat()
        guard fstat(handle.fileDescriptor, &fileStatus) == 0 else {
            throw POSIXError(POSIXErrorCode(rawValue: errno) ?? .EIO)
        }
        guard (fileStatus.st_mode & S_IFMT) == S_IFREG else {
            throw EditorDocumentError.fileIsNotRegular(path: url.path)
        }

        let reportedSize = Int64(fileStatus.st_size)
        guard reportedSize <= maximumReadableFileBytes else {
            throw EditorDocumentError.fileTooLarge(
                path: url.path,
                sizeBytes: reportedSize,
                maximumBytes: maximumReadableFileBytes
            )
        }

        var data = Data()
        data.reserveCapacity(Int(reportedSize))
        while data.count <= maximumReadableFileBytes {
            let remainingLimit = Int(maximumReadableFileBytes) + 1 - data.count
            guard remainingLimit > 0,
                  let chunk = try handle.read(upToCount: min(64 * 1024, remainingLimit)),
                  !chunk.isEmpty else {
                break
            }
            data.append(chunk)
        }

        guard data.count <= maximumReadableFileBytes else {
            throw EditorDocumentError.fileTooLarge(
                path: url.path,
                sizeBytes: Int64(data.count),
                maximumBytes: maximumReadableFileBytes
            )
        }
        return data
    }

    private static func decodeText(_ data: Data, path: String) throws -> (text: String, encoding: TextFileEncoding) {
        let utf8ByteOrderMark = Data([0xEF, 0xBB, 0xBF])
        let utf16LittleEndianByteOrderMark = Data([0xFF, 0xFE])
        let utf16BigEndianByteOrderMark = Data([0xFE, 0xFF])
        if data.starts(with: utf8ByteOrderMark) {
            guard let text = String(
                data: data.dropFirst(utf8ByteOrderMark.count),
                encoding: .utf8
            ) else {
                throw EditorDocumentError.unsupportedTextEncoding(path: path)
            }
            try validatePlainText(text, path: path)
            return (text, .utf8WithByteOrderMark)
        }
        if data.starts(with: utf16LittleEndianByteOrderMark) {
            guard let text = String(
                data: data.dropFirst(utf16LittleEndianByteOrderMark.count),
                encoding: .utf16LittleEndian
            ) else {
                throw EditorDocumentError.unsupportedTextEncoding(path: path)
            }
            try validatePlainText(text, path: path)
            return (text, .utf16LittleEndian)
        }
        if data.starts(with: utf16BigEndianByteOrderMark) {
            guard let text = String(
                data: data.dropFirst(utf16BigEndianByteOrderMark.count),
                encoding: .utf16BigEndian
            ) else {
                throw EditorDocumentError.unsupportedTextEncoding(path: path)
            }
            try validatePlainText(text, path: path)
            return (text, .utf16BigEndian)
        }
        if let text = String(data: data, encoding: .utf8) {
            try validatePlainText(text, path: path)
            return (text, .utf8)
        }
        if data.contains(where: { (0x80...0x9F).contains($0) }),
           isPlausibleWindows1252Text(data),
           let text = String(data: data, encoding: .windowsCP1252) {
            try validatePlainText(text, path: path)
            return (text, .windows1252)
        }
        guard isPlausibleLatin1Text(data),
              let text = String(data: data, encoding: .isoLatin1) else {
            throw EditorDocumentError.unsupportedTextEncoding(path: path)
        }
        try validatePlainText(text, path: path)
        return (text, .isoLatin1)
    }

    private static func isPlausibleLatin1Text(_ data: Data) -> Bool {
        data.allSatisfy { byte in
            if byte == 0x09 || byte == 0x0A || byte == 0x0D {
                return true
            }
            return byte >= 0x20 && !(0x7F...0x9F).contains(byte)
        }
    }

    private static func isPlausibleWindows1252Text(_ data: Data) -> Bool {
        data.allSatisfy { byte in
            if byte == 0x09 || byte == 0x0A || byte == 0x0D {
                return true
            }
            return byte >= 0x20 && byte != 0x7F
        }
    }

    private static func validatePlainText(_ text: String, path: String) throws {
        let containsBinaryControl = text.unicodeScalars.contains { scalar in
            let value = scalar.value
            if value == 0x09 || value == 0x0A || value == 0x0D {
                return false
            }
            return value < 0x20 || (0x7F...0x9F).contains(value)
        }
        if containsBinaryControl {
            throw EditorDocumentError.unsupportedTextEncoding(path: path)
        }
    }

    private static func digest(_ data: Data) -> Data {
        Data(SHA256.hash(data: data))
    }
}
