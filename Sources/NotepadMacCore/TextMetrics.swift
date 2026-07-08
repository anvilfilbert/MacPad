import Foundation

public struct CursorPosition: Equatable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public enum TextMetrics {
    public static func cursorPosition(in text: String, selectedLocation: Int) -> CursorPosition {
        let boundedLocation = max(0, min(selectedLocation, (text as NSString).length))
        let prefix = (text as NSString).substring(to: boundedLocation)
        var line = 1
        var column = 1

        for scalar in prefix.unicodeScalars {
            if scalar == "\n" {
                line += 1
                column = 1
            } else {
                column += 1
            }
        }

        return CursorPosition(line: line, column: column)
    }

    public static func normalizedLineEndingsForEditing(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public static func textForSave(_ text: String, lineEnding: LineEnding) -> String {
        let normalized = normalizedLineEndingsForEditing(text)
        switch lineEnding {
        case .windows:
            return normalized.replacingOccurrences(of: "\n", with: "\r\n")
        case .unix:
            return normalized
        case .classicMac:
            return normalized.replacingOccurrences(of: "\n", with: "\r")
        }
    }
}

public enum LineEnding: String, Codable, Equatable {
    case windows
    case unix
    case classicMac

    public var statusLabel: String {
        switch self {
        case .windows:
            return "Windows (CRLF)"
        case .unix:
            return "Unix (LF)"
        case .classicMac:
            return "Macintosh (CR)"
        }
    }

    public static func detected(in text: String) -> LineEnding {
        if text.contains("\r\n") {
            return .windows
        }
        if text.contains("\n") {
            return .unix
        }
        if text.contains("\r") {
            return .classicMac
        }
        return .windows
    }
}
