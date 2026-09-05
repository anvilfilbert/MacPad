public enum MacPadTechnicalTermKey: String, CaseIterable, Hashable, Sendable {
    case utf8 = "macpad.term.encoding.utf8"
    case utf8WithByteOrderMark = "macpad.term.encoding.utf8-bom"
    case utf16LittleEndian = "macpad.term.encoding.utf16-le"
    case utf16BigEndian = "macpad.term.encoding.utf16-be"
    case windows1252 = "macpad.term.encoding.windows-1252"
    case iso88591 = "macpad.term.encoding.iso-8859-1"
    case windowsLineEnding = "macpad.term.line-ending.windows-crlf"
    case unixLineEnding = "macpad.term.line-ending.unix-lf"
    case classicMacLineEnding = "macpad.term.line-ending.classic-mac-cr"
    case mixedLineEndings = "macpad.term.line-ending.mixed"

    public var englishValue: String {
        switch self {
        case .utf8: "UTF-8"
        case .utf8WithByteOrderMark: "UTF-8 BOM"
        case .utf16LittleEndian: "UTF-16 LE"
        case .utf16BigEndian: "UTF-16 BE"
        case .windows1252: "Windows-1252"
        case .iso88591: "ISO-8859-1"
        case .windowsLineEnding: "Windows (CRLF)"
        case .unixLineEnding: "Unix (LF)"
        case .classicMacLineEnding: "Macintosh (CR)"
        case .mixedLineEndings: "Mixed"
        }
    }
}
