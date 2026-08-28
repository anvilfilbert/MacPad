import Foundation
import Testing
@testable import NotepadMacCore

private enum CoordinationWaitError: Error {
    case timedOut(String)
}

private func waitForCoordinationSignal(
    _ semaphore: DispatchSemaphore,
    name: String
) throws {
    guard semaphore.wait(timeout: .now() + 15) == .success else {
        throw CoordinationWaitError.timedOut(name)
    }
}

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

    @Test("valid UTF-8 containing null bytes is rejected")
    func rejectsNullBytesInUTF8Data() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("null-bytes.dat")
        try Data([0x4D, 0x61, 0x63, 0x00, 0x50, 0x61, 0x64]).write(to: fileURL)

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

    @Test("UTF-16 little-endian input keeps its encoding when saved")
    func preservesUTF16LittleEndianEncoding() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("utf16-le.txt")
        let body = try #require("MacPad".data(using: .utf16LittleEndian))
        let originalData = Data([0xFF, 0xFE]) + body
        try originalData.write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        try document.save(to: fileURL)

        #expect(document.text == "MacPad")
        #expect(document.textEncoding == .utf16LittleEndian)
        #expect(try Data(contentsOf: fileURL) == originalData)
    }

    @Test("UTF-16 big-endian input keeps its encoding when saved")
    func preservesUTF16BigEndianEncoding() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("utf16-be.txt")
        let body = try #require("MacPad".data(using: .utf16BigEndian))
        let originalData = Data([0xFE, 0xFF]) + body
        try originalData.write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        try document.save(to: fileURL)

        #expect(document.text == "MacPad")
        #expect(document.textEncoding == .utf16BigEndian)
        #expect(try Data(contentsOf: fileURL) == originalData)
    }

    @Test("Windows-1252 punctuation is decoded and preserved")
    func preservesWindows1252Encoding() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("windows-1252.txt")
        let originalData = Data([0x93, 0x4D, 0x61, 0x63, 0x50, 0x61, 0x64, 0x94, 0x20, 0x80])
        try originalData.write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        try document.save(to: fileURL)

        #expect(document.text == "“MacPad” €")
        #expect(document.textEncoding == .windows1252)
        #expect(try Data(contentsOf: fileURL) == originalData)
    }

    @Test("Save As can convert legacy text to UTF-8")
    func convertsLegacyTextToUTF8() throws {
        let directory = try temporaryDirectory()
        let sourceURL = directory.appendingPathComponent("latin1.txt")
        let destinationURL = directory.appendingPathComponent("utf8.txt")
        try Data([0x63, 0x61, 0x66, 0xE9]).write(to: sourceURL)

        let document = EditorDocument()
        try document.loadFile(sourceURL)
        document.updateText("café 🚀")
        try document.save(to: destinationURL, encoding: .utf8)

        #expect(document.textEncoding == .utf8)
        #expect(try String(contentsOf: destinationURL, encoding: .utf8) == "café 🚀")
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

    @Test(
        "mixed line endings are preserved when saved",
        arguments: [
            "first\nsecond\r\nthird\n",
            "first\nsecond\rthird\n",
            "first\r\nsecond\rthird\r\n",
            "first\nsecond\r\nthird\rfourth\n"
        ]
    )
    func preservesMixedLineEndings(contents: String) throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("mixed.txt")
        let originalData = Data(contents.utf8)
        try originalData.write(to: fileURL)

        let document = EditorDocument()
        try document.loadFile(fileURL)
        try document.save(to: fileURL)

        #expect(document.lineEnding.statusLabel == "Mixed")
        #expect(try Data(contentsOf: fileURL) == originalData)
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

    @Test("oversized saves are rejected before replacing the destination")
    func rejectsOversizedSaveBeforeWriting() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("existing.txt")
        let originalData = Data("existing".utf8)
        try originalData.write(to: fileURL)
        let oversizedText = String(
            repeating: "x",
            count: Int(EditorDocument.maximumReadableFileBytes) + 1
        )
        let document = EditorDocument(text: oversizedText)

        #expect(throws: EditorDocumentError.self) {
            try document.save(to: fileURL)
        }
        #expect(try Data(contentsOf: fileURL) == originalData)
        #expect(document.fileURL == nil)
        #expect(document.hasUnsavedChanges)
    }

    @Test("a document at the save limit is accepted")
    func acceptsSaveAtLimit() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("limit.txt")
        let text = String(
            repeating: "x",
            count: Int(EditorDocument.maximumReadableFileBytes)
        )
        let document = EditorDocument(text: text)

        try document.save(to: fileURL)

        #expect(
            try Data(contentsOf: fileURL).count == Int(EditorDocument.maximumReadableFileBytes)
        )
        #expect(document.fileURL == fileURL.standardizedFileURL)
        #expect(!document.hasUnsavedChanges)
    }

    @Test("save waits for another coordinated writer")
    func waitsForCoordinatedWriter() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("coordinated.txt")
        try Data("original".utf8).write(to: fileURL)

        let holderAcquired = DispatchSemaphore(value: 0)
        let releaseHolder = DispatchSemaphore(value: 0)
        let holderFinished = DispatchSemaphore(value: 0)
        let holderQueue = OperationQueue()
        holderQueue.maxConcurrentOperationCount = 1
        holderQueue.qualityOfService = .userInitiated
        var holderFinishedObserved = false
        holderQueue.addOperation {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { _ in
                holderAcquired.signal()
                do {
                    try waitForCoordinationSignal(releaseHolder, name: "release holder")
                } catch {
                    Issue.record(error)
                }
            }
            #expect(coordinationError == nil)
            holderFinished.signal()
        }
        defer {
            releaseHolder.signal()
            if !holderFinishedObserved {
                do {
                    try waitForCoordinationSignal(holderFinished, name: "holder finished")
                } catch {
                    Issue.record(error)
                }
            }
        }
        try waitForCoordinationSignal(holderAcquired, name: "holder acquired")

        let saveFinished = DispatchSemaphore(value: 0)
        let saveQueue = OperationQueue()
        saveQueue.maxConcurrentOperationCount = 1
        saveQueue.qualityOfService = .userInitiated
        var saveFinishedObserved = false
        saveQueue.addOperation {
            do {
                let document = EditorDocument()
                try document.loadFile(fileURL)
                document.updateText("MacPad edit")
                try document.save(to: fileURL)
            } catch {
                Issue.record(error)
            }
            saveFinished.signal()
        }
        defer {
            releaseHolder.signal()
            if !saveFinishedObserved {
                do {
                    try waitForCoordinationSignal(saveFinished, name: "save finished")
                } catch {
                    Issue.record(error)
                }
            }
        }

        let earlySaveResult = saveFinished.wait(timeout: .now() + 0.2)
        #expect(earlySaveResult == .timedOut)
        releaseHolder.signal()
        try waitForCoordinationSignal(holderFinished, name: "holder finished")
        holderFinishedObserved = true
        if earlySaveResult == .timedOut {
            try waitForCoordinationSignal(saveFinished, name: "save finished")
        }
        saveFinishedObserved = true
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "MacPad edit")
    }

    @Test("a coordinated external edit wins the save race")
    func rejectsSaveAfterCoordinatedExternalEdit() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("coordinated-race.txt")
        try Data("original".utf8).write(to: fileURL)

        let documentLoaded = DispatchSemaphore(value: 0)
        let beginSave = DispatchSemaphore(value: 0)
        let saveFinished = DispatchSemaphore(value: 0)
        let saveQueue = OperationQueue()
        saveQueue.maxConcurrentOperationCount = 1
        saveQueue.qualityOfService = .userInitiated
        var saveFinishedObserved = false
        saveQueue.addOperation {
            do {
                let document = EditorDocument()
                try document.loadFile(fileURL)
                document.updateText("MacPad edit")
                documentLoaded.signal()
                do {
                    try waitForCoordinationSignal(beginSave, name: "begin save")
                } catch {
                    Issue.record(error)
                }
                do {
                    try document.save(to: fileURL)
                    Issue.record("Expected the coordinated external edit to reject the save.")
                } catch EditorDocumentError.fileChangedOnDisk {
                    // Expected stale-file rejection after the external writer releases its claim.
                } catch {
                    Issue.record(error)
                }
            } catch {
                Issue.record(error)
            }
            saveFinished.signal()
        }
        defer {
            beginSave.signal()
            if !saveFinishedObserved {
                do {
                    try waitForCoordinationSignal(saveFinished, name: "save finished")
                } catch {
                    Issue.record(error)
                }
            }
        }
        try waitForCoordinationSignal(documentLoaded, name: "document loaded")

        let holderAcquired = DispatchSemaphore(value: 0)
        let releaseHolder = DispatchSemaphore(value: 0)
        let holderFinished = DispatchSemaphore(value: 0)
        let holderQueue = OperationQueue()
        holderQueue.maxConcurrentOperationCount = 1
        holderQueue.qualityOfService = .userInitiated
        var holderFinishedObserved = false
        holderQueue.addOperation {
            let coordinator = NSFileCoordinator(filePresenter: nil)
            var coordinationError: NSError?
            coordinator.coordinate(writingItemAt: fileURL, options: [], error: &coordinationError) { coordinatedURL in
                do {
                    try Data("external edit".utf8).write(to: coordinatedURL, options: .atomic)
                } catch {
                    Issue.record(error)
                }
                holderAcquired.signal()
                do {
                    try waitForCoordinationSignal(releaseHolder, name: "release holder")
                } catch {
                    Issue.record(error)
                }
            }
            if let coordinationError {
                Issue.record(coordinationError)
            }
            holderFinished.signal()
        }
        defer {
            releaseHolder.signal()
            if !holderFinishedObserved {
                do {
                    try waitForCoordinationSignal(holderFinished, name: "holder finished")
                } catch {
                    Issue.record(error)
                }
            }
        }
        try waitForCoordinationSignal(holderAcquired, name: "holder acquired")

        beginSave.signal()
        let earlySaveResult = saveFinished.wait(timeout: .now() + 0.2)
        #expect(earlySaveResult == .timedOut)
        releaseHolder.signal()
        try waitForCoordinationSignal(holderFinished, name: "holder finished")
        holderFinishedObserved = true
        if earlySaveResult == .timedOut {
            try waitForCoordinationSignal(saveFinished, name: "save finished")
        }
        saveFinishedObserved = true
        #expect(try String(contentsOf: fileURL, encoding: .utf8) == "external edit")
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
