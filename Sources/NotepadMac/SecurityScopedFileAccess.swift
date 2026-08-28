import Foundation
import NotepadMacCore

struct ResolvedFileAccess<Value> {
    let value: Value
    let refreshedReference: PersistedFileReference
}

enum SecurityScopedFileAccessError: LocalizedError, MacPadLocalizedError, Equatable {
    case missingPersistentAccess(path: String)
    case securityScopedAccessDenied(path: String)

    var errorDescription: String? {
        localizedErrorDescription(using: MacPadLocalization(bundle: .main))
    }

    func localizedErrorDescription(using localization: MacPadLocalization) -> String {
        switch self {
        case let .missingPersistentAccess(path):
            return localization.missingPersistentAccess(path: path)
        case let .securityScopedAccessDenied(path):
            return localization.securityScopedAccessDenied(path: path)
        }
    }
}

struct SecurityScopedFileAccess {
    let requiresBookmark: Bool

    func makeReference(for url: URL) throws -> PersistedFileReference {
        let canonicalURL = canonical(url)
        guard requiresBookmark else {
            return PersistedFileReference(path: canonicalURL.path, bookmarkData: nil)
        }

        let bookmarkData = try canonicalURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )
        guard !bookmarkData.isEmpty else {
            throw SecurityScopedFileAccessError.missingPersistentAccess(
                path: canonicalURL.path
            )
        }
        return PersistedFileReference(
            path: canonicalURL.path,
            bookmarkData: bookmarkData
        )
    }

    func access<Value>(
        _ reference: PersistedFileReference,
        operation: (URL) throws -> Value
    ) throws -> ResolvedFileAccess<Value> {
        guard requiresBookmark else {
            let canonicalURL = canonical(URL(fileURLWithPath: reference.path))
            let value = try operation(canonicalURL)
            return ResolvedFileAccess(
                value: value,
                refreshedReference: PersistedFileReference(
                    path: canonicalURL.path,
                    bookmarkData: nil
                )
            )
        }

        guard let bookmarkData = reference.bookmarkData, !bookmarkData.isEmpty else {
            throw SecurityScopedFileAccessError.missingPersistentAccess(path: reference.path)
        }

        var isStale = false
        let grantedURL = try URL(
            resolvingBookmarkData: bookmarkData,
            options: [.withSecurityScope, .withoutUI],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        guard grantedURL.startAccessingSecurityScopedResource() else {
            let deniedPath = grantedURL.path.isEmpty ? reference.path : grantedURL.path
            throw SecurityScopedFileAccessError.securityScopedAccessDenied(
                path: deniedPath
            )
        }
        defer {
            grantedURL.stopAccessingSecurityScopedResource()
        }

        let canonicalURL = canonical(grantedURL)
        let refreshedBookmarkData: Data
        if isStale {
            refreshedBookmarkData = try grantedURL.bookmarkData(
                options: .withSecurityScope,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            )
        } else {
            refreshedBookmarkData = bookmarkData
        }
        let refreshedReference = PersistedFileReference(
            path: canonicalURL.path,
            bookmarkData: refreshedBookmarkData
        )
        let value = try operation(canonicalURL)
        return ResolvedFileAccess(
            value: value,
            refreshedReference: refreshedReference
        )
    }

    func accessGrantedURL<Value>(
        _ url: URL,
        operation: (URL) throws -> Value
    ) throws -> ResolvedFileAccess<Value> {
        let canonicalURL = canonical(url)
        let value = try operation(canonicalURL)
        let reference = try makeReference(for: canonicalURL)
        return ResolvedFileAccess(value: value, refreshedReference: reference)
    }

    private func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
