import Foundation
import Testing
@testable import NotepadMacCore

@Suite("Session state")
struct SessionStateTests {
    @Test("legacy filePath JSON migrates to a path-only reference")
    func migratesLegacyFilePath() throws {
        let data = Data(#"{"id":"legacy","filePath":"/tmp/legacy.txt"}"#.utf8)

        let state = try JSONDecoder().decode(EditorSessionState.self, from: data)

        #expect(
            state.fileReference
                == PersistedFileReference(path: "/tmp/legacy.txt", bookmarkData: nil)
        )
        #expect(state.filePath == "/tmp/legacy.txt")
    }

    @Test("new file reference with bookmark bytes round-trips")
    func roundTripsNewFileReference() throws {
        let reference = PersistedFileReference(
            path: "/tmp/bookmarked.txt",
            bookmarkData: Data([0x00, 0x80, 0xFF])
        )
        let state = EditorSessionState(
            id: "bookmarked",
            fileReference: reference,
            selectedLocation: 8,
            wordWrapEnabled: false,
            statusBarVisible: true,
            zoomPercent: 125,
            lineEnding: .unix
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EditorSessionState.self, from: encoded)

        #expect(decoded == state)
        #expect(decoded.fileReference == reference)
        #expect(decoded.filePath == reference.path)
    }

    @Test("encoded session uses only fileReference and excludes document text")
    func encodesOnlyNewFileFieldAndNoText() throws {
        let state = EditorSessionState(
            id: "bookmarked",
            fileReference: PersistedFileReference(
                path: "/tmp/bookmarked.txt",
                bookmarkData: Data([0xAB, 0xCD])
            ),
            selectedLocation: 0,
            wordWrapEnabled: true,
            statusBarVisible: true,
            zoomPercent: 100,
            lineEnding: .windows
        )

        let encoded = try JSONEncoder().encode(state)
        let fields = try JSONDecoder().decode(JSONObjectKeySet.self, from: encoded)

        #expect(fields.keys.contains("fileReference"))
        #expect(!fields.keys.contains("filePath"))
        #expect(!fields.keys.contains("text"))
        #expect(!fields.keys.contains("originalText"))
    }

    @Test("untitled session encodes neither file field")
    func untitledSessionEncodesNoFileField() throws {
        let state = EditorSessionState(
            id: "untitled",
            fileReference: nil,
            selectedLocation: 0,
            wordWrapEnabled: true,
            statusBarVisible: true,
            zoomPercent: 100,
            lineEnding: .windows
        )

        let encoded = try JSONEncoder().encode(state)
        let fields = try JSONDecoder().decode(JSONObjectKeySet.self, from: encoded)

        #expect(!fields.keys.contains("fileReference"))
        #expect(!fields.keys.contains("filePath"))
    }

    @Test("explicit null fileReference overrides a legacy filePath")
    func explicitNullNewReferenceIsAuthoritative() throws {
        let data = Data(
            #"{"id":"untitled","fileReference":null,"filePath":"/tmp/legacy.txt"}"#.utf8
        )

        let state = try JSONDecoder().decode(EditorSessionState.self, from: data)

        #expect(state.fileReference == nil)
        #expect(state.filePath == nil)
    }

    @Test("malformed new bookmark fails even when legacy filePath is valid")
    func malformedNewBookmarkFailsClosed() {
        let data = Data(
            #"{"id":"invalid","fileReference":{"path":"/tmp/new.txt","bookmarkData":"%%%"},"filePath":"/tmp/legacy.txt"}"#.utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(EditorSessionState.self, from: data)
        }
    }

    @Test("decoded zoom is bounded to supported values")
    func boundsDecodedZoom() throws {
        let data = Data(
            """
            {
              "id": "tab",
              "selectedLocation": -8,
              "wordWrapEnabled": true,
              "statusBarVisible": true,
              "zoomPercent": 9000,
              "lineEnding": "windows"
            }
            """.utf8
        )

        let state = try JSONDecoder().decode(EditorSessionState.self, from: data)

        #expect(state.selectedLocation == 0)
        #expect(state.zoomPercent == 500)
    }

    @Test("unreasonably large tab collections are rejected")
    func rejectsExcessiveTabs() throws {
        let tab = """
        {"id":"tab","selectedLocation":0,"wordWrapEnabled":true,"statusBarVisible":true,"zoomPercent":100,"lineEnding":"windows"}
        """
        let tabs = Array(repeating: tab, count: 101).joined(separator: ",")
        let data = Data("{\"windows\":[{\"tabs\":[\(tabs)]}]}".utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppSessionState.self, from: data)
        }
    }

    @Test("unreasonably large window collections are rejected")
    func rejectsExcessiveWindows() {
        let windows = Array(repeating: "{\"tabs\":[]}", count: 51)
            .joined(separator: ",")
        let data = Data("{\"windows\":[\(windows)]}".utf8)

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(AppSessionState.self, from: data)
        }
    }

    @Test("session creation retains only restorable recent windows")
    func boundsCreatedWindows() throws {
        let windows = (0...AppSessionState.maximumWindowCount).map { index in
            EditorWindowSessionState(tabs: [sessionTab(id: "tab-\(index)")])
        }

        let state = AppSessionState(windows: windows)
        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AppSessionState.self, from: encoded)

        #expect(state.windows.count == AppSessionState.maximumWindowCount)
        #expect(decoded.windows.count == AppSessionState.maximumWindowCount)
        #expect(decoded.windows.first?.tabs.first?.id == "tab-1")
        #expect(decoded.windows.last?.tabs.first?.id == "tab-50")
    }

    @Test("window creation retains the selected tab and recent tabs")
    func boundsCreatedTabs() throws {
        let tabs = (0...AppSessionState.maximumTabsPerWindow).map { index in
            sessionTab(id: "tab-\(index)")
        }

        let state = EditorWindowSessionState(
            tabs: tabs,
            selectedTabIndex: 0,
            frame: nil
        )
        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EditorWindowSessionState.self, from: encoded)

        #expect(state.tabs.count == AppSessionState.maximumTabsPerWindow)
        #expect(state.tabs.first?.id == "tab-0")
        #expect(state.tabs.last?.id == "tab-100")
        #expect(state.selectedTabIndex == 0)
        #expect(decoded == state)
    }

    @Test("tab truncation retains recently used tabs regardless of tab-strip position")
    func retainsRecentlyUsedTabs() {
        let tabs = (0...AppSessionState.maximumTabsPerWindow).map { index in
            sessionTab(id: "tab-\(index)")
        }
        let recency = Array(1...AppSessionState.maximumTabsPerWindow) + [0]

        let state = EditorWindowSessionState(
            tabs: tabs,
            selectedTabIndex: 50,
            frame: nil,
            recentlyUsedTabIndices: recency
        )

        #expect(state.tabs.count == AppSessionState.maximumTabsPerWindow)
        #expect(state.tabs.contains(where: { $0.id == "tab-0" }))
        #expect(!state.tabs.contains(where: { $0.id == "tab-1" }))
        #expect(state.tabs[state.selectedTabIndex].id == "tab-50")
    }

    @Test("window state preserves frame and selected tab")
    func preservesWindowMetadata() throws {
        let first = sessionTab(id: "first")
        let second = sessionTab(id: "second")
        let frame = WindowFrameState(x: 100, y: 120, width: 820, height: 580)
        let state = EditorWindowSessionState(
            tabs: [first, second],
            selectedTabIndex: 1,
            frame: frame
        )

        let encoded = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EditorWindowSessionState.self, from: encoded)

        #expect(decoded == state)
    }

    @Test("legacy window state gets safe metadata defaults")
    func decodesLegacyWindowState() throws {
        let data = Data(
            """
            {"tabs":[{"id":"tab","selectedLocation":0,"wordWrapEnabled":true,"statusBarVisible":true,"zoomPercent":100,"lineEnding":"windows"}]}
            """.utf8
        )

        let state = try JSONDecoder().decode(EditorWindowSessionState.self, from: data)

        #expect(state.selectedTabIndex == 0)
        #expect(state.frame == nil)
    }

    @Test("selected tab index is bounded by decoded tabs")
    func boundsSelectedTabIndex() throws {
        let data = Data(
            """
            {"tabs":[{"id":"tab","selectedLocation":0,"wordWrapEnabled":true,"statusBarVisible":true,"zoomPercent":100,"lineEnding":"windows"}],"selectedTabIndex":99}
            """.utf8
        )

        let state = try JSONDecoder().decode(EditorWindowSessionState.self, from: data)

        #expect(state.selectedTabIndex == 0)
    }

    private func sessionTab(id: String) -> EditorSessionState {
        EditorSessionState(
            id: id,
            filePath: nil,
            selectedLocation: 0,
            wordWrapEnabled: true,
            statusBarVisible: true,
            zoomPercent: 100,
            lineEnding: .windows
        )
    }
}

private struct JSONObjectKeySet: Decodable {
    let keys: Set<String>

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: JSONKey.self)
        keys = Set(container.allKeys.map(\.stringValue))
    }
}

private struct JSONKey: CodingKey {
    let stringValue: String
    let intValue: Int?

    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }

    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}
