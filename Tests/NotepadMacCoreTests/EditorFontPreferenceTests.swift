import Foundation
import Testing
@testable import NotepadMacCore

@Suite("Editor font preference")
struct EditorFontPreferenceTests {
    @Test("font preference errors use the injected German bundle")
    func localizesFontPreferenceErrors() throws {
        try LocalizationFixture.with(
            languageCode: "de",
            strings: [
                MacPadStringKey.emptyFontName.rawValue:
                    "Der Name der Editorschrift darf nicht leer sein.",
                MacPadStringKey.invalidFontPointSize.rawValue:
                    "Die Größe der Editorschrift muss zwischen 6 und 72 Punkt liegen: %1$g."
            ]
        ) { localization in
            #expect(
                EditorFontPreferenceError.emptyPostScriptName
                    .localizedErrorDescription(using: localization)
                    == "Der Name der Editorschrift darf nicht leer sein."
            )
            #expect(
                EditorFontPreferenceError.invalidPointSize(73)
                    .localizedErrorDescription(using: localization)
                    == "Die Größe der Editorschrift muss zwischen 6 und 72 Punkt liegen: 73."
            )
        }
    }

    @Test("valid preferences round-trip through JSON")
    func roundTripsThroughJSON() throws {
        let preference = try EditorFontPreference(
            postScriptName: "Menlo-Regular",
            pointSize: 15
        )

        let data = try JSONEncoder().encode(preference)
        let decoded = try JSONDecoder().decode(EditorFontPreference.self, from: data)

        #expect(decoded == preference)
    }

    @Test("font name must contain visible characters")
    func rejectsEmptyFontName() {
        #expect(throws: (any Error).self) {
            try EditorFontPreference(postScriptName: "   ", pointSize: 14)
        }
    }

    @Test("font size must stay within the supported range", arguments: [5.9, 72.1, .infinity])
    func rejectsInvalidPointSize(pointSize: Double) {
        #expect(throws: (any Error).self) {
            try EditorFontPreference(postScriptName: "Menlo-Regular", pointSize: pointSize)
        }
    }

    @Test("invalid persisted preferences fail decoding")
    func rejectsInvalidPersistedPreference() {
        let data = Data(#"{"postScriptName":"","pointSize":14}"#.utf8)

        #expect(throws: (any Error).self) {
            try JSONDecoder().decode(EditorFontPreference.self, from: data)
        }
    }
}
