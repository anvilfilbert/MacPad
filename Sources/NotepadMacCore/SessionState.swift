import Foundation

public struct AppSessionState: Codable, Equatable {
    public static let maximumWindowCount = 50
    public static let maximumTabsPerWindow = 100
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
        if container.contains(.windows) {
            var windowsContainer = try container.nestedUnkeyedContainer(forKey: .windows)
            var decodedWindows: [EditorWindowSessionState] = []
            while !windowsContainer.isAtEnd {
                guard decodedWindows.count < Self.maximumWindowCount else {
                    throw Self.limitError(codingPath: decoder.codingPath)
                }
                decodedWindows.append(try windowsContainer.decode(EditorWindowSessionState.self))
            }
            windows = decodedWindows
        } else if container.contains(.tabs) {
            var tabsContainer = try container.nestedUnkeyedContainer(forKey: .tabs)
            var decodedTabs: [EditorSessionState] = []
            while !tabsContainer.isAtEnd {
                guard decodedTabs.count < Self.maximumTabsPerWindow else {
                    throw Self.limitError(codingPath: decoder.codingPath)
                }
                decodedTabs.append(try tabsContainer.decode(EditorSessionState.self))
            }
            windows = decodedTabs.isEmpty ? [] : [EditorWindowSessionState(tabs: decodedTabs)]
        } else {
            windows = []
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(windows, forKey: .windows)
    }

    private static func limitError(codingPath: [any CodingKey]) -> DecodingError {
        DecodingError.dataCorrupted(
            .init(
                codingPath: codingPath,
                debugDescription: "Session contains more windows or tabs than MacPad supports."
            )
        )
    }
}

public struct EditorWindowSessionState: Codable, Equatable {
    public let tabs: [EditorSessionState]
    public let selectedTabIndex: Int
    public let frame: WindowFrameState?

    private enum CodingKeys: String, CodingKey {
        case tabs
        case selectedTabIndex
        case frame
    }

    public init(tabs: [EditorSessionState]) {
        self.init(tabs: tabs, selectedTabIndex: 0, frame: nil)
    }

    public init(
        tabs: [EditorSessionState],
        selectedTabIndex: Int,
        frame: WindowFrameState?
    ) {
        self.tabs = tabs
        self.selectedTabIndex = Self.boundedSelectedTabIndex(
            selectedTabIndex,
            tabCount: tabs.count
        )
        self.frame = frame?.isUsable == true ? frame : nil
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        var tabsContainer = try container.nestedUnkeyedContainer(forKey: .tabs)
        var decodedTabs: [EditorSessionState] = []
        while !tabsContainer.isAtEnd {
            guard decodedTabs.count < AppSessionState.maximumTabsPerWindow else {
                throw DecodingError.dataCorrupted(
                    .init(
                        codingPath: decoder.codingPath,
                        debugDescription: "Session contains more tabs than MacPad supports."
                    )
                )
            }
            decodedTabs.append(try tabsContainer.decode(EditorSessionState.self))
        }
        tabs = decodedTabs
        let decodedIndex = try container.decodeIfPresent(Int.self, forKey: .selectedTabIndex) ?? 0
        selectedTabIndex = Self.boundedSelectedTabIndex(
            decodedIndex,
            tabCount: decodedTabs.count
        )
        let decodedFrame = try container.decodeIfPresent(WindowFrameState.self, forKey: .frame)
        frame = decodedFrame?.isUsable == true ? decodedFrame : nil
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(tabs, forKey: .tabs)
        try container.encode(selectedTabIndex, forKey: .selectedTabIndex)
        try container.encodeIfPresent(frame, forKey: .frame)
    }

    private static func boundedSelectedTabIndex(_ index: Int, tabCount: Int) -> Int {
        guard tabCount > 0 else { return 0 }
        return min(max(0, index), tabCount - 1)
    }
}

public struct WindowFrameState: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    fileprivate var isUsable: Bool {
        let values = [x, y, width, height]
        return values.allSatisfy(\.isFinite)
            && width >= 320
            && height >= 240
            && width <= 20_000
            && height <= 20_000
            && abs(x) <= 1_000_000
            && abs(y) <= 1_000_000
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
        selectedLocation = max(0, try container.decodeIfPresent(Int.self, forKey: .selectedLocation) ?? 0)
        wordWrapEnabled = try container.decodeIfPresent(Bool.self, forKey: .wordWrapEnabled) ?? true
        statusBarVisible = try container.decodeIfPresent(Bool.self, forKey: .statusBarVisible) ?? true
        zoomPercent = min(500, max(10, try container.decodeIfPresent(Int.self, forKey: .zoomPercent) ?? 100))
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
