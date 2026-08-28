import Foundation
import Testing

@testable import NotepadMacCore

struct LocalizationTests {
    @Test("Localizable catalog satisfies the English and German contract")
    func localizableCatalogContract() throws {
        let catalog = try loadCatalog(named: "Localizable.xcstrings")
        let placeholderMismatches = try catalog.placeholderMismatches()
        let expectedKeys = Set(MacPadStringKey.allCases.map(\.rawValue))

        #expect(catalog.sourceLanguage == "en")
        #expect(catalog.locales == Set(["en", "de"]))
        #expect(catalog.missingGermanKeys.isEmpty)
        #expect(placeholderMismatches.isEmpty)
        #expect(catalog.unexpectedPluralCategories.isEmpty)
        #expect(catalog.nonManualKeys.isEmpty)
        #expect(Set(catalog.strings.keys) == expectedKeys)
        for key in MacPadStringKey.allCases {
            #expect(catalog.value(for: key.rawValue, locale: "en") == key.englishValue)
        }
    }

    @Test("Info.plist catalog satisfies the English and German contract")
    func infoPlistCatalogContract() throws {
        let catalog = try loadCatalog(named: "InfoPlist.xcstrings")
        let placeholderMismatches = try catalog.placeholderMismatches()

        #expect(catalog.sourceLanguage == "en")
        #expect(catalog.locales == Set(["en", "de"]))
        #expect(catalog.missingGermanKeys.isEmpty)
        #expect(placeholderMismatches.isEmpty)
        #expect(catalog.unexpectedPluralCategories.isEmpty)
        #expect(catalog.nonManualKeys.isEmpty)
        #expect(Set(catalog.strings.keys) == Set(["CFBundleTypeName"]))
        #expect(catalog.value(for: "CFBundleTypeName", locale: "en") == "Plain Text")
        #expect(catalog.value(for: "CFBundleTypeName", locale: "de") == "Klartext")
    }

    @Test("German safety copy and invariant encoding labels are exact")
    func germanSafetyAndEncodingContract() throws {
        let catalog = try loadCatalog(named: "Localizable.xcstrings")
        let expectedSafetyValues: [MacPadStringKey: String] = [
            .save: "Sichern",
            .saveAs: "Sichern unter …",
            .dontSave: "Nicht sichern",
            .discardChanges: "Änderungen verwerfen",
            .replaceTitle: "Ersetzen",
            .reloadFromDisk: "Neu laden",
            .recover: "Wiederherstellen",
            .delete: "Löschen",
            .cancel: "Abbrechen",
            .externalChangeTitle: "Diese Datei wurde außerhalb von MacPad geändert.",
            .externalChangeGuidance: "In einer anderen Datei sichern, neu laden oder weiterbearbeiten."
        ]
        for (key, value) in expectedSafetyValues {
            #expect(catalog.value(for: key.rawValue, locale: "de") == value)
        }

        let invariantEncodingKeys: [MacPadStringKey] = [
            .utf8Encoding,
            .utf8BOMEncoding,
            .utf16LittleEndianEncoding,
            .utf16BigEndianEncoding,
            .windows1252Encoding,
            .iso88591Encoding
        ]
        for key in invariantEncodingKeys {
            #expect(catalog.value(for: key.rawValue, locale: "de") == key.englishValue)
        }
    }

    @Test("Typed localization formats dynamic English fallback strings")
    func typedFormattingFallback() {
        let localization = MacPadLocalization(bundle: .main)

        #expect(localization.windowTitle(documentName: "Notes.txt") == "Notes.txt - MacPad")
        #expect(
            localization.statusLine(
                line: 4,
                column: 9,
                zoom: 125,
                lineEnding: "Windows (CRLF)",
                encoding: "UTF-8"
            ) == "Ln 4, Col 9  |  125%  |  Windows (CRLF)  |  UTF-8"
        )
        #expect(
            localization.fileTooLarge(
                path: "/tmp/large.txt",
                sizeBytes: 101,
                maximumBytes: 100
            ) == "File is too large to open safely: /tmp/large.txt is 101 bytes, maximum is 100 bytes."
        )
        #expect(
            localization.unrepresentableText(
                encoding: "ISO-8859-1",
                path: "/tmp/note.txt"
            ) == "The document contains text that cannot be represented as ISO-8859-1: /tmp/note.txt."
        )
    }
}

private enum CatalogContractError: Error, CustomStringConvertible {
    case missingCatalog(String)
    case invalidPlaceholderCapture(String)

    var description: String {
        switch self {
        case let .missingCatalog(name):
            return "Required localization catalog is absent: \(name)"
        case let .invalidPlaceholderCapture(value):
            return "Could not read a placeholder conversion from: \(value)"
        }
    }
}

private struct Catalog: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogString]

    var locales: Set<String> {
        strings.values.reduce(into: Set<String>()) { locales, string in
            locales.formUnion(string.localizations.keys)
        }
    }

    var missingGermanKeys: [String] {
        strings.compactMap { key, string in
            guard let localization = string.localizations["de"],
                  localization.hasNonEmptyValues else {
                return key
            }
            return nil
        }
        .sorted()
    }

    func placeholderMismatches() throws -> [String] {
        try strings.flatMap { key, string in
            try string.placeholderMismatches(key: key)
        }
        .sorted()
    }

    var unexpectedPluralCategories: [String] {
        strings.compactMap { key, string in
            guard let english = string.localizations["en"],
                  let german = string.localizations["de"],
                  english.pluralCategories != german.pluralCategories else {
                return nil
            }
            return key
        }
        .sorted()
    }

    var nonManualKeys: [String] {
        strings.compactMap { key, string in
            string.extractionState == "manual" ? nil : key
        }
        .sorted()
    }

    func value(for key: String, locale: String) -> String? {
        strings[key]?.localizations[locale]?.stringUnit?.value
    }
}

private struct CatalogString: Decodable {
    let extractionState: String
    let localizations: [String: CatalogLocalization]

    func placeholderMismatches(key: String) throws -> [String] {
        guard let english = localizations["en"],
              let german = localizations["de"] else {
            return []
        }
        let categories = english.pluralCategories.union(german.pluralCategories)
        if categories.isEmpty {
            return try placeholderArguments(in: english.stringUnit?.value ?? "")
                == placeholderArguments(in: german.stringUnit?.value ?? "")
                ? []
                : [key]
        }
        return try categories.compactMap { category in
            let englishValue = english.variations?.plural[category]?.stringUnit.value ?? ""
            let germanValue = german.variations?.plural[category]?.stringUnit.value ?? ""
            return try placeholderArguments(in: englishValue) == placeholderArguments(in: germanValue)
                ? nil
                : "\(key)[\(category)]"
        }
    }
}

private struct CatalogLocalization: Decodable {
    let stringUnit: CatalogStringUnit?
    let variations: CatalogVariations?

    var hasNonEmptyValues: Bool {
        if let stringUnit {
            return !stringUnit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        guard let plural = variations?.plural, !plural.isEmpty else {
            return false
        }
        return plural.values.allSatisfy { variation in
            !variation.stringUnit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    var pluralCategories: Set<String> {
        guard let plural = variations?.plural else { return [] }
        return Set(plural.keys)
    }
}

private struct CatalogStringUnit: Decodable {
    let state: String
    let value: String
}

private struct CatalogVariations: Decodable {
    let plural: [String: CatalogVariation]
}

private struct CatalogVariation: Decodable {
    let stringUnit: CatalogStringUnit
}

private func loadCatalog(named name: String) throws -> Catalog {
    let catalogURL = packageRoot
        .appendingPathComponent("Resources", isDirectory: true)
        .appendingPathComponent(name, isDirectory: false)
    guard FileManager.default.fileExists(atPath: catalogURL.path) else {
        throw CatalogContractError.missingCatalog(name)
    }
    return try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: catalogURL))
}

private var packageRoot: URL {
    URL(fileURLWithPath: #filePath, isDirectory: false)
        .deletingLastPathComponent()
        .deletingLastPathComponent()
        .deletingLastPathComponent()
}

private struct FormatArgument: Equatable {
    let index: Int
    let type: String
}

private func placeholderArguments(in value: String) throws -> [FormatArgument] {
    let expression = try NSRegularExpression(
        pattern: #"%(?:(\d+)\$)?(?:[-+ #0']*)?(?:\d+)?(?:\.\d+)?(hh|h|ll|l|q|L|z|t|j)?([@diuoxXfFeEgGaAcCsSp])"#
    )
    let range = NSRange(value.startIndex..<value.endIndex, in: value)
    var implicitIndex = 1
    var arguments: [FormatArgument] = []
    for match in expression.matches(in: value, range: range) {
        let argumentIndex: Int
        if let indexRange = Range(match.range(at: 1), in: value),
           let explicitIndex = Int(value[indexRange]) {
            argumentIndex = explicitIndex
        } else {
            argumentIndex = implicitIndex
            implicitIndex += 1
        }
        let length = Range(match.range(at: 2), in: value).map { String(value[$0]) } ?? ""
        guard let conversionRange = Range(match.range(at: 3), in: value) else {
            throw CatalogContractError.invalidPlaceholderCapture(value)
        }
        arguments.append(
            FormatArgument(
                index: argumentIndex,
                type: length + String(value[conversionRange])
            )
        )
    }
    return arguments.sorted { first, second in
        if first.index == second.index {
            return first.type < second.type
        }
        return first.index < second.index
    }
}
