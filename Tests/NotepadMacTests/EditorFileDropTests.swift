import AppKit
import Testing
@testable import NotepadMac

@Suite("Editor file drops")
@MainActor
struct EditorFileDropTests {
    @Test("Finder text-file URLs open in their original order")
    func acceptsMultipleRegularTextFiles() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let firstURL = directory.appendingPathComponent("first.txt")
        let secondURL = directory.appendingPathComponent("second.md")
        try Data("First".utf8).write(to: firstURL)
        try Data("Second".utf8).write(to: secondURL)
        let pasteboard = try makeFilePasteboard(urls: [firstURL, secondURL])

        let decision = EditorFileDropClassifier.classify(pasteboard: pasteboard)

        #expect(decision == .openFiles([firstURL.standardizedFileURL, secondURL.standardizedFileURL]))
    }

    @Test("literal path text remains an ordinary text drop")
    func defersLiteralPathTextToTextView() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        try #require(pasteboard.setString("/tmp/example.txt", forType: .string))

        let decision = EditorFileDropClassifier.classify(pasteboard: pasteboard)

        #expect(decision == .deferToTextView)
    }

    @Test("directories do not become editor text or documents")
    func rejectsDirectoryFileURL() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let pasteboard = try makeFilePasteboard(urls: [directory])

        let decision = EditorFileDropClassifier.classify(pasteboard: pasteboard)

        #expect(decision == .rejectFileDrop)
    }

    @Test("unsupported, special, and missing file URLs are rejected")
    func rejectsInvalidFileURLs() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let imageURL = directory.appendingPathComponent("image.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: imageURL)
        let missingURL = directory.appendingPathComponent("missing.txt")
        let specialURL = URL(fileURLWithPath: "/dev/null")

        for url in [imageURL, missingURL, specialURL] {
            let decision = EditorFileDropClassifier.classify(
                pasteboard: try makeFilePasteboard(urls: [url])
            )
            #expect(decision == .rejectFileDrop)
        }
    }

    @Test("handling a valid file drop never changes editor text or selection")
    func preservesEditorContentWhileOpeningFiles() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("opened.txt")
        try Data("Opened separately".utf8).write(to: fileURL)
        let editor = EditorTextView()
        editor.string = "Unsaved editor text"
        editor.setSelectedRange(NSRange(location: 3, length: 5))
        var openedURLs: [URL] = []
        editor.onOpenDroppedFiles = { urls in
            openedURLs = urls
        }

        let handled = editor.handleFileDrop(
            pasteboard: try makeFilePasteboard(urls: [fileURL])
        )

        #expect(handled)
        #expect(openedURLs == [fileURL.standardizedFileURL])
        #expect(editor.string == "Unsaved editor text")
        #expect(editor.selectedRange() == NSRange(location: 3, length: 5))
    }

    @Test("a dropped file already open resolves to its existing editor")
    func resolvesDuplicateDroppedFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let fileURL = directory.appendingPathComponent("already-open.txt")
        try Data("Already open".utf8).write(to: fileURL)
        let existingEditor = EditorWindowController()
        try existingEditor.loadFile(fileURL)
        let decision = EditorFileDropClassifier.classify(
            pasteboard: try makeFilePasteboard(urls: [fileURL])
        )
        guard case let .openFiles(urls) = decision else {
            Issue.record("Expected a supported Finder file-URL drop.")
            return
        }

        let resolved = EditorWindowResolver.controller(
            opening: try #require(urls.first),
            controllers: [existingEditor]
        )

        #expect(resolved === existingEditor)
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func makeFilePasteboard(urls: [URL]) throws -> NSPasteboard {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name(UUID().uuidString))
        pasteboard.clearContents()
        try #require(pasteboard.writeObjects(urls.map { $0 as NSURL }))
        return pasteboard
    }
}
