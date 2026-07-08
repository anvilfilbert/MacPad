import Foundation
import Testing
@testable import NotepadMacCore

@Suite("EditorDocument")
struct EditorDocumentTests {
    @Test func loadFileNormalizesLineEndingsAndDetectsWindowsFiles() throws {
        let url = try makeTemporaryFile(contents: "one\r\ntwo\r\n")
        let document = EditorDocument()

        try document.loadFile(url)

        #expect(document.fileURL == url)
        #expect(document.displayName == url.lastPathComponent)
        #expect(document.text == "one\ntwo\n")
        #expect(document.originalText == "one\ntwo\n")
        #expect(document.lineEnding == .windows)
        #expect(document.hasUnsavedChanges == false)
    }

    @Test func savePreservesDetectedLineEndingAndClearsDirtyState() throws {
        let sourceURL = try makeTemporaryFile(contents: "one\r\ntwo")
        let outputURL = temporaryDirectory().appendingPathComponent("saved.txt")
        let document = EditorDocument()

        try document.loadFile(sourceURL)
        document.updateText("one\ntwo\nthree")
        #expect(document.hasUnsavedChanges == true)

        try document.save(to: outputURL)

        let savedText = try String(contentsOf: outputURL, encoding: .utf8)
        #expect(savedText == "one\r\ntwo\r\nthree")
        #expect(document.fileURL == outputURL)
        #expect(document.originalText == "one\ntwo\nthree")
        #expect(document.hasUnsavedChanges == false)
    }

    @Test func sessionStateCanBeSuppressedAndRestored() throws {
        let document = EditorDocument(id: "doc-1")
        document.updateText("draft")

        document.discardFromSessionRestore()
        #expect(document.sessionState(selectedLocation: 0, wordWrapEnabled: true, statusBarVisible: true, zoomPercent: 100) == nil)

        document.keepInSessionRestore()
        let state = try #require(document.sessionState(selectedLocation: 2, wordWrapEnabled: false, statusBarVisible: false, zoomPercent: 150))

        #expect(state.id == "doc-1")
        #expect(state.text == "draft")
        #expect(state.selectedLocation == 2)
        #expect(state.wordWrapEnabled == false)
        #expect(state.statusBarVisible == false)
        #expect(state.zoomPercent == 150)
    }

    @Test func restoreSessionStateRestoresDocumentIdentityAndDirtyState() {
        let document = EditorDocument()
        let state = EditorSessionState(
            id: "restored",
            filePath: "/tmp/example.txt",
            text: "changed",
            originalText: "original",
            selectedLocation: 0,
            wordWrapEnabled: true,
            statusBarVisible: true,
            zoomPercent: 100,
            lineEnding: .unix
        )

        document.restoreSessionState(state)

        #expect(document.id == "restored")
        #expect(document.fileURL?.path == "/tmp/example.txt")
        #expect(document.text == "changed")
        #expect(document.originalText == "original")
        #expect(document.lineEnding == .unix)
        #expect(document.hasUnsavedChanges == true)
    }

    @Test func textMetricsReportsCursorPositionAndConvertsLineEndings() {
        let position = TextMetrics.cursorPosition(in: "one\ntwo", selectedLocation: 5)

        #expect(position == CursorPosition(line: 2, column: 2))
        #expect(TextMetrics.normalizedLineEndingsForEditing("a\r\nb\rc") == "a\nb\nc")
        #expect(TextMetrics.textForSave("a\nb", lineEnding: .classicMac) == "a\rb")
    }

    private func makeTemporaryFile(contents: String) throws -> URL {
        let directory = temporaryDirectory()
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("txt")
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private func temporaryDirectory() -> URL {
        URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
            .appendingPathComponent("MacPadTests", isDirectory: true)
    }
}
