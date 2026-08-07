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
}
