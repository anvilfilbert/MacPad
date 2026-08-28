import Foundation

private enum SessionStateLocalization {
    static let userInfoKey = CodingUserInfoKey(
        rawValue: "local.macpad.session-state-localization"
    )!

    static func from(_ decoder: Decoder) -> MacPadLocalization {
        if let localization = decoder.userInfo[userInfoKey] as? MacPadLocalization {
            return localization
        }
        return MacPadLocalization(bundle: .main)
    }
}

public struct AppSessionState: Codable, Equatable {
    public static let maximumWindowCount = 50
    public static let maximumTabsPerWindow = 100
    public let windows: [EditorWindowSessionState]

    public init(windows: [EditorWindowSessionState]) {
        self.windows = Array(windows.suffix(Self.maximumWindowCount))
    }

    public init(tabs: [EditorSessionState]) {
        self.windows = [EditorWindowSessionState(tabs: tabs)]
    }

    public var tabs: [EditorSessionState] {
        windows.flatMap(\.tabs)
    }

    public static func decode(
        data: Data,
        localization: MacPadLocalization
    ) throws -> AppSessionState {
        let decoder = JSONDecoder()
        decoder.userInfo[SessionStateLocalization.userInfoKey] = localization
        return try decoder.decode(AppSessionState.self, from: data)
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
                    throw Self.limitError(
                        codingPath: decoder.codingPath,
                        localization: SessionStateLocalization.from(decoder)
                    )
                }
                decodedWindows.append(try windowsContainer.decode(EditorWindowSessionState.self))
            }
            windows = decodedWindows
        } else if container.contains(.tabs) {
            var tabsContainer = try container.nestedUnkeyedContainer(forKey: .tabs)
            var decodedTabs: [EditorSessionState] = []
            while !tabsContainer.isAtEnd {
                guard decodedTabs.count < Self.maximumTabsPerWindow else {
                    throw Self.limitError(
                        codingPath: decoder.codingPath,
                        localization: SessionStateLocalization.from(decoder)
                    )
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

    private static func limitError(
        codingPath: [any CodingKey],
        localization: MacPadLocalization
    ) -> DecodingError {
        DecodingError.dataCorrupted(
            .init(
                codingPath: codingPath,
                debugDescription: localization.string(.sessionWindowOrTabLimit)
            )
        )
    }
}

public struct EditorWindowSessionState: Codable, Equatable {
    private struct BoundedTabs {
        let tabs: [EditorSessionState]
        let selectedTabIndex: Int
    }

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
        self.init(
            tabs: tabs,
            selectedTabIndex: selectedTabIndex,
            frame: frame,
            recentlyUsedTabIndices: Array(tabs.indices)
        )
    }

    public init(
        tabs: [EditorSessionState],
        selectedTabIndex: Int,
        frame: WindowFrameState?,
        recentlyUsedTabIndices: [Int]
    ) {
        let boundedTabs = Self.boundedTabs(
            tabs,
            selectedTabIndex: selectedTabIndex,
            recentlyUsedTabIndices: recentlyUsedTabIndices
        )
        self.tabs = boundedTabs.tabs
        self.selectedTabIndex = boundedTabs.selectedTabIndex
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
                        debugDescription: SessionStateLocalization.from(decoder)
                            .string(.sessionTabLimit)
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

    private static func boundedTabs(
        _ tabs: [EditorSessionState],
        selectedTabIndex: Int,
        recentlyUsedTabIndices: [Int]
    ) -> BoundedTabs {
        let boundedSelection = boundedSelectedTabIndex(selectedTabIndex, tabCount: tabs.count)
        guard tabs.count > AppSessionState.maximumTabsPerWindow else {
            return BoundedTabs(tabs: tabs, selectedTabIndex: boundedSelection)
        }

        var seenRecentIndices = Set<Int>()
        let validRecentIndices = recentlyUsedTabIndices.filter { index in
            tabs.indices.contains(index) && seenRecentIndices.insert(index).inserted
        }
        let untrackedIndices = tabs.indices.filter { !seenRecentIndices.contains($0) }
        let completeRecency = untrackedIndices + validRecentIndices
        var retainedIndices = Array(
            completeRecency.suffix(AppSessionState.maximumTabsPerWindow)
        )
        if !retainedIndices.contains(boundedSelection) {
            retainedIndices.removeFirst()
            retainedIndices.append(boundedSelection)
        }
        retainedIndices.sort()
        let retainedTabs = retainedIndices.map { tabs[$0] }
        guard let retainedSelection = retainedIndices.firstIndex(of: boundedSelection) else {
            preconditionFailure("Bounded tabs must retain the selected tab.")
        }
        return BoundedTabs(tabs: retainedTabs, selectedTabIndex: retainedSelection)
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
    public let fileReference: PersistedFileReference?
    public let selectedLocation: Int
    public let wordWrapEnabled: Bool
    public let statusBarVisible: Bool
    public let zoomPercent: Int
    public let lineEnding: LineEnding

    public var filePath: String? {
        fileReference?.path
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case fileReference
        case filePath
        case selectedLocation
        case wordWrapEnabled
        case statusBarVisible
        case zoomPercent
        case lineEnding
    }

    public init(
        id: String,
        fileReference: PersistedFileReference?,
        selectedLocation: Int,
        wordWrapEnabled: Bool,
        statusBarVisible: Bool,
        zoomPercent: Int,
        lineEnding: LineEnding
    ) {
        self.id = id
        self.fileReference = fileReference
        self.selectedLocation = selectedLocation
        self.wordWrapEnabled = wordWrapEnabled
        self.statusBarVisible = statusBarVisible
        self.zoomPercent = zoomPercent
        self.lineEnding = lineEnding
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
        self.init(
            id: id,
            fileReference: filePath.map {
                PersistedFileReference(path: $0, bookmarkData: nil)
            },
            selectedLocation: selectedLocation,
            wordWrapEnabled: wordWrapEnabled,
            statusBarVisible: statusBarVisible,
            zoomPercent: zoomPercent,
            lineEnding: lineEnding
        )
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        if container.contains(.fileReference) {
            fileReference = try container.decodeIfPresent(
                PersistedFileReference.self,
                forKey: .fileReference
            )
        } else {
            fileReference = try container.decodeIfPresent(
                String.self,
                forKey: .filePath
            ).map {
                PersistedFileReference(path: $0, bookmarkData: nil)
            }
        }
        selectedLocation = max(0, try container.decodeIfPresent(Int.self, forKey: .selectedLocation) ?? 0)
        wordWrapEnabled = try container.decodeIfPresent(Bool.self, forKey: .wordWrapEnabled) ?? true
        statusBarVisible = try container.decodeIfPresent(Bool.self, forKey: .statusBarVisible) ?? true
        zoomPercent = min(500, max(10, try container.decodeIfPresent(Int.self, forKey: .zoomPercent) ?? 100))
        lineEnding = try container.decodeIfPresent(LineEnding.self, forKey: .lineEnding) ?? .windows
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encodeIfPresent(fileReference, forKey: .fileReference)
        try container.encode(selectedLocation, forKey: .selectedLocation)
        try container.encode(wordWrapEnabled, forKey: .wordWrapEnabled)
        try container.encode(statusBarVisible, forKey: .statusBarVisible)
        try container.encode(zoomPercent, forKey: .zoomPercent)
        try container.encode(lineEnding, forKey: .lineEnding)
    }
}
