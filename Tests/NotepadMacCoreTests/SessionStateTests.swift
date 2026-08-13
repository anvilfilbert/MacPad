import Foundation
import Testing
@testable import NotepadMacCore

@Suite("Session state")
struct SessionStateTests {
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
