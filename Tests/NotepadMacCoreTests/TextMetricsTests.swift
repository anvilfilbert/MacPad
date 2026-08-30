import Testing
@testable import NotepadMacCore

@Suite("Text metrics")
struct TextMetricsTests {
    @Test("line-ending labels use the injected German bundle")
    func localizesLineEndingLabels() throws {
        try LocalizationFixture.with(
            languageCode: "de",
            strings: [:],
            technicalTerms: [
                "macpad.term.line-ending.windows-crlf": "Windows-Zeilenende (CRLF)",
                "macpad.term.line-ending.unix-lf": "Unix-Zeilenende (LF)",
                "macpad.term.line-ending.classic-mac-cr": "Mac-Zeilenende (CR)",
                "macpad.term.line-ending.mixed": "Gemischte Zeilenenden"
            ]
        ) { localization in
            let lineEndings: [LineEnding] = [.windows, .unix, .classicMac, .mixed]
            #expect(
                lineEndings.map { $0.statusLabel(using: localization) }
                    == [
                        "Windows-Zeilenende (CRLF)",
                        "Unix-Zeilenende (LF)",
                        "Mac-Zeilenende (CR)",
                        "Gemischte Zeilenenden"
                    ]
            )
        }
    }

    @Test("indexed cursor positions use UTF-16 text-view locations")
    func indexedCursorPositions() {
        let index = TextLineIndex(text: "first\nsecond\n")

        #expect(index.cursorPosition(selectedLocation: 0) == CursorPosition(line: 1, column: 1))
        #expect(index.cursorPosition(selectedLocation: 8) == CursorPosition(line: 2, column: 3))
        #expect(index.cursorPosition(selectedLocation: 13) == CursorPosition(line: 3, column: 1))
    }

    @Test("indexed cursor lookup remains correct for large documents")
    func indexedLargeDocumentLookup() {
        let text = Array(repeating: "0123456789\n", count: 100_000).joined()
        let index = TextLineIndex(text: text)

        #expect(index.cursorPosition(selectedLocation: 1_099_995) == CursorPosition(line: 100_000, column: 7))
        #expect(index.location(ofLine: 100_000) == 1_099_989)
    }

    @Test("line starts use text-view UTF-16 locations")
    func lineStartLocations() {
        #expect(TextMetrics.location(ofLine: 1, in: "first\nsecond") == 0)
        #expect(TextMetrics.location(ofLine: 2, in: "first\nsecond") == 6)
    }

    @Test("a trailing newline creates one final empty line")
    func trailingNewlineBounds() {
        #expect(TextMetrics.location(ofLine: 2, in: "first\n") == 6)
        #expect(TextMetrics.location(ofLine: 3, in: "first\n") == nil)
    }

    @Test("line index treats CRLF and CR as line endings")
    func indexesMixedLineEndings() {
        let index = TextLineIndex(text: "a\r\nb\rc\nd")

        #expect(index.location(ofLine: 1) == 0)
        #expect(index.location(ofLine: 2) == 3)
        #expect(index.location(ofLine: 3) == 5)
        #expect(index.location(ofLine: 4) == 7)
        #expect(index.cursorPosition(selectedLocation: 7) == CursorPosition(line: 4, column: 1))
    }

    @Test("non-positive line numbers are rejected")
    func rejectsNonPositiveLineNumbers() {
        #expect(TextMetrics.location(ofLine: 0, in: "first") == nil)
        #expect(TextMetrics.location(ofLine: -1, in: "first") == nil)
    }
}
