import Foundation

public struct AppSessionState: Codable, Equatable {
    public let windows: [EditorWindowSessionState]

    public init(windows: [EditorWindowSessionState]) {
        self.windows = windows
    }

    public init(tabs: [EditorSessionState]) {
        self.windows = [EditorWindowSessionState(tabs: tabs)]
    }

    public var tabs: [EditorSessionState] {
        windows.flatMap(\.tabs)
    }

    private enum CodingKeys: String, CodingKey {
        case windows
        case tabs
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if let windows = try container.decodeIfPresent([EditorWindowSessionState].self, forKey: .windows) {
            self.windows = windows
        } else {
            let tabs = try container.decodeIfPresent([EditorSessionState].self, forKey: .tabs) ?? []
            self.windows = tabs.isEmpty ? [] : [EditorWindowSessionState(tabs: tabs)]
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windows, forKey: .windows)
    }
}

public struct EditorWindowSessionState: Codable, Equatable {
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
