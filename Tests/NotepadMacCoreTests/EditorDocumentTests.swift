import Foundation
import Testing
@testable import NotepadMacCore

@Suite("Editor document")
struct EditorDocumentTests {
    @Test("save refuses to overwrite an externally changed file")
    func rejectsExternalModification() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("note.txt")
        try Data("original".utf8).write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        document.updateText("MacPad edit")
        try Data("external edit".utf8).write(to: fileURL)

        #expect(throws: (any Error).self) {
            try document.save(to: fileURL)
        }
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "external edit")
    }

    @Test("save follows a symbolic link instead of replacing it")
    func preservesSymbolicLink() throws {
        let directory = try temporaryDirectory()
        let targetURL = directory.appendingPathComponent("target.txt")
        let linkURL = directory.appendingPathComponent("link.txt")
        try Data("original".utf8).write(to: targetURL)
        try FileManager.default.createSymbolicLink(
            at: linkURL,
            withDestinationURL: targetURL
        )

        let document = EditorDocument()
        try document.loadFile(linkURL)
        document.updateText("updated")
        try document.save(to: linkURL)

        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: linkURL.path) == targetURL.path)
        #expect(try String(contentsOf: targetURL, encoding: .utf8) == "updated")
    }

    @Test("binary-like control bytes are rejected")
    func rejectsBinaryLikeLatin1Data() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("not-text.dat")
        try Data([1, 2, 3, 255, 254, 253]).write(to: fileURL)

        let document = EditorDocument()

        #expect(throws: (any Error).self) {
            try document.loadFile(fileURL)
        }
    }

    @Test("Latin-1 input keeps its encoding when saved")
    func preservesLatin1Encoding() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("latin1.txt")
        let originalData = Data([0x63, 0x61, 0x66, 0xE9])
        try originalData.write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        try document.save(to: fileURL)

        #expect(try Data(contentsOf: fileURL) == originalData)
    }

    @Test("UTF-8 byte order mark is preserved when saved")
    func preservesUTF8ByteOrderMark() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("bom.txt")
        let originalData = Data([0xEF, 0xBB, 0xBF]) + Data("MacPad".utf8)
        try originalData.write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        document.updateText("Updated")
        try document.save(to: fileURL)

        #expect(try Data(contentsOf: fileURL).starts(with: [0xEF, 0xBB, 0xBF]))
        #expect(document.textEncoding == .utf8WithByteOrderMark)
    }

    @Test("an invalid UTF-8 byte order mark is rejected")
    func rejectsMalformedUTF8ByteOrderMark() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("invalid-bom.txt")
        try Data([0xEF, 0xBB, 0xBF, 0xFF]).write(to: fileURL)

        let document = EditorDocument()

        #expect(throws: (any Error).self) {
            try document.loadFile(fileURL)
        }
    }

    @Test("Windows line endings are preserved when saved")
    func preservesWindowsLineEndings() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("windows.txt")
        try Data("first\r\nsecond\r\n".utf8).write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        document.updateText("first\nchanged\n")
        try document.save(to: fileURL)

        #expect(try Data(contentsOf: fileURL) == Data("first\r\nchanged\r\n".utf8))
    }

    @Test("oversized files are rejected before decoding")
    func rejectsOversizedFile() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("large.txt")
        FileManager.default.createFile(atPath: fileURL.path, contents: nil)
        let handle = try FileHandle(forWritingTo: fileURL)
        try handle.truncate(atOffset: UInt64(EditorDocument.maximumReadableFileBytes + 1))
        try handle.close()

        let document = EditorDocument()

        #expect(throws: (any Error).self) {
            try document.loadFile(fileURL)
        }
    }

    @Test("directories are rejected as editor documents")
    func rejectsDirectory() throws {
        let directory = try temporaryDirectory()
        let document = EditorDocument()

        #expect(throws: (any Error).self) {
            try document.loadFile(directory)
        }
    }

    @Test("legacy text is not saved with lossy conversion")
    func rejectsLossyLegacySave() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("latin1.txt")
        let originalData = Data([0x63, 0x61, 0x66, 0xE9])
        try originalData.write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        document.updateText("cafe \u{1F680}")

        #expect(throws: (any Error).self) {
            try document.save(to: fileURL)
        }
        #expect(try Data(contentsOf: fileURL) == originalData)
    }

    private func temporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }
}
