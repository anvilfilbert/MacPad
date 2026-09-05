import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@Suite("Recent document store")
struct RecentDocumentStoreTests {
    @Test("absent data represents no recent documents")
    func absentData() throws {
        try withStore { store, _ in
            let references = try store.references()
            #expect(references.isEmpty)
        }
    }

    @Test("adding documents keeps most-recent-first order")
    func orderedAdd() throws {
        try withStore { store, _ in
            let first = reference("/private/tmp/first.txt", bookmark: [1])
            let second = reference("/private/tmp/second.txt", bookmark: [2])

            try store.add(first)
            try store.add(second)

            let stored = try store.references()
            #expect(stored == [second, first])
        }
    }

    @Test("canonical deduplication replaces the previous bookmark")
    func canonicalDeduplicationAndBookmarkReplacement() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("canonical.txt")
            try Data().write(to: fileURL)
            let canonicalPath = fileURL.resolvingSymlinksInPath().standardizedFileURL.path
            let alternatePath = canonicalPath.replacingOccurrences(
                of: "/private/var/",
                with: "/var/"
            )
            try withStore { store, _ in
                let oldReference = reference(alternatePath, bookmark: [1])
                let replacement = reference(canonicalPath, bookmark: [2])

                try store.add(oldReference)
                try store.add(replacement)

                let stored = try store.references()
                #expect(stored.count == 1)
                #expect(stored[0].path == canonicalPath)
                #expect(stored[0].bookmarkData == Data([2]))
            }
        }
    }

    @Test("Save As atomically replaces the old file with the new file")
    func saveAsReplacement() throws {
        try withStore { store, _ in
            let oldReference = reference("/private/tmp/old.txt", bookmark: [1])
            let retained = reference("/private/tmp/retained.txt", bookmark: [2])
            let newReference = reference("/private/tmp/new.txt", bookmark: [3])
            try store.add(retained)
            try store.add(oldReference)

            try store.replace(oldReference, with: newReference)

            let stored = try store.references()
            #expect(stored == [newReference, retained])
        }
    }

    @Test("clear removes valid and corrupt recent data")
    func clear() throws {
        try withStore { store, defaults in
            try store.add(reference("/private/tmp/first.txt", bookmark: [1]))
            store.clear()
            let references = try store.references()
            #expect(references.isEmpty)

            defaults.set("corrupt", forKey: testDefaultsKey)
            store.clear()
            #expect(defaults.object(forKey: testDefaultsKey) == nil)
        }
    }

    @Test("present non-Data values fail closed")
    func nonDataCorruption() throws {
        try withStore { store, defaults in
            defaults.set("not data", forKey: testDefaultsKey)

            do {
                _ = try store.references()
                Issue.record("Expected non-Data corruption to throw.")
            } catch let error as RecentDocumentStoreError {
                #expect(error == .invalidRecentDocumentData)
                #expect(
                    error.localizedErrorDescription(using: MacPadLocalization(bundle: .main))
                        == "Saved recent-document access data is invalid. Clear the Open Recent menu to remove it."
                )
            }
            #expect(defaults.string(forKey: testDefaultsKey) == "not data")
        }
    }

    @Test("malformed JSON is preserved and blocks mutation")
    func malformedJSONDoesNotMutate() throws {
        try withStore { store, defaults in
            let malformed = Data("{not-json".utf8)
            defaults.set(malformed, forKey: testDefaultsKey)

            #expect(throws: RecentDocumentStoreError.self) {
                _ = try store.references()
            }
            #expect(throws: RecentDocumentStoreError.self) {
                try store.add(reference("/private/tmp/new.txt", bookmark: [1]))
            }
            #expect(defaults.data(forKey: testDefaultsKey) == malformed)
        }
    }

    @Test("stored bookmarks follow native recent-document order")
    func nativeOrderJoin() throws {
        try withStore { store, _ in
            let first = reference("/private/tmp/first.txt", bookmark: [1])
            let second = reference("/private/tmp/second.txt", bookmark: [2])
            try store.add(first)
            try store.add(second)

            let joined = try store.references(
                inNativeOrder: [
                    URL(fileURLWithPath: first.path),
                    URL(fileURLWithPath: "/private/tmp/missing.txt"),
                    URL(fileURLWithPath: second.path)
                ]
            )

            #expect(joined == [first, second])
        }
    }

    @Test("direct native join synthesizes missing path-only entries")
    func directNativeOrderJoin() throws {
        try withStore { store, _ in
            let stored = reference("/private/tmp/stored.txt", bookmark: [1])
            let missingURL = URL(fileURLWithPath: "/private/tmp/missing.txt")
            try store.add(stored)

            let joined = try store.directReferences(
                inNativeOrder: [missingURL, URL(fileURLWithPath: stored.path)]
            )

            #expect(
                joined == [
                    PersistedFileReference(
                        path: missingURL.resolvingSymlinksInPath().standardizedFileURL.path,
                        bookmarkData: nil
                    ),
                    stored
                ]
            )
        }
    }

    @Test("recent documents are strictly truncated to twenty")
    func strictMaximumCount() throws {
        try withStore { store, _ in
            for index in 0..<25 {
                try store.add(
                    reference("/private/tmp/\(index).txt", bookmark: [UInt8(index)])
                )
            }

            let stored = try store.references()
            #expect(stored.count == 20)
            #expect(stored.first?.path == "/private/tmp/24.txt")
            #expect(stored.last?.path == "/private/tmp/5.txt")
        }
    }

    private var testDefaultsKey: String {
        "MacPadTests.RecentDocuments"
    }

    private func reference(_ path: String, bookmark: [UInt8]) -> PersistedFileReference {
        PersistedFileReference(path: path, bookmarkData: Data(bookmark))
    }

    private func withStore<Result>(
        _ body: (RecentDocumentStore, UserDefaults) throws -> Result
    ) throws -> Result {
        let suiteName = "MacPadRecentDocumentTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }
        let store = RecentDocumentStore(
            defaults: defaults,
            defaultsKey: testDefaultsKey,
            maximumCount: 20
        )
        return try body(store, defaults)
    }

    private func withTemporaryDirectory<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacPadRecentTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
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
}
