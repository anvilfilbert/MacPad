import Foundation

public struct FindOptions: Equatable, Sendable {
    public let matchCase: Bool
    public let wrapAround: Bool

    public init(matchCase: Bool, wrapAround: Bool) {
        self.matchCase = matchCase
        self.wrapAround = wrapAround
    }
}

public enum TextEditingOperations {
    public static func selectionMatches(
        selectedText: String,
        searchTerm: String
    ) -> Bool {
        selectionMatches(
            selectedText: selectedText,
            searchTerm: searchTerm,
            matchCase: false
        )
    }

    public static func selectionMatches(
        selectedText: String,
        searchTerm: String,
        matchCase: Bool
    ) -> Bool {
        guard !searchTerm.isEmpty else { return false }
        if matchCase {
            return selectedText == searchTerm
        }
        return selectedText.caseInsensitiveCompare(searchTerm) == .orderedSame
    }

    public static func findRange(
        in text: String,
        searchTerm: String,
        selectedRange: NSRange,
        backwards: Bool,
        options: FindOptions
    ) -> NSRange? {
        guard !searchTerm.isEmpty else { return nil }

        let nsText = text as NSString
        let boundedLocation = max(0, min(selectedRange.location, nsText.length))
        let boundedLength = max(0, min(selectedRange.length, nsText.length - boundedLocation))
        let boundedSelection = NSRange(location: boundedLocation, length: boundedLength)
        var compareOptions: NSString.CompareOptions = [.literal]
        if backwards {
            compareOptions.insert(.backwards)
        }
        if !options.matchCase {
            compareOptions.insert(.caseInsensitive)
        }

        let primaryRange: NSRange
        if backwards {
            primaryRange = NSRange(location: 0, length: boundedSelection.location)
        } else {
            let start = boundedSelection.location + boundedSelection.length
            primaryRange = NSRange(location: start, length: nsText.length - start)
        }

        let primaryResult = nsText.range(
            of: searchTerm,
            options: compareOptions,
            range: primaryRange
        )
        if primaryResult.location != NSNotFound {
            return primaryResult
        }
        guard options.wrapAround else { return nil }

        let wrappedResult = nsText.range(
            of: searchTerm,
            options: compareOptions,
            range: NSRange(location: 0, length: nsText.length)
        )
        return wrappedResult.location == NSNotFound ? nil : wrappedResult
    }

    public static func replacingAll(
        in text: String,
        searchTerm: String,
        replacement: String,
        matchCase: Bool
    ) -> String {
        guard !searchTerm.isEmpty else { return text }
        var options: String.CompareOptions = [.literal]
        if !matchCase {
            options.insert(.caseInsensitive)
        }
        return text.replacingOccurrences(
            of: searchTerm,
            with: replacement,
            options: options,
            range: nil
        )
    }
}
