import Foundation

private let supportedLocales: Set<String> = ["en", "de"]

private enum LocalizationValidationError: Error, CustomStringConvertible {
    case usage(String)
    case unsupportedSourceLanguage(path: String, language: String)
    case unsupportedLocales(key: String, locales: Set<String>)
    case missingLocalization(key: String, locale: String)
    case invalidExtractionState(key: String, state: String)
    case invalidState(key: String, locale: String, variant: String, state: String)
    case emptyLocalization(key: String, locale: String, variant: String)
    case invalidValueShape(key: String, locale: String)
    case missingPluralOther(key: String, locale: String)
    case pluralCategoryMismatch(key: String, english: Set<String>, german: Set<String>)
    case invalidFormat(key: String, locale: String, variant: String, detail: String)
    case placeholderMismatch(key: String, variant: String)
    case duplicateSemanticKey(String)
    case catalogKeyMismatch(missing: Set<String>, unexpected: Set<String>)
    case infoPlistKeyMismatch(Set<String>)

    var description: String {
        switch self {
        case let .usage(message):
            return message
        case let .unsupportedSourceLanguage(path, language):
            return "Unsupported source language '\(language)' in \(path); expected exactly 'en'."
        case let .unsupportedLocales(key, locales):
            return "Unsupported localization set for '\(key)': \(locales.sorted()); expected exactly [\"de\", \"en\"]."
        case let .missingLocalization(key, locale):
            return "Missing required '\(locale)' localization for '\(key)'."
        case let .invalidExtractionState(key, state):
            return "Catalog entry '\(key)' has extraction state '\(state)'; expected 'manual'."
        case let .invalidState(key, locale, variant, state):
            return "Localization '\(key)' [\(locale)/\(variant)] has state '\(state)'; expected 'translated' and never 'needs_review'."
        case let .emptyLocalization(key, locale, variant):
            return "Localization '\(key)' [\(locale)/\(variant)] is empty."
        case let .invalidValueShape(key, locale):
            return "Localization '\(key)' [\(locale)] must contain exactly one string unit or plural variation."
        case let .missingPluralOther(key, locale):
            return "Plural localization '\(key)' [\(locale)] is missing the required 'other' category."
        case let .pluralCategoryMismatch(key, english, german):
            return "Plural categories differ for '\(key)': en=\(english.sorted()), de=\(german.sorted())."
        case let .invalidFormat(key, locale, variant, detail):
            return "Invalid placeholder in '\(key)' [\(locale)/\(variant)]: \(detail)"
        case let .placeholderMismatch(key, variant):
            return "Placeholder type, count, or argument index differs for '\(key)' [\(variant)] between English and German."
        case let .duplicateSemanticKey(key):
            return "Duplicate semantic localization key in Localization.swift: \(key)."
        case let .catalogKeyMismatch(missing, unexpected):
            return "Localizable.xcstrings does not match MacPadStringKey; missing=\(missing.sorted()), unexpected=\(unexpected.sorted())."
        case let .infoPlistKeyMismatch(keys):
            return "InfoPlist.xcstrings must contain exactly CFBundleTypeName; found \(keys.sorted())."
        }
    }
}

private struct Catalog: Decodable {
    let sourceLanguage: String
    let strings: [String: CatalogString]
}

private struct CatalogString: Decodable {
    let extractionState: String
    let localizations: [String: CatalogLocalization]
}

private struct CatalogLocalization: Decodable {
    let stringUnit: CatalogStringUnit?
    let variations: CatalogVariations?
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

private struct FormatArgument: Equatable {
    let index: Int
    let type: String
}

private struct LocalizedValue {
    let variant: String
    let unit: CatalogStringUnit
}

private func decodeCatalog(at url: URL) throws -> Catalog {
    let data = try Data(contentsOf: url)
    return try JSONDecoder().decode(Catalog.self, from: data)
}

private func localizedValues(
    _ localization: CatalogLocalization,
    key: String,
    locale: String
) throws -> [LocalizedValue] {
    switch (localization.stringUnit, localization.variations) {
    case let (.some(unit), .none):
        return [LocalizedValue(variant: "string", unit: unit)]
    case let (.none, .some(variations)):
        guard variations.plural.keys.contains("other") else {
            throw LocalizationValidationError.missingPluralOther(key: key, locale: locale)
        }
        return variations.plural.map { category, variation in
            LocalizedValue(variant: category, unit: variation.stringUnit)
        }
    default:
        throw LocalizationValidationError.invalidValueShape(key: key, locale: locale)
    }
}

private func validateUnit(
    _ localizedValue: LocalizedValue,
    key: String,
    locale: String
) throws {
    guard localizedValue.unit.state == "translated" else {
        throw LocalizationValidationError.invalidState(
            key: key,
            locale: locale,
            variant: localizedValue.variant,
            state: localizedValue.unit.state
        )
    }
    guard !localizedValue.unit.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
        throw LocalizationValidationError.emptyLocalization(
            key: key,
            locale: locale,
            variant: localizedValue.variant
        )
    }
}

private func formatArguments(
    in value: String,
    key: String,
    locale: String,
    variant: String
) throws -> [FormatArgument] {
    let characters = Array(value)
    let conversions = Set("@diuoxXfFeEgGaAcCsSp")
    let flags = Set("-+ #0'")
    let lengths = ["hh", "ll", "h", "l", "q", "L", "z", "t", "j"]
    var arguments: [FormatArgument] = []
    var position = 0
    var implicitIndex = 1
    var sawExplicitIndex = false
    var sawImplicitIndex = false

    while position < characters.count {
        guard characters[position] == "%" else {
            position += 1
            continue
        }
        let placeholderStart = position
        position += 1
        guard position < characters.count else {
            throw LocalizationValidationError.invalidFormat(
                key: key,
                locale: locale,
                variant: variant,
                detail: "trailing percent sign"
            )
        }
        if characters[position] == "%" {
            position += 1
            continue
        }

        let possibleIndexStart = position
        while position < characters.count, characters[position].isNumber {
            position += 1
        }
        let explicitIndex: Int?
        if position < characters.count,
           characters[position] == "$",
           position > possibleIndexStart {
            let indexText = String(characters[possibleIndexStart..<position])
            guard let parsedIndex = Int(indexText), parsedIndex > 0 else {
                throw LocalizationValidationError.invalidFormat(
                    key: key,
                    locale: locale,
                    variant: variant,
                    detail: "invalid positional argument index"
                )
            }
            explicitIndex = parsedIndex
            sawExplicitIndex = true
            position += 1
        } else {
            explicitIndex = nil
            sawImplicitIndex = true
            position = possibleIndexStart
        }
        guard !(sawExplicitIndex && sawImplicitIndex) else {
            throw LocalizationValidationError.invalidFormat(
                key: key,
                locale: locale,
                variant: variant,
                detail: "mixed positional and non-positional arguments"
            )
        }

        while position < characters.count, flags.contains(characters[position]) {
            position += 1
        }
        if position < characters.count, characters[position] == "*" {
            throw LocalizationValidationError.invalidFormat(
                key: key,
                locale: locale,
                variant: variant,
                detail: "dynamic field widths are unsupported"
            )
        }
        while position < characters.count, characters[position].isNumber {
            position += 1
        }
        if position < characters.count, characters[position] == "." {
            position += 1
            if position < characters.count, characters[position] == "*" {
                throw LocalizationValidationError.invalidFormat(
                    key: key,
                    locale: locale,
                    variant: variant,
                    detail: "dynamic precision is unsupported"
                )
            }
            while position < characters.count, characters[position].isNumber {
                position += 1
            }
        }

        var length = ""
        for candidate in lengths {
            let candidateCharacters = Array(candidate)
            guard position + candidateCharacters.count <= characters.count else { continue }
            if Array(characters[position..<(position + candidateCharacters.count)]) == candidateCharacters {
                length = candidate
                position += candidateCharacters.count
                break
            }
        }
        guard position < characters.count, conversions.contains(characters[position]) else {
            let fragment = String(characters[placeholderStart..<min(characters.count, position + 1)])
            throw LocalizationValidationError.invalidFormat(
                key: key,
                locale: locale,
                variant: variant,
                detail: "unsupported conversion near '\(fragment)'"
            )
        }
        let conversion = characters[position]
        position += 1
        let argumentIndex = explicitIndex ?? implicitIndex
        if explicitIndex == nil {
            implicitIndex += 1
        }
        arguments.append(FormatArgument(index: argumentIndex, type: length + String(conversion)))
    }

    return arguments.sorted { first, second in
        if first.index == second.index {
            return first.type < second.type
        }
        return first.index < second.index
    }
}

private func validatePlaceholders(
    key: String,
    englishValues: [LocalizedValue],
    germanValues: [LocalizedValue]
) throws {
    let englishByVariant = Dictionary(uniqueKeysWithValues: englishValues.map { ($0.variant, $0.unit) })
    let germanByVariant = Dictionary(uniqueKeysWithValues: germanValues.map { ($0.variant, $0.unit) })
    let englishCategories = Set(englishByVariant.keys)
    let germanCategories = Set(germanByVariant.keys)
    guard englishCategories == germanCategories else {
        throw LocalizationValidationError.pluralCategoryMismatch(
            key: key,
            english: englishCategories,
            german: germanCategories
        )
    }
    for variant in englishCategories.sorted() {
        guard let englishUnit = englishByVariant[variant],
              let germanUnit = germanByVariant[variant] else {
            throw LocalizationValidationError.placeholderMismatch(key: key, variant: variant)
        }
        let englishArguments = try formatArguments(
            in: englishUnit.value,
            key: key,
            locale: "en",
            variant: variant
        )
        let germanArguments = try formatArguments(
            in: germanUnit.value,
            key: key,
            locale: "de",
            variant: variant
        )
        guard englishArguments == germanArguments else {
            throw LocalizationValidationError.placeholderMismatch(key: key, variant: variant)
        }
    }
}

private func validateCatalog(_ catalog: Catalog, path: String) throws {
    guard catalog.sourceLanguage == "en" else {
        throw LocalizationValidationError.unsupportedSourceLanguage(
            path: path,
            language: catalog.sourceLanguage
        )
    }
    let sortedStrings = catalog.strings.sorted { first, second in
        first.key < second.key
    }
    for (key, string) in sortedStrings {
        guard string.extractionState == "manual" else {
            throw LocalizationValidationError.invalidExtractionState(
                key: key,
                state: string.extractionState
            )
        }
        let locales = Set(string.localizations.keys)
        guard let english = string.localizations["en"] else {
            throw LocalizationValidationError.missingLocalization(key: key, locale: "en")
        }
        guard let german = string.localizations["de"] else {
            throw LocalizationValidationError.missingLocalization(key: key, locale: "de")
        }
        guard locales == supportedLocales else {
            throw LocalizationValidationError.unsupportedLocales(key: key, locales: locales)
        }
        let englishValues = try localizedValues(english, key: key, locale: "en")
        let germanValues = try localizedValues(german, key: key, locale: "de")
        for value in englishValues {
            try validateUnit(value, key: key, locale: "en")
        }
        for value in germanValues {
            try validateUnit(value, key: key, locale: "de")
        }
        try validatePlaceholders(
            key: key,
            englishValues: englishValues,
            germanValues: germanValues
        )
    }
}

private func semanticKeys(in sourceURL: URL) throws -> Set<String> {
    let source = try String(contentsOf: sourceURL, encoding: .utf8)
    let expression = try NSRegularExpression(
        pattern: #"case\s+[A-Za-z][A-Za-z0-9]*\s*=\s*\"([^\"]+)\""#
    )
    let range = NSRange(source.startIndex..<source.endIndex, in: source)
    var keys = Set<String>()
    for match in expression.matches(in: source, range: range) {
        guard let keyRange = Range(match.range(at: 1), in: source) else {
            throw LocalizationValidationError.usage(
                "Could not read a semantic localization key from \(sourceURL.path)."
            )
        }
        let key = String(source[keyRange])
        guard keys.insert(key).inserted else {
            throw LocalizationValidationError.duplicateSemanticKey(key)
        }
    }
    return keys
}

private func validateCatalogKeys(
    localizable: Catalog,
    infoPlist: Catalog,
    localizationSourceURL: URL
) throws {
    let expectedKeys = try semanticKeys(in: localizationSourceURL)
    let catalogKeys = Set(localizable.strings.keys)
    guard expectedKeys == catalogKeys else {
        throw LocalizationValidationError.catalogKeyMismatch(
            missing: expectedKeys.subtracting(catalogKeys),
            unexpected: catalogKeys.subtracting(expectedKeys)
        )
    }
    let infoPlistKeys = Set(infoPlist.strings.keys)
    guard infoPlistKeys == ["CFBundleTypeName"] else {
        throw LocalizationValidationError.infoPlistKeyMismatch(infoPlistKeys)
    }
}

private func runValidation(arguments: [String]) throws {
    guard arguments.count == 4 else {
        throw LocalizationValidationError.usage(
            "Usage: check-localizations.swift <Localizable.xcstrings> <InfoPlist.xcstrings> <Localization.swift>"
        )
    }
    let localizableURL = URL(fileURLWithPath: arguments[1], isDirectory: false)
    let infoPlistURL = URL(fileURLWithPath: arguments[2], isDirectory: false)
    let localizationSourceURL = URL(fileURLWithPath: arguments[3], isDirectory: false)
    let localizable = try decodeCatalog(at: localizableURL)
    let infoPlist = try decodeCatalog(at: infoPlistURL)
    try validateCatalog(localizable, path: localizableURL.path)
    try validateCatalog(infoPlist, path: infoPlistURL.path)
    try validateCatalogKeys(
        localizable: localizable,
        infoPlist: infoPlist,
        localizationSourceURL: localizationSourceURL
    )
    print(
        "Validated \(localizable.strings.count) Localizable keys and \(infoPlist.strings.count) InfoPlist key for en and de."
    )
}

try runValidation(arguments: CommandLine.arguments)
