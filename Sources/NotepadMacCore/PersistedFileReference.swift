import Foundation

public struct PersistedFileReference: Codable, Equatable, Sendable {
    public let path: String
    public let bookmarkData: Data?

    public init(path: String, bookmarkData: Data?) {
        self.path = path
        self.bookmarkData = bookmarkData
    }
}
