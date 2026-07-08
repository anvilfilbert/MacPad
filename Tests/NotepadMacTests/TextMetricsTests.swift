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

    func testNormalizesLineEndingsForEditing() {
        XCTAssertEqual(TextMetrics.normalizedLineEndingsForEditing("a\r\nb\rc"), "a\nb\nc")
    }

    func testDetectsWindowsLineEndings() {
        XCTAssertEqual(LineEnding.detected(in: "a\r\nb"), .windows)
    }

    func testDetectsUnixLineEndings() {
        XCTAssertEqual(LineEnding.detected(in: "a\nb"), .unix)
    }

    func testDetectsClassicMacLineEndings() {
        XCTAssertEqual(LineEnding.detected(in: "a\rb"), .classicMac)
    }

    func testNewDocumentsDefaultToWindowsLineEndings() {
        XCTAssertEqual(LineEnding.detected(in: "no line break"), .windows)
    }

    func testFormatsWindowsLineEndingsForSave() {
        XCTAssertEqual(TextMetrics.textForSave("a\nb\n", lineEnding: .windows), "a\r\nb\r\n")
    }

    func testFormatsUnixLineEndingsForSave() {
        XCTAssertEqual(TextMetrics.textForSave("a\r\nb\r", lineEnding: .unix), "a\nb\n")
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
                zoomPercent: 120,
                lineEnding: .unix
            )
        ])

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(AppSessionState.self, from: data)

        XCTAssertEqual(decoded, state)
    }
}
