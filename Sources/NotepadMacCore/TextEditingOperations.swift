import Foundation

public enum TextEditingOperations {
    public static func selectionMatches(
        selectedText: String,
        searchTerm: String
    ) -> Bool {
        guard !searchTerm.isEmpty else { return false }
        return selectedText.caseInsensitiveCompare(searchTerm) == .orderedSame
    }
}
