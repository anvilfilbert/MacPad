import Foundation
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

    @Test("selection matching can require exact case")
    func matchesSelectionWithExactCase() {
        #expect(
            !TextEditingOperations.selectionMatches(
                selectedText: "MacPad",
                searchTerm: "macpad",
                matchCase: true
            )
        )
    }

    @Test("forward search does not wrap when disabled")
    func forwardSearchWithoutWrapping() {
        let options = FindOptions(matchCase: false, wrapAround: false)
        let result = TextEditingOperations.findRange(
            in: "MacPad text MacPad",
            searchTerm: "MacPad",
            selectedRange: NSRange(location: 12, length: 6),
            backwards: false,
            options: options
        )

        #expect(result == nil)
    }

    @Test("forward search wraps when enabled")
    func forwardSearchWithWrapping() {
        let options = FindOptions(matchCase: false, wrapAround: true)
        let result = TextEditingOperations.findRange(
            in: "MacPad text MacPad",
            searchTerm: "macpad",
            selectedRange: NSRange(location: 12, length: 6),
            backwards: false,
            options: options
        )

        #expect(result == NSRange(location: 0, length: 6))
    }

    @Test("wrapped search can return the only selected match")
    func wrapsToOnlySelectedMatch() {
        let options = FindOptions(matchCase: false, wrapAround: true)
        let result = TextEditingOperations.findRange(
            in: "MacPad",
            searchTerm: "MacPad",
            selectedRange: NSRange(location: 0, length: 6),
            backwards: false,
            options: options
        )

        #expect(result == NSRange(location: 0, length: 6))
    }

    @Test("case-sensitive search ignores differently cased text")
    func caseSensitiveSearch() {
        let options = FindOptions(matchCase: true, wrapAround: true)
        let result = TextEditingOperations.findRange(
            in: "macpad MacPad",
            searchTerm: "MacPad",
            selectedRange: NSRange(location: 0, length: 0),
            backwards: false,
            options: options
        )

        #expect(result == NSRange(location: 7, length: 6))
    }

    @Test("replace all follows match-case setting")
    func replaceAllWithExactCase() {
        let result = TextEditingOperations.replacingAll(
            in: "MacPad macpad MacPad",
            searchTerm: "MacPad",
            replacement: "Editor",
            matchCase: true
        )

        #expect(result == "Editor macpad Editor")
    }
}
