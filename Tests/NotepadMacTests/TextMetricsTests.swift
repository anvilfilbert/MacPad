import XCTest
@testable import NotepadMacCore

final class TextMetricsTests: XCTestCase {
    func testCursorPositionAtStart() {
        XCTAssertEqual(TextMetrics.cursorPosition(in: "hello", selectedLocation: 0), CursorPosition(line: 1, column: 1))
    }

    func testCursorPositionAfterText() {
        XCTAssertEqual(TextMetrics.cursorPosition(in: "hello", selectedLocation: 5), CursorPosition(line: 1, column: 6))
    }

    func testCursorPositionAcrossLines() {
        XCTAssertEqual(TextMetrics.cursorPosition(in: "one\ntwo\nthree", selectedLocation: 8), CursorPosition(line: 3, column: 1))
    }

    func testCursorPositionBoundsSelection() {
        XCTAssertEqual(TextMetrics.cursorPosition(in: "a", selectedLocation: 100), CursorPosition(line: 1, column: 2))
    }

    func testNormalizesLineEndingsForSave() {
        XCTAssertEqual(TextMetrics.normalizedLineEndingsForSave("a\r\nb\rc"), "a\nb\nc")
    }

    func testSessionStateRoundTripsThroughJSON() throws {
        let state = AppSessionState(tabs: [
            EditorSessionState(
                id: "tab-1",
                filePath: "/tmp/example.txt",
                text: "changed",
                originalText: "original",
                selectedLocation: 3,
                wordWrapEnabled: true,
                statusBarVisible: false,
                zoomPercent: 120
            )
        ])

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AppSessionState.self, from: data)

        XCTAssertEqual(decoded, state)
    }
}
