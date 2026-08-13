import Foundation

public enum EditorFontPreferenceError: LocalizedError, Equatable {
    case emptyPostScriptName
    case invalidPointSize(Double)

    public var errorDescription: String? {
        switch self {
        case .emptyPostScriptName:
            return "Editor font name must not be empty."
        case let .invalidPointSize(pointSize):
            return "Editor font size must be between 6 and 72 points: \(pointSize)."
        }
    }
}

public struct EditorFontPreference: Codable, Equatable, Sendable {
    public static let minimumPointSize = 6.0
    public static let maximumPointSize = 72.0

    public let postScriptName: String
    public let pointSize: Double

    public init(postScriptName: String, pointSize: Double) throws {
        let normalizedName = postScriptName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !normalizedName.isEmpty else {
            throw EditorFontPreferenceError.emptyPostScriptName
        }
        guard pointSize.isFinite,
              (Self.minimumPointSize...Self.maximumPointSize).contains(pointSize) else {
            throw EditorFontPreferenceError.invalidPointSize(pointSize)
        }

        self.postScriptName = normalizedName
        self.pointSize = pointSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        try self.init(
            postScriptName: container.decode(String.self, forKey: .postScriptName),
            pointSize: container.decode(Double.self, forKey: .pointSize)
        )
    }
}
