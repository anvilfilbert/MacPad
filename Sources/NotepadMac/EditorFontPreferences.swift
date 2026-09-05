import AppKit
import NotepadMacCore

enum EditorFontPreferencesError: LocalizedError, MacPadLocalizedError {
    case unavailableFont(String)

    var errorDescription: String? {
        localizedErrorDescription(using: MacPadLocalization(bundle: .main))
    }

    func localizedErrorDescription(using localization: MacPadLocalization) -> String {
        switch self {
        case let .unavailableFont(fontName):
            return localization.savedFontUnavailable(fontName: fontName)
        }
    }
}

enum EditorFontPreferences {
    static let defaultsKey = "MacPad.EditorFont.v1"

    static func load(from defaults: UserDefaults) throws -> NSFont? {
        guard let data = defaults.data(forKey: defaultsKey) else { return nil }

        let preference = try JSONDecoder().decode(EditorFontPreference.self, from: data)
        guard let font = NSFont(
            name: preference.postScriptName,
            size: CGFloat(preference.pointSize)
        ) else {
            throw EditorFontPreferencesError.unavailableFont(preference.postScriptName)
        }
        return font
    }

    static func save(_ font: NSFont, to defaults: UserDefaults) throws {
        let preference = try EditorFontPreference(
            postScriptName: font.fontName,
            pointSize: Double(font.pointSize)
        )
        defaults.set(try JSONEncoder().encode(preference), forKey: defaultsKey)
    }
}
