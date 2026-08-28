import Foundation
import NotepadMacCore
import Testing
@testable import NotepadMac

@Suite("Security-scoped file access")
struct SecurityScopedFileAccessTests {
    @Test("direct access uses a canonical path-only reference")
    func directPathOnlyAccess() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("direct.txt")
            try Data("direct".utf8).write(to: fileURL)
            let access = SecurityScopedFileAccess(requiresBookmark: false)

            let reference = try access.makeReference(for: fileURL)
            let result = try access.access(reference) { resolvedURL in
                try String(contentsOf: resolvedURL, encoding: .utf8)
            }

            #expect(reference.bookmarkData == nil)
            #expect(reference.path == canonical(fileURL).path)
            #expect(result.value == "direct")
            #expect(result.refreshedReference == reference)
        }
    }

    @Test("Store access rejects a path-only reference with localized detail")
    func storeRejectsMissingBookmark() throws {
        let path = "/private/tmp/missing-bookmark.txt"
        let access = SecurityScopedFileAccess(requiresBookmark: true)
        let reference = PersistedFileReference(path: path, bookmarkData: nil)
        var operationCalled = false

        do {
            _ = try access.access(reference) { _ in
                operationCalled = true
            }
            Issue.record("Expected missing persistent access to throw.")
        } catch let error as SecurityScopedFileAccessError {
            #expect(error == .missingPersistentAccess(path: path))
            #expect(
                error.localizedErrorDescription(using: MacPadLocalization(bundle: .main))
                    == "MacPad no longer has persistent access to this file: \(path). Choose the file again to restore access."
            )
        }

        #expect(!operationCalled)
    }

    @Test("Store bookmarks support real read and write access")
    func bookmarkReadAndWrite() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("scoped.txt")
            try Data("before".utf8).write(to: fileURL)
            let access = SecurityScopedFileAccess(requiresBookmark: true)

            let reference = try access.makeReference(for: fileURL)
            let readResult = try access.access(reference) { resolvedURL in
                try String(contentsOf: resolvedURL, encoding: .utf8)
            }
            let writeResult = try access.access(readResult.refreshedReference) { resolvedURL in
                try Data("after".utf8).write(to: resolvedURL, options: .atomic)
                return "written"
            }

            #expect(reference.bookmarkData?.isEmpty == false)
            #expect(readResult.value == "before")
            #expect(writeResult.value == "written")
            #expect(try String(contentsOf: fileURL, encoding: .utf8) == "after")
        }
    }

    @Test("bookmark resolution tracks a moved file and refreshes stale data")
    func bookmarkTracksMove() throws {
        try withTemporaryDirectory { directory in
            let originalURL = directory.appendingPathComponent("original.txt")
            let movedURL = directory.appendingPathComponent("moved.txt")
            try Data("moved".utf8).write(to: originalURL)
            let access = SecurityScopedFileAccess(requiresBookmark: true)
            let reference = try access.makeReference(for: originalURL)
            try FileManager.default.moveItem(at: originalURL, to: movedURL)

            var wasStale = false
            let manuallyResolvedURL = try URL(
                resolvingBookmarkData: try #require(reference.bookmarkData),
                options: [.withSecurityScope, .withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &wasStale
            )
            let result = try access.access(reference) { resolvedURL in
                #expect(canonical(resolvedURL) == canonical(movedURL))
                return try String(contentsOf: resolvedURL, encoding: .utf8)
            }

            #expect(canonical(manuallyResolvedURL) == canonical(movedURL))
            #expect(result.value == "moved")
            #expect(result.refreshedReference.path == canonical(movedURL).path)
            if wasStale {
                var refreshedIsStale = false
                let refreshedURL = try URL(
                    resolvingBookmarkData: try #require(
                        result.refreshedReference.bookmarkData
                    ),
                    options: [.withSecurityScope, .withoutUI],
                    relativeTo: nil,
                    bookmarkDataIsStale: &refreshedIsStale
                )
                #expect(canonical(refreshedURL) == canonical(movedURL))
                #expect(!refreshedIsStale)
            }
        }
    }

    @Test("canonical identity treats var and private var as the same location")
    func canonicalVarIdentity() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("canonical.txt")
            try Data("canonical".utf8).write(to: fileURL)
            let canonicalURL = canonical(fileURL)
            let alternatePath = canonicalURL.path.replacingOccurrences(
                of: "/private/var/",
                with: "/var/"
            )
            let alternateURL = URL(fileURLWithPath: alternatePath)
            let access = SecurityScopedFileAccess(requiresBookmark: false)

            let reference = try access.makeReference(for: alternateURL)

            #expect(reference.path == canonicalURL.path)
        }
    }

    @Test("operation errors escape unchanged after scoped access begins")
    func operationErrorIsPreserved() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("error.txt")
            try Data().write(to: fileURL)
            let access = SecurityScopedFileAccess(requiresBookmark: true)
            let reference = try access.makeReference(for: fileURL)

            do {
                _ = try access.access(reference) { _ -> Void in
                    throw AccessProbeError.expected
                }
                Issue.record("Expected the operation error to escape.")
            } catch let error as AccessProbeError {
                #expect(error == .expected)
            }
        }
    }

    @Test("granted Save As writes before creating a bookmark")
    func grantedURLWritesBeforeBookmarkCreation() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("new.txt")
            let access = SecurityScopedFileAccess(requiresBookmark: true)
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))

            let result = try access.accessGrantedURL(fileURL) { grantedURL in
                try Data("created".utf8).write(to: grantedURL, options: .atomic)
                return 7
            }

            #expect(result.value == 7)
            #expect(result.refreshedReference.path == canonical(fileURL).path)
            #expect(result.refreshedReference.bookmarkData?.isEmpty == false)
            #expect(try String(contentsOf: fileURL, encoding: .utf8) == "created")
        }
    }

    @Test("granted operation errors escape without bookmark creation")
    func grantedOperationErrorIsPreserved() throws {
        try withTemporaryDirectory { directory in
            let fileURL = directory.appendingPathComponent("never-created.txt")
            let access = SecurityScopedFileAccess(requiresBookmark: true)

            do {
                _ = try access.accessGrantedURL(fileURL) { _ -> Void in
                    throw AccessProbeError.expected
                }
                Issue.record("Expected the granted operation error to escape.")
            } catch let error as AccessProbeError {
                #expect(error == .expected)
            }
            #expect(!FileManager.default.fileExists(atPath: fileURL.path))
        }
    }

    private func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }

    private func withTemporaryDirectory<Result>(
        _ body: (URL) throws -> Result
    ) throws -> Result {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("MacPadSecurityTests-\(UUID().uuidString)", isDirectory: true)
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

private enum AccessProbeError: Error, Equatable {
    case expected
}
