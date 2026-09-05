import Foundation
import NotepadMacCore

enum RecentDocumentStoreError: LocalizedError, MacPadLocalizedError, Equatable {
    case invalidRecentDocumentData

    var errorDescription: String? {
        localizedErrorDescription(using: MacPadLocalization(bundle: .main))
    }

    func localizedErrorDescription(using localization: MacPadLocalization) -> String {
        localization.string(.invalidRecentDocumentData)
    }
}

struct RecentDocumentStore {
    private struct StoredRecentDocuments: Codable {
        let references: [PersistedFileReference]
    }

    let defaults: UserDefaults
    let defaultsKey: String
    let maximumCount: Int

    init(defaults: UserDefaults, defaultsKey: String, maximumCount: Int) {
        precondition(maximumCount > 0, "Recent-document maximum count must be positive.")
        self.defaults = defaults
        self.defaultsKey = defaultsKey
        self.maximumCount = maximumCount
    }

    func references() throws -> [PersistedFileReference] {
        guard let storedValue = defaults.object(forKey: defaultsKey) else {
            return []
        }
        guard let data = storedValue as? Data else {
            throw RecentDocumentStoreError.invalidRecentDocumentData
        }

        do {
            let stored = try JSONDecoder().decode(StoredRecentDocuments.self, from: data)
            return Array(stored.references.prefix(maximumCount))
        } catch is DecodingError {
            throw RecentDocumentStoreError.invalidRecentDocumentData
        }
    }

    func add(_ reference: PersistedFileReference) throws {
        let current = try references()
        let normalizedReference = normalized(reference)
        let retained = current.filter {
            canonicalPath($0.path) != normalizedReference.path
        }
        try write([normalizedReference] + retained)
    }

    func replace(
        _ previousReference: PersistedFileReference?,
        with currentReference: PersistedFileReference
    ) throws {
        let current = try references()
        let normalizedCurrent = normalized(currentReference)
        let previousPath = previousReference.map { canonicalPath($0.path) }
        let retained = current.filter { reference in
            let path = canonicalPath(reference.path)
            return path != normalizedCurrent.path && path != previousPath
        }
        try write([normalizedCurrent] + retained)
    }

    func references(inNativeOrder nativeURLs: [URL]) throws -> [PersistedFileReference] {
        let stored = try references()
        let storedByPath = stored.reduce(
            into: [String: PersistedFileReference]()
        ) { result, reference in
            result[canonicalPath(reference.path)] = reference
        }
        var seenPaths = Set<String>()
        let joined = nativeURLs.compactMap { url -> PersistedFileReference? in
            let path = canonical(url).path
            guard seenPaths.insert(path).inserted else { return nil }
            return storedByPath[path]
        }
        return Array(joined.prefix(maximumCount))
    }

    func directReferences(
        inNativeOrder nativeURLs: [URL]
    ) throws -> [PersistedFileReference] {
        let stored = try references()
        let storedByPath = stored.reduce(
            into: [String: PersistedFileReference]()
        ) { result, reference in
            result[canonicalPath(reference.path)] = reference
        }
        var seenPaths = Set<String>()
        let joined = nativeURLs.compactMap { url -> PersistedFileReference? in
            let path = canonical(url).path
            guard seenPaths.insert(path).inserted else { return nil }
            return storedByPath[path]
                ?? PersistedFileReference(path: path, bookmarkData: nil)
        }
        return Array(joined.prefix(maximumCount))
    }

    func clear() {
        defaults.removeObject(forKey: defaultsKey)
    }

    private func write(_ references: [PersistedFileReference]) throws {
        let bounded = Array(references.prefix(maximumCount))
        let data = try JSONEncoder().encode(
            StoredRecentDocuments(references: bounded)
        )
        defaults.set(data, forKey: defaultsKey)
    }

    private func normalized(_ reference: PersistedFileReference) -> PersistedFileReference {
        PersistedFileReference(
            path: canonicalPath(reference.path),
            bookmarkData: reference.bookmarkData
        )
    }

    private func canonicalPath(_ path: String) -> String {
        canonical(URL(fileURLWithPath: path)).path
    }

    private func canonical(_ url: URL) -> URL {
        url.resolvingSymlinksInPath().standardizedFileURL
    }
}
