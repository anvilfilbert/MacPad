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
    public let selectedLocation: Int
    public let wordWrapEnabled: Bool
    public let statusBarVisible: Bool
    public let zoomPercent: Int
    public let lineEnding: LineEnding

    private enum CodingKeys: String, CodingKey {
        case id
        case filePath
        case selectedLocation
        case wordWrapEnabled
        case statusBarVisible
        case zoomPercent
        case lineEnding
    }

    public init(
        id: String,
        filePath: String?,
        selectedLocation: Int,
        wordWrapEnabled: Bool,
        statusBarVisible: Bool,
        zoomPercent: Int,
        lineEnding: LineEnding
    ) {
        self.id = id
        self.filePath = filePath
        self.selectedLocation = selectedLocation
        self.wordWrapEnabled = wordWrapEnabled
        self.statusBarVisible = statusBarVisible
        self.zoomPercent = zoomPercent
        self.lineEnding = lineEnding
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
        selectedLocation = try container.decodeIfPresent(Int.self, forKey: .selectedLocation) ?? 0
        wordWrapEnabled = try container.decodeIfPresent(Bool.self, forKey: .wordWrapEnabled) ?? true
        statusBarVisible = try container.decodeIfPresent(Bool.self, forKey: .statusBarVisible) ?? true
        zoomPercent = try container.decodeIfPresent(Int.self, forKey: .zoomPercent) ?? 100
        lineEnding = try container.decodeIfPresent(LineEnding.self, forKey: .lineEnding) ?? .windows
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(filePath, forKey: .filePath)
        try container.encode(selectedLocation, forKey: .selectedLocation)
        try container.encode(wordWrapEnabled, forKey: .wordWrapEnabled)
        try container.encode(statusBarVisible, forKey: .statusBarVisible)
        try container.encode(zoomPercent, forKey: .zoomPercent)
        try container.encode(lineEnding, forKey: .lineEnding)
    }
}
