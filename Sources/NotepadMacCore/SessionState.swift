import Foundation

public struct AppSessionState: Codable, Equatable {
    public let tabs: [EditorSessionState]

    public init(tabs: [EditorSessionState]) {
        self.tabs = tabs
    }
}

public struct EditorSessionState: Codable, Equatable {
    public let id: String
    public let filePath: String?
    public let text: String
    public let originalText: String
    public let selectedLocation: Int
    public let wordWrapEnabled: Bool
    public let statusBarVisible: Bool
    public let zoomPercent: Int
    public let lineEnding: LineEnding

    public init(
        id: String,
        filePath: String?,
        text: String,
        originalText: String,
        selectedLocation: Int,
        wordWrapEnabled: Bool,
        statusBarVisible: Bool,
        zoomPercent: Int,
        lineEnding: LineEnding = .windows
    ) {
        self.id = id
        self.filePath = filePath
        self.text = text
        self.originalText = originalText
        self.selectedLocation = selectedLocation
        self.wordWrapEnabled = wordWrapEnabled
        self.statusBarVisible = statusBarVisible
        self.zoomPercent = zoomPercent
        self.lineEnding = lineEnding
    }
}
