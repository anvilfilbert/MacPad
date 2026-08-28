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
        #expect(catalog.localizationValueViolations.isEmpty)
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
        #expect(catalog.localizationValueViolations.isEmpty)
        #expect(Set(catalog.strings.keys) == Set(["CFBundleTypeName"]))
        #expect(catalog.value(for: "CFBundleTypeName", locale: "en") == "Plain Text")
        #expect(catalog.value(for: "CFBundleTypeName", locale: "de") == "Klartext")
    }

    @Test("Current About and Find accessibility strings have dedicated keys")
    func currentSourceInventoryKeys() throws {
        let catalog = try loadCatalog(named: "Localizable.xcstrings")
        let expectedValues: [String: [String: String]] = [
            "about.publicRepository": [
                "en": "Public repo: %1$@",
                "de": "Öffentliches Repository: %1$@"
            ],
            "find.accessibility.what": [
                "en": "Find what",
                "de": "Suchtext"
            ],
            "find.accessibility.replaceWith": [
                "en": "Replace with",
                "de": "Ersatztext"
            ]
        ]

        for (key, localizations) in expectedValues {
            for (locale, value) in localizations {
                #expect(catalog.value(for: key, locale: locale) == value)
            }
        }
    }

    @Test("Catalog contract rejects non-translated string and plural units")
    func rejectsNonTranslatedUnits() {
        let stringLocalization = CatalogLocalization(
            stringUnit: CatalogStringUnit(state: "needs_review", value: "Text"),
            variations: nil
        )
        let pluralLocalization = CatalogLocalization(
            stringUnit: nil,
            variations: CatalogVariations(
                plural: [
                    "one": CatalogVariation(
                        stringUnit: CatalogStringUnit(state: "new", value: "%1$lld item")
                    ),
                    "other": CatalogVariation(
                        stringUnit: CatalogStringUnit(state: "translated", value: "%1$lld items")
                    )
                ]
            )
        )

        #expect(
            Set(stringLocalization.contractViolations(key: "fixture.string", locale: "de"))
                == Set([
                    .nonTranslatedState(
                        key: "fixture.string",
                        locale: "de",
                        variant: "string",
                        state: "needs_review"
                    )
                ])
        )
        #expect(
            Set(pluralLocalization.contractViolations(key: "fixture.plural", locale: "en"))
                == Set([
                    .nonTranslatedState(
                        key: "fixture.plural",
                        locale: "en",
                        variant: "one",
                        state: "new"
                    )
                ])
        )
    }

    @Test("Catalog contract rejects invalid localization value shapes")
    func rejectsInvalidLocalizationValueShapes() {
        let translatedUnit = CatalogStringUnit(state: "translated", value: "Text")
        let both = CatalogLocalization(
            stringUnit: translatedUnit,
            variations: CatalogVariations(
                plural: ["other": CatalogVariation(stringUnit: translatedUnit)]
            )
        )
        let neither = CatalogLocalization(stringUnit: nil, variations: nil)
        let emptyString = CatalogLocalization(
            stringUnit: CatalogStringUnit(state: "translated", value: " \n "),
            variations: nil
        )
        let emptyPlural = CatalogLocalization(
            stringUnit: nil,
            variations: CatalogVariations(plural: [:])
        )
        let missingOther = CatalogLocalization(
            stringUnit: nil,
            variations: CatalogVariations(
                plural: ["one": CatalogVariation(stringUnit: translatedUnit)]
            )
        )
        let emptyOther = CatalogLocalization(
            stringUnit: nil,
            variations: CatalogVariations(
                plural: [
                    "other": CatalogVariation(
                        stringUnit: CatalogStringUnit(state: "translated", value: "")
                    )
                ]
            )
        )

        #expect(
            Set(both.contractViolations(key: "fixture.both", locale: "en"))
                == Set([.invalidValueShape(key: "fixture.both", locale: "en")])
        )
        #expect(
            Set(neither.contractViolations(key: "fixture.neither", locale: "en"))
                == Set([.invalidValueShape(key: "fixture.neither", locale: "en")])
        )
        #expect(
            Set(emptyString.contractViolations(key: "fixture.empty", locale: "en"))
                == Set([.emptyValue(key: "fixture.empty", locale: "en", variant: "string")])
        )
        #expect(
            Set(emptyPlural.contractViolations(key: "fixture.emptyPlural", locale: "en"))
                == Set([
                    .emptyPlural(key: "fixture.emptyPlural", locale: "en"),
                    .missingPluralOther(key: "fixture.emptyPlural", locale: "en")
                ])
        )
        #expect(
            Set(missingOther.contractViolations(key: "fixture.missingOther", locale: "de"))
                == Set([.missingPluralOther(key: "fixture.missingOther", locale: "de")])
        )
        #expect(
            Set(emptyOther.contractViolations(key: "fixture.emptyOther", locale: "de"))
                == Set([
                    .emptyValue(key: "fixture.emptyOther", locale: "de", variant: "other")
                ])
        )
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
        #expect(
            localization.aboutPublicRepository(repository: "anvilfilbert/MacPad")
                == "Public repo: anvilfilbert/MacPad"
        )
        #expect(localization.string(.findWhatAccessibilityLabel) == "Find what")
        #expect(localization.string(.replaceWithAccessibilityLabel) == "Replace with")
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

    var localizationValueViolations: [CatalogContractViolation] {
        strings.flatMap { key, string in
            string.localizations.flatMap { locale, localization in
                localization.contractViolations(key: key, locale: locale)
            }
        }
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

    func contractViolations(
        key: String,
        locale: String
    ) -> [CatalogContractViolation] {
        switch (stringUnit, variations?.plural) {
        case let (.some(unit), .none):
            return unit.contractViolations(key: key, locale: locale, variant: "string")
        case let (.none, .some(plural)):
            var violations: [CatalogContractViolation] = []
            if plural.isEmpty {
                violations.append(.emptyPlural(key: key, locale: locale))
            }
            if plural["other"] == nil {
                violations.append(.missingPluralOther(key: key, locale: locale))
            }
            violations.append(
                contentsOf: plural.flatMap { category, variation in
                    variation.stringUnit.contractViolations(
                        key: key,
                        locale: locale,
                        variant: category
                    )
                }
            )
            return violations
        default:
            return [.invalidValueShape(key: key, locale: locale)]
        }
    }

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

    func contractViolations(
        key: String,
        locale: String,
        variant: String
    ) -> [CatalogContractViolation] {
        var violations: [CatalogContractViolation] = []
        if state != "translated" {
            violations.append(
                .nonTranslatedState(
                    key: key,
                    locale: locale,
                    variant: variant,
                    state: state
                )
            )
        }
        if value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            violations.append(.emptyValue(key: key, locale: locale, variant: variant))
        }
        return violations
    }
}

private struct CatalogVariations: Decodable {
    let plural: [String: CatalogVariation]
}

private struct CatalogVariation: Decodable {
    let stringUnit: CatalogStringUnit
}

private enum CatalogContractViolation: Hashable {
    case invalidValueShape(key: String, locale: String)
    case nonTranslatedState(key: String, locale: String, variant: String, state: String)
    case emptyValue(key: String, locale: String, variant: String)
    case emptyPlural(key: String, locale: String)
    case missingPluralOther(key: String, locale: String)
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
