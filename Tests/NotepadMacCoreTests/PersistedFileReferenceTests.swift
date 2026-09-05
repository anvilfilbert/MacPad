import Foundation
import Testing
@testable import NotepadMacCore

@Suite("Persisted file reference")
struct PersistedFileReferenceTests {
    @Test("document initializers derive coherent path-only or untitled references")
    func documentInitializersDeriveReferences() {
        let fileURL = URL(fileURLWithPath: "/tmp/MacPad initial.txt")
        let fileDocument = EditorDocument(fileURL: fileURL)
        let untitledDocument = EditorDocument()

        #expect(fileDocument.fileURL == fileURL)
        #expect(
            fileDocument.fileReference
                == PersistedFileReference(path: fileURL.path, bookmarkData: nil)
        )
        #expect(untitledDocument.fileURL == nil)
        #expect(untitledDocument.fileReference == nil)
    }

    @Test("arbitrary bookmark bytes round-trip through JSON Base64")
    func roundTripsArbitraryBookmarkBytes() throws {
        let bookmarkData = Data([0x00, 0xFF, 0x80, 0x41, 0x0A, 0xC3, 0x28])
        let reference = PersistedFileReference(
            path: "/tmp/MacPad note.txt",
            bookmarkData: bookmarkData
        )

        let encoded = try JSONEncoder().encode(reference)
        let encodedFields = try JSONDecoder().decode(
            EncodedFileReferenceFields.self,
            from: encoded
        )
        let decoded = try JSONDecoder().decode(PersistedFileReference.self, from: encoded)

        #expect(encodedFields.bookmarkData == bookmarkData.base64EncodedString())
        #expect(decoded == reference)
    }

    @Test("invalid bookmark Base64 fails decoding")
    func rejectsInvalidBookmarkBase64() {
        let data = Data(
            #"{"path":"/tmp/note.txt","bookmarkData":"%%%"}"#.utf8
        )

        #expect(throws: DecodingError.self) {
            try JSONDecoder().decode(PersistedFileReference.self, from: data)
        }
    }

    @Test("attaching a reference stores the current resolved path in session state")
    func attachesReferenceToCurrentResolvedPath() throws {
        try withTemporaryDirectory { directory in
            let targetURL = directory.appendingPathComponent("target.txt")
            let linkURL = directory.appendingPathComponent("link.txt")
            let bookmarkData = Data([0x10, 0x20, 0x30])
            try Data("MacPad".utf8).write(to: targetURL)
            try FileManager.default.createSymbolicLink(
                at: linkURL,
                withDestinationURL: targetURL
            )
            let document = EditorDocument()
            try document.loadFile(linkURL)

            document.attachFileReference(
                PersistedFileReference(
                    path: "/stale/path.txt",
                    bookmarkData: bookmarkData
                )
            )

            let resolvedURL = targetURL.resolvingSymlinksInPath().standardizedFileURL
            let state = try #require(
                document.sessionState(
                    selectedLocation: 0,
                    wordWrapEnabled: true,
                    statusBarVisible: true,
                    zoomPercent: 100
                )
            )
            #expect(document.fileURL == resolvedURL)
            #expect(
                document.fileReference
                    == PersistedFileReference(
                        path: resolvedURL.path,
                        bookmarkData: bookmarkData
                    )
            )
            #expect(state.fileReference == document.fileReference)
        }
    }

    @Test("same-file reload and save preserve bookmark bytes")
    func sameFileLoadAndSavePreserveBookmark() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("note.txt")
            let bookmarkData = Data([0x00, 0xAA, 0xFF])
            try Data("original".utf8).write(to: fileURL)
            let document = EditorDocument()
            try document.loadFile(fileURL)
            document.attachFileReference(
                PersistedFileReference(path: "/ignored", bookmarkData: bookmarkData)
            )

            try document.loadFile(fileURL)
            #expect(document.fileReference?.bookmarkData == bookmarkData)

            document.updateText("updated")
            try document.save(to: fileURL)

            #expect(document.fileURL == fileURL.standardizedFileURL)
            #expect(document.fileReference?.path == fileURL.standardizedFileURL.path)
            #expect(document.fileReference?.bookmarkData == bookmarkData)
        }
    }

    @Test("loading a different file drops the old bookmark")
    func differentFileLoadDropsBookmark() throws {
        try withTemporaryDirectory { directory in
            let firstURL = directory.appendingPathComponent("first.txt")
            let secondURL = directory.appendingPathComponent("second.txt")
            try Data("first".utf8).write(to: firstURL)
            try Data("second".utf8).write(to: secondURL)
            let document = EditorDocument()
            try document.loadFile(firstURL)
            document.attachFileReference(
                PersistedFileReference(path: firstURL.path, bookmarkData: Data([0x99]))
            )

            try document.loadFile(secondURL)

            let resolvedSecondURL = secondURL.standardizedFileURL
            #expect(document.fileURL == resolvedSecondURL)
            #expect(
                document.fileReference
                    == PersistedFileReference(
                        path: resolvedSecondURL.path,
                        bookmarkData: nil
                    )
            )
        }
    }

    @Test("successful Save As changes the path and drops the old bookmark")
    func saveAsDropsOldBookmark() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("source.txt")
            let destinationURL = directory.appendingPathComponent("destination.txt")
            try Data("original".utf8).write(to: sourceURL)
            let document = EditorDocument()
            try document.loadFile(sourceURL)
            document.attachFileReference(
                PersistedFileReference(path: sourceURL.path, bookmarkData: Data([0xAB]))
            )
            document.updateText("saved elsewhere")

            try document.save(to: destinationURL)

            let resolvedDestination = destinationURL.standardizedFileURL
            #expect(document.fileURL == resolvedDestination)
            #expect(
                document.fileReference
                    == PersistedFileReference(
                        path: resolvedDestination.path,
                        bookmarkData: nil
                    )
            )
        }
    }

    @Test("failed Save As leaves the original URL and reference unchanged")
    func failedSaveAsPreservesOriginalReference() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("source.txt")
            let destinationDirectory = directory.appendingPathComponent(
                "destination",
                isDirectory: true
            )
            try Data("original".utf8).write(to: sourceURL)
            try FileManager.default.createDirectory(
                at: destinationDirectory,
                withIntermediateDirectories: false
            )
            let document = EditorDocument()
            try document.loadFile(sourceURL)
            document.attachFileReference(
                PersistedFileReference(path: sourceURL.path, bookmarkData: Data([0xBC]))
            )
            document.updateText("unsaved edit")
            let originalURL = document.fileURL
            let originalReference = document.fileReference

            #expect(throws: (any Error).self) {
                try document.save(to: destinationDirectory)
            }

            #expect(document.fileURL == originalURL)
            #expect(document.fileReference == originalReference)
        }
    }

    @Test("failed load leaves the original URL and reference unchanged")
    func failedLoadPreservesOriginalReference() throws {
        try withTemporaryDirectory { directory in
            let sourceURL = directory.appendingPathComponent("source.txt")
            let missingURL = directory.appendingPathComponent("missing.txt")
            try Data("original".utf8).write(to: sourceURL)
            let document = EditorDocument()
            try document.loadFile(sourceURL)
            document.attachFileReference(
                PersistedFileReference(path: sourceURL.path, bookmarkData: Data([0xCD]))
            )
            let originalURL = document.fileURL
            let originalReference = document.fileReference

            #expect(throws: (any Error).self) {
                try document.loadFile(missingURL)
            }

            #expect(document.fileURL == originalURL)
            #expect(document.fileReference == originalReference)
        }
    }

    @Test("failed same-file save leaves the URL and reference unchanged")
    func failedSameFileSavePreservesReference() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("note.txt")
            try Data("original".utf8).write(to: fileURL)
            let document = EditorDocument()
            try document.loadFile(fileURL)
            document.attachFileReference(
                PersistedFileReference(path: fileURL.path, bookmarkData: Data([0xDE]))
            )
            document.updateText("MacPad edit")
            let originalURL = document.fileURL
            let originalReference = document.fileReference
            try Data("external edit".utf8).write(to: fileURL)

            #expect(throws: EditorDocumentError.self) {
                try document.save(to: fileURL)
            }

            #expect(document.fileURL == originalURL)
            #expect(document.fileReference == originalReference)
        }
    }

    @Test("restore and reload preserve the session bookmark and ID")
    func restoreAndReloadPreserveBookmarkAndID() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("note.txt")
            let bookmarkData = Data([0xEF, 0x01, 0x02])
            try Data("restored".utf8).write(to: fileURL)
            let state = EditorSessionState(
                id: "restored-id",
                fileReference: PersistedFileReference(
                    path: fileURL.path,
                    bookmarkData: bookmarkData
                ),
                selectedLocation: 3,
                wordWrapEnabled: true,
                statusBarVisible: true,
                zoomPercent: 100,
                lineEnding: .windows
            )
            let document = EditorDocument()

            try document.restoreSessionStateAndReloadFile(state)

            let resolvedURL = fileURL.standardizedFileURL
            #expect(document.id == "restored-id")
            #expect(document.fileURL == resolvedURL)
            #expect(
                document.fileReference
                    == PersistedFileReference(
                        path: resolvedURL.path,
                        bookmarkData: bookmarkData
                    )
            )
        }
    }

    @Test("restore without reload derives the file URL from the session reference")
    func restoreWithoutReloadUsesReferencePath() {
        let reference = PersistedFileReference(
            path: "/tmp/MacPad restored.txt",
            bookmarkData: Data([0xFA])
        )
        let state = EditorSessionState(
            id: "restored-id",
            fileReference: reference,
            selectedLocation: 0,
            wordWrapEnabled: true,
            statusBarVisible: true,
            zoomPercent: 100,
            lineEnding: .windows
        )
        let document = EditorDocument(text: "discarded")

        document.restoreSessionState(state)

        #expect(document.fileURL == URL(fileURLWithPath: reference.path))
        #expect(document.fileReference == reference)
        #expect(document.text.isEmpty)
    }
}

private struct EncodedFileReferenceFields: Decodable {
    let bookmarkData: String?
}

private func withTemporaryDirectory<Result>(
    _ body: (URL) throws -> Result
) throws -> Result {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: false
    )
    defer {
        do {
            try FileManager.default.removeItem(at: directory)
        } catch {
            Issue.record(error)
        }
    }
    return try body(directory)
}
