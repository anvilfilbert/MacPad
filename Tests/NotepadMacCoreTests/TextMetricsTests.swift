import Testing
@testable import NotepadMacCore

@Suite("Text metrics")
struct TextMetricsTests {
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

    @Test("non-positive line numbers are rejected")
    func rejectsNonPositiveLineNumbers() {
        #expect(TextMetrics.location(ofLine: 0, in: "first") == nil)
        #expect(TextMetrics.location(ofLine: -1, in: "first") == nil)
    }
}
