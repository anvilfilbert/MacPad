import Foundation

public struct CursorPosition: Equatable {
    public let line: Int
    public let column: Int

    public init(line: Int, column: Int) {
        self.line = line
        self.column = column
    }
}

public struct TextLineIndex: Equatable, Sendable {
    private let lineStarts: [Int]
    private let utf16Length: Int

    public init(text: String) {
        var starts = [0]
        var location = 0
        var previousCodeUnitWasCarriageReturn = false
        for codeUnit in text.utf16 {
            if previousCodeUnitWasCarriageReturn, codeUnit != 0x0A {
                starts.append(location)
            }
            location += 1
            if codeUnit == 0x0A {
                starts.append(location)
                previousCodeUnitWasCarriageReturn = false
            } else {
                previousCodeUnitWasCarriageReturn = codeUnit == 0x0D
            }
        }
        if previousCodeUnitWasCarriageReturn {
            starts.append(location)
        }
        lineStarts = starts
        utf16Length = location
    }

    public func cursorPosition(selectedLocation: Int) -> CursorPosition {
        let boundedLocation = max(0, min(selectedLocation, utf16Length))
        let lineIndex = indexOfLine(containing: boundedLocation)
        return CursorPosition(
            line: lineIndex + 1,
            column: boundedLocation - lineStarts[lineIndex] + 1
        )
    }

    public func location(ofLine lineNumber: Int) -> Int? {
        guard lineNumber > 0, lineNumber <= lineStarts.count else { return nil }
        return lineStarts[lineNumber - 1]
    }

    private func indexOfLine(containing location: Int) -> Int {
        var lowerBound = 0
        var upperBound = lineStarts.count

        while lowerBound < upperBound {
            let middle = lowerBound + (upperBound - lowerBound) / 2
            if lineStarts[middle] <= location {
                lowerBound = middle + 1
            } else {
                upperBound = middle
            }
        }

        return max(0, lowerBound - 1)
    }
}

public enum TextMetrics {
    public static func cursorPosition(in text: String, selectedLocation: Int) -> CursorPosition {
        TextLineIndex(text: text).cursorPosition(selectedLocation: selectedLocation)
    }

    public static func normalizedLineEndingsForEditing(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public static func location(ofLine lineNumber: Int, in text: String) -> Int? {
        TextLineIndex(text: text).location(ofLine: lineNumber)
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
        case .mixed:
            return text
        }
    }
}

public enum LineEnding: String, Codable, Equatable {
    case windows
    case unix
    case classicMac
    case mixed

    public var statusLabel: String {
        switch self {
        case .windows:
            return "Windows (CRLF)"
        case .unix:
            return "Unix (LF)"
        case .classicMac:
            return "Macintosh (CR)"
        case .mixed:
            return "Mixed"
        }
    }

    public static func detected(in text: String) -> LineEnding {
        var foundWindows = false
        var foundUnix = false
        var foundClassicMac = false
        var previousCodeUnitWasCarriageReturn = false

        for codeUnit in text.utf16 {
            switch codeUnit {
            case 0x0D:
                if previousCodeUnitWasCarriageReturn {
                    foundClassicMac = true
                }
                previousCodeUnitWasCarriageReturn = true
            case 0x0A:
                if previousCodeUnitWasCarriageReturn {
                    foundWindows = true
                } else {
                    foundUnix = true
                }
                previousCodeUnitWasCarriageReturn = false
            default:
                if previousCodeUnitWasCarriageReturn {
                    foundClassicMac = true
                    previousCodeUnitWasCarriageReturn = false
                }
            }
        }
        if previousCodeUnitWasCarriageReturn {
            foundClassicMac = true
        }

        let detectedCount = [foundWindows, foundUnix, foundClassicMac].count(where: { $0 })
        if detectedCount > 1 {
            return .mixed
        }
        if foundUnix {
            return .unix
        }
        if foundClassicMac {
            return .classicMac
        }
        return .windows
    }
}
