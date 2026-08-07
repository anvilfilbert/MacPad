import Testing
@testable import NotepadMacCore

@Suite("Text editing operations")
struct TextEditingOperationsTests {
    @Test("empty search terms never match a selection")
    func rejectsEmptySearchTerm() {
        #expect(
            !TextEditingOperations.selectionMatches(
                selectedText: "",
                searchTerm: ""
            )
        )
    }

    @Test("selection matching is case insensitive")
    func matchesSelectionCaseInsensitively() {
        #expect(
            TextEditingOperations.selectionMatches(
                selectedText: "MacPad",
                searchTerm: "macpad"
            )
        )
    }
}
