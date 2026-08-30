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
    @Test("document display values and errors use the injected German bundle")
    func localizesDocumentValuesAndErrors() throws {
        try LocalizationFixture.with(
            languageCode: "de",
            strings: [
                MacPadStringKey.untitled.rawValue: "Ohne Titel",
                MacPadStringKey.fileTooLarge.rawValue:
                    "Die Datei ist zu groß, um sie sicher zu öffnen: %1$@ hat %2$lld Byte, maximal zulässig sind %3$lld Byte.",
                MacPadStringKey.documentTooLarge.rawValue:
                    "Das Dokument ist zu groß, um es sicher zu sichern: %1$@ hätte %2$lld Byte, maximal zulässig sind %3$lld Byte.",
                MacPadStringKey.regularFilesOnly.rawValue:
                    "Nur reguläre Dateien können sicher geöffnet werden: %1$@.",
                MacPadStringKey.fileChangedOnDisk.rawValue:
                    "Die Datei wurde nach dem Öffnen in MacPad auf dem Datenträger geändert: %1$@. Neu laden oder mit ‚Sichern unter‘ sichern, damit keine andere Änderung überschrieben wird.",
                MacPadStringKey.coordinatedWriteDenied.rawValue:
                    "macOS hat keinen koordinierten Schreibzugriff auf die Datei gewährt: %1$@.",
                MacPadStringKey.unsupportedTextEncoding.rawValue:
                    "Die Datei kann nicht als unterstützter Klartext gelesen werden: %1$@.",
                MacPadStringKey.unrepresentableText.rawValue:
                    "Das Dokument enthält Text, der nicht als %1$@ dargestellt werden kann: %2$@."
            ],
            technicalTerms: [
                "macpad.term.encoding.utf8": "Technischer Begriff UTF-8",
                "macpad.term.encoding.utf8-bom": "Technischer Begriff UTF-8 BOM",
                "macpad.term.encoding.utf16-le": "Technischer Begriff UTF-16 LE",
                "macpad.term.encoding.utf16-be": "Technischer Begriff UTF-16 BE",
                "macpad.term.encoding.windows-1252": "Technischer Begriff Windows-1252",
                "macpad.term.encoding.iso-8859-1": "Technischer Begriff ISO-8859-1"
            ]
        ) { localization in
            let document = EditorDocument()
            #expect(document.displayName(using: localization) == "Ohne Titel")
            #expect(
                TextFileEncoding.allCases.map { $0.statusLabel(using: localization) }
                    == [
                        "Technischer Begriff UTF-8",
                        "Technischer Begriff UTF-8 BOM",
                        "Technischer Begriff UTF-16 LE",
                        "Technischer Begriff UTF-16 BE",
                        "Technischer Begriff Windows-1252",
                        "Technischer Begriff ISO-8859-1"
                    ]
            )

            let cases: [(EditorDocumentError, String)] = [
                (
                    .fileTooLarge(path: "/tmp/note.txt", sizeBytes: 11, maximumBytes: 10),
                    "Die Datei ist zu groß, um sie sicher zu öffnen: /tmp/note.txt hat 11 Byte, maximal zulässig sind 10 Byte."
                ),
                (
                    .documentTooLargeToSave(
                        path: "/tmp/note.txt",
                        sizeBytes: 11,
                        maximumBytes: 10
                    ),
                    "Das Dokument ist zu groß, um es sicher zu sichern: /tmp/note.txt hätte 11 Byte, maximal zulässig sind 10 Byte."
                ),
                (
                    .fileIsNotRegular(path: "/tmp/folder"),
                    "Nur reguläre Dateien können sicher geöffnet werden: /tmp/folder."
                ),
                (
                    .fileChangedOnDisk(path: "/tmp/note.txt"),
                    "Die Datei wurde nach dem Öffnen in MacPad auf dem Datenträger geändert: /tmp/note.txt. Neu laden oder mit ‚Sichern unter‘ sichern, damit keine andere Änderung überschrieben wird."
                ),
                (
                    .fileCoordinationFailed(path: "/tmp/note.txt"),
                    "macOS hat keinen koordinierten Schreibzugriff auf die Datei gewährt: /tmp/note.txt."
                ),
                (
                    .unsupportedTextEncoding(path: "/tmp/note.txt"),
                    "Die Datei kann nicht als unterstützter Klartext gelesen werden: /tmp/note.txt."
                ),
                (
                    .textCannotBeSaved(path: "/tmp/note.txt", encoding: .windows1252),
                    "Das Dokument enthält Text, der nicht als Technischer Begriff Windows-1252 dargestellt werden kann: /tmp/note.txt."
                )
            ]

            for (error, expectedDescription) in cases {
                #expect(error.localizedErrorDescription(using: localization) == expectedDescription)
            }
        }
    }

    @Test("session limit decoding uses the injected German bundle")
    func localizesSessionLimitDecodingError() throws {
        try LocalizationFixture.with(
            languageCode: "de",
            strings: [
                MacPadStringKey.sessionWindowOrTabLimit.rawValue:
                    "Die Sitzung enthält mehr Fenster oder Tabs, als MacPad unterstützt."
            ]
        ) { localization in
            let windows = Array(
                repeating: #"{"tabs":[],"selectedTabIndex":0}"#,
                count: AppSessionState.maximumWindowCount + 1
            ).joined(separator: ",")
            let data = Data(#"{"windows":[\#(windows)]}"#.utf8)

            do {
                _ = try AppSessionState.decode(data: data, localization: localization)
                Issue.record("Expected an over-limit session to fail decoding.")
            } catch DecodingError.dataCorrupted(let context) {
                #expect(
                    context.debugDescription
                        == "Die Sitzung enthält mehr Fenster oder Tabs, als MacPad unterstützt."
                )
            } catch {
                Issue.record(error)
            }
        }
    }

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

    @Test("session reload preserves the saved line ending when disk content differs")
    func sessionReloadPreservesSavedLineEnding() throws {
        let directory = try temporaryDirectory()
        let fileURL = directory.appendingPathComponent("session-line-ending.txt")
        try Data("first\r\nsecond".utf8).write(to: fileURL)
        let state = EditorSessionState(
            id: "saved-session",
            fileReference: PersistedFileReference(path: fileURL.path, bookmarkData: Data([1])),
            selectedLocation: 0,
            wordWrapEnabled: true,
            statusBarVisible: true,
            zoomPercent: 100,
            lineEnding: .unix
        )
        let document = EditorDocument()

        try document.restoreSessionStateAndReloadFile(state)

        #expect(document.text == "first\r\nsecond")
        #expect(document.lineEnding == .unix)
        #expect(document.sessionState(
            selectedLocation: 0,
            wordWrapEnabled: true,
            statusBarVisible: true,
            zoomPercent: 100
        )?.lineEnding == .unix)
    }

    @Test("current-file save rejects a moved destination changed outside MacPad")
    func currentFileSaveRejectsMovedExternalChange() throws {
        let directory = try temporaryDirectory()
        let originalURL = directory.appendingPathComponent("current-original.txt")
        let movedURL = directory.appendingPathComponent("current-moved.txt")
        try Data("original".utf8).write(to: originalURL)
        let document = EditorDocument()
        try document.loadFile(originalURL)
        document.attachFileReference(
            PersistedFileReference(path: originalURL.path, bookmarkData: Data([0x41]))
        )
        let originalReference = document.fileReference
        let originalDocumentURL = document.fileURL
        document.updateText("MacPad edit")
        try FileManager.default.moveItem(at: originalURL, to: movedURL)
        try Data("external edit".utf8).write(to: movedURL)

        do {
            try document.saveCurrentFile(at: movedURL, encoding: .utf8)
            Issue.record("Expected the external edit to reject the moved-file save.")
        } catch EditorDocumentError.fileChangedOnDisk(let path) {
            #expect(path == movedURL.resolvingSymlinksInPath().standardizedFileURL.path)
        } catch {
            Issue.record(error)
        }

        #expect(try String(contentsOf: movedURL, encoding: .utf8) == "external edit")
        #expect(document.fileURL == originalDocumentURL)
        #expect(document.fileReference == originalReference)
        #expect(document.text == "MacPad edit")
        #expect(document.originalText == "original")
        #expect(document.hasUnsavedChanges)
    }

    @Test("successful current-file save adopts a bookmark-resolved moved location")
    func currentFileSaveAdoptsMovedLocationAfterSuccess() throws {
        let directory = try temporaryDirectory()
        let originalURL = directory.appendingPathComponent("success-original.txt")
        let movedURL = directory.appendingPathComponent("success-moved.txt")
        try Data("original".utf8).write(to: originalURL)
        let document = EditorDocument()
        try document.loadFile(originalURL)
        let bookmarkData = Data([0x42])
        document.attachFileReference(
            PersistedFileReference(path: originalURL.path, bookmarkData: bookmarkData)
        )
        document.updateText("MacPad edit")
        try FileManager.default.moveItem(at: originalURL, to: movedURL)

        try document.saveCurrentFile(at: movedURL, encoding: .utf8)

        let canonicalMovedURL = movedURL.resolvingSymlinksInPath().standardizedFileURL
        #expect(try String(contentsOf: movedURL, encoding: .utf8) == "MacPad edit")
        #expect(document.fileURL == canonicalMovedURL)
        #expect(document.fileReference?.path == canonicalMovedURL.path)
        #expect(document.fileReference?.bookmarkData == bookmarkData)
        #expect(document.originalText == "MacPad edit")
        #expect(!document.hasUnsavedChanges)
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

enum LocalizationFixture {
    static func with<Result>(
        languageCode: String,
        strings: [String: String],
        body: (MacPadLocalization) throws -> Result
    ) throws -> Result {
        try with(
            languageCode: languageCode,
            tables: ["Localizable": strings],
            body: body
        )
    }

    static func with<Result>(
        languageCode: String,
        strings: [String: String],
        technicalTerms: [String: String],
        body: (MacPadLocalization) throws -> Result
    ) throws -> Result {
        try with(
            languageCode: languageCode,
            tables: ["Localizable": strings, "TechnicalTerms": technicalTerms],
            body: body
        )
    }

    private static func with<Result>(
        languageCode: String,
        tables: [String: [String: String]],
        body: (MacPadLocalization) throws -> Result
    ) throws -> Result {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
            .appendingPathComponent("MacPadLocalization.bundle", isDirectory: true)
        defer {
            do {
                try FileManager.default.removeItem(at: root)
            } catch {
                Issue.record(error)
            }
        }

        let contents = root.appendingPathComponent("Contents", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let localizationDirectory = resources.appendingPathComponent(
            "\(languageCode).lproj",
            isDirectory: true
        )
        try FileManager.default.createDirectory(
            at: localizationDirectory,
            withIntermediateDirectories: true
        )

        let info = CoreLocalizationBundleInfo(
            developmentRegion: languageCode,
            identifier: "local.macpad.tests.core-localization.\(UUID().uuidString)",
            localizations: [languageCode],
            packageType: "BNDL"
        )
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .xml
        try encoder.encode(info).write(
            to: contents.appendingPathComponent("Info.plist"),
            options: .atomic
        )
        for (table, strings) in tables {
            try encoder.encode(strings).write(
                to: localizationDirectory.appendingPathComponent("\(table).strings"),
                options: .atomic
            )
        }

        let bundle = try #require(Bundle(path: root.path))
        return try body(MacPadLocalization(bundle: bundle))
    }
}

private struct CoreLocalizationBundleInfo: Encodable {
    let developmentRegion: String
    let identifier: String
    let localizations: [String]
    let packageType: String

    private enum CodingKeys: String, CodingKey {
        case developmentRegion = "CFBundleDevelopmentRegion"
        case identifier = "CFBundleIdentifier"
        case localizations = "CFBundleLocalizations"
        case packageType = "CFBundlePackageType"
    }
}
