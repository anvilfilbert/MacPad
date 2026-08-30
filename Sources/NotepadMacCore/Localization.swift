import Foundation

public enum MacPadStringKey: String, CaseIterable, Hashable, Sendable {
    case mainMenu = "menu.main"
    case aboutMacPad = "app.about"
    case services = "app.services"
    case hideMacPad = "app.hide"
    case hideOthers = "app.hideOthers"
    case showAll = "app.showAll"
    case quitMacPad = "app.quit"
    case fileMenu = "menu.file"
    case newTab = "file.newTab"
    case newWindow = "file.newWindow"
    case open = "file.open"
    case openRecent = "file.openRecent"
    case noRecentDocuments = "file.noRecentDocuments"
    case clearRecentMenu = "file.clearRecentMenu"
    case recentDocumentsUnavailable = "file.recentDocumentsUnavailable"
    case close = "file.close"
    case save = "file.save"
    case saveAs = "file.saveAs"
    case clearSessionData = "file.clearSessionData"
    case print = "file.print"
    case editMenu = "menu.edit"
    case undo = "edit.undo"
    case redo = "edit.redo"
    case cut = "edit.cut"
    case copy = "edit.copy"
    case paste = "edit.paste"
    case delete = "edit.delete"
    case find = "edit.find"
    case findNext = "edit.findNext"
    case findPrevious = "edit.findPrevious"
    case replace = "edit.replace"
    case goTo = "edit.goTo"
    case selectAll = "edit.selectAll"
    case timeDate = "edit.timeDate"
    case formatMenu = "menu.format"
    case wordWrap = "format.wordWrap"
    case font = "format.font"
    case viewMenu = "menu.view"
    case zoomIn = "view.zoomIn"
    case zoomOut = "view.zoomOut"
    case restoreDefaultZoom = "view.restoreDefaultZoom"
    case statusBar = "view.statusBar"
    case showInMenuBar = "view.showInMenuBar"
    case windowMenu = "menu.window"
    case minimize = "window.minimize"
    case zoom = "window.zoom"
    case showPreviousTab = "window.showPreviousTab"
    case showNextTab = "window.showNextTab"
    case bringAllToFront = "window.bringAllToFront"
    case helpMenu = "menu.help"
    case macPadHelp = "help.macPadHelp"
    case reportIssue = "help.reportIssue"
    case privacy = "help.privacy"
    case security = "help.security"
    case checkForUpdates = "help.checkForUpdates"
    case findTitle = "find.title"
    case replaceTitle = "replace.title"
    case findWhat = "find.what"
    case replaceWith = "find.replaceWith"
    case findWhatAccessibilityLabel = "find.accessibility.what"
    case replaceWithAccessibilityLabel = "find.accessibility.replaceWith"
    case replaceAll = "find.replaceAll"
    case matchCase = "find.matchCase"
    case wrapAround = "find.wrapAround"
    case goToLineTitle = "goTo.title"
    case lineNumberLabel = "goTo.lineNumberLabel"
    case lineNumber = "goTo.lineNumber"
    case goToLine = "goTo.action"
    case cancel = "action.cancel"
    case dontSave = "action.dontSave"
    case discardChanges = "action.discardChanges"
    case recover = "action.recover"
    case reloadFromDisk = "action.reloadFromDisk"
    case locate = "action.locate"
    case skip = "action.skip"
    case cancelRestore = "action.cancelRestore"
    case untitled = "editor.untitled"
    case untitledFileName = "editor.untitledFileName"
    case windowTitle = "editor.windowTitle"
    case documentText = "editor.documentText"
    case documentStatus = "editor.documentStatus"
    case statusLine = "editor.statusLine"
    case encodingLabel = "save.encodingLabel"
    case textEncoding = "save.textEncoding"
    case saveFailure = "save.failure"
    case invalidTextEncoding = "save.invalidTextEncoding"
    case fontUseFailure = "font.useFailure"
    case unsavedChangesQuestion = "document.unsavedChangesQuestion"
    case unsavedChangesWarning = "document.unsavedChangesWarning"
    case externalChangeTitle = "conflict.externalChangeTitle"
    case externalChangeGuidance = "conflict.externalChangeGuidance"
    case reloadFailure = "reload.failure"
    case menuBarCreationFailure = "menuBar.creationFailure"
    case menuBarButtonUnavailable = "menuBar.buttonUnavailable"
    case menuBarOpenNewWindow = "menuBar.openNewWindow"
    case sessionRestoreSingleFailure = "session.restoreSingleFailure"
    case sessionRestoreMultipleFailure = "session.restoreMultipleFailure"
    case sessionRestoreDetail = "session.restoreDetail"
    case sessionRestoreFailureLine = "session.restoreFailureLine"
    case openFailure = "open.failure"
    case linkOpenFailure = "link.openFailure"
    case fontSaveFailure = "font.saveFailure"
    case aboutCreatedBy = "about.createdBy"
    case aboutWebsite = "about.website"
    case aboutSupport = "about.support"
    case aboutPrivacyPolicy = "about.privacyPolicy"
    case aboutSourceCode = "about.sourceCode"
    case fileTooLarge = "error.fileTooLarge"
    case documentTooLarge = "error.documentTooLarge"
    case regularFilesOnly = "error.regularFilesOnly"
    case fileChangedOnDisk = "error.fileChangedOnDisk"
    case coordinatedWriteDenied = "error.coordinatedWriteDenied"
    case unsupportedTextEncoding = "error.unsupportedTextEncoding"
    case unrepresentableText = "error.unrepresentableText"
    case emptyFontName = "error.emptyFontName"
    case invalidFontPointSize = "error.invalidFontPointSize"
    case savedFontUnavailable = "error.savedFontUnavailable"
    case sessionWindowOrTabLimit = "error.sessionWindowOrTabLimit"
    case sessionTabLimit = "error.sessionTabLimit"
    case missingPersistentAccess = "error.missingPersistentAccess"
    case securityScopedAccessDenied = "error.securityScopedAccessDenied"
    case persistentAccessUnavailableAfterWrite = "error.persistentAccessUnavailableAfterWrite"
    case invalidRecentDocumentData = "error.invalidRecentDocumentData"
    public var englishValue: String {
        switch self {
        case .mainMenu: "Main Menu"
        case .aboutMacPad: "About MacPad"
        case .services: "Services"
        case .hideMacPad: "Hide MacPad"
        case .hideOthers: "Hide Others"
        case .showAll: "Show All"
        case .quitMacPad: "Quit MacPad"
        case .fileMenu: "File"
        case .newTab: "New Tab"
        case .newWindow: "New Window"
        case .open: "Open…"
        case .openRecent: "Open Recent"
        case .noRecentDocuments: "No Recent Documents"
        case .clearRecentMenu: "Clear Menu"
        case .recentDocumentsUnavailable: "Recent documents are unavailable"
        case .close: "Close"
        case .save: "Save"
        case .saveAs: "Save As…"
        case .clearSessionData: "Clear Session Data"
        case .print: "Print…"
        case .editMenu: "Edit"
        case .undo: "Undo"
        case .redo: "Redo"
        case .cut: "Cut"
        case .copy: "Copy"
        case .paste: "Paste"
        case .delete: "Delete"
        case .find: "Find…"
        case .findNext: "Find Next"
        case .findPrevious: "Find Previous"
        case .replace: "Replace…"
        case .goTo: "Go To…"
        case .selectAll: "Select All"
        case .timeDate: "Time/Date"
        case .formatMenu: "Format"
        case .wordWrap: "Word Wrap"
        case .font: "Font…"
        case .viewMenu: "View"
        case .zoomIn: "Zoom In"
        case .zoomOut: "Zoom Out"
        case .restoreDefaultZoom: "Restore Default Zoom"
        case .statusBar: "Status Bar"
        case .showInMenuBar: "Show MacPad in Menu Bar"
        case .windowMenu: "Window"
        case .minimize: "Minimize"
        case .zoom: "Zoom"
        case .showPreviousTab: "Show Previous Tab"
        case .showNextTab: "Show Next Tab"
        case .bringAllToFront: "Bring All to Front"
        case .helpMenu: "Help"
        case .macPadHelp: "MacPad Help"
        case .reportIssue: "Report an Issue"
        case .privacy: "Privacy"
        case .security: "Security"
        case .checkForUpdates: "Check for Updates…"
        case .findTitle: "Find"
        case .replaceTitle: "Replace"
        case .findWhat: "Find what:"
        case .replaceWith: "Replace with:"
        case .findWhatAccessibilityLabel: "Find what"
        case .replaceWithAccessibilityLabel: "Replace with"
        case .replaceAll: "Replace All"
        case .matchCase: "Match case"
        case .wrapAround: "Wrap around"
        case .goToLineTitle: "Go To Line"
        case .lineNumberLabel: "Line number:"
        case .lineNumber: "Line number"
        case .goToLine: "Go To"
        case .cancel: "Cancel"
        case .dontSave: "Don't Save"
        case .discardChanges: "Discard Changes"
        case .recover: "Recover"
        case .reloadFromDisk: "Reload from Disk"
        case .locate: "Locate…"
        case .skip: "Skip"
        case .cancelRestore: "Cancel Restore"
        case .untitled: "Untitled"
        case .untitledFileName: "Untitled.txt"
        case .windowTitle: "%1$@ - MacPad"
        case .documentText: "Document text"
        case .documentStatus: "Document status"
        case .statusLine: "Ln %1$lld, Col %2$lld  |  %3$lld%%  |  %4$@  |  %5$@"
        case .encodingLabel: "Encoding:"
        case .textEncoding: "Text encoding"
        case .saveFailure: "Could not save the file."
        case .invalidTextEncoding: "No valid text encoding was selected."
        case .fontUseFailure: "Could not use the selected font."
        case .unsavedChangesQuestion: "Do you want to save changes to this document?"
        case .unsavedChangesWarning: "Your changes will be lost if you do not save them."
        case .externalChangeTitle: "This file changed outside MacPad."
        case .externalChangeGuidance: "Save to another file, reload, or keep editing."
        case .reloadFailure: "Could not reload the file."
        case .menuBarCreationFailure: "Could not add MacPad to the menu bar."
        case .menuBarButtonUnavailable: "macOS did not provide a menu-bar button."
        case .menuBarOpenNewWindow: "Open a new MacPad window"
        case .sessionRestoreSingleFailure: "Could not restore a previous MacPad tab."
        case .sessionRestoreMultipleFailure: "Some previous MacPad tabs could not be restored."
        case .sessionRestoreDetail: "%1$@\n\n%2$@"
        case .sessionRestoreFailureLine: "Could not restore %1$@: %2$@"
        case .openFailure: "Could not open %1$@."
        case .linkOpenFailure: "Could not open the link."
        case .fontSaveFailure: "Could not save the editor font."
        case .aboutCreatedBy: "Created by %1$@"
        case .aboutWebsite: "Website: %1$@"
        case .aboutSupport: "Support: %1$@"
        case .aboutPrivacyPolicy: "Privacy Policy"
        case .aboutSourceCode: "Source Code: %1$@"
        case .fileTooLarge: "File is too large to open safely: %1$@ is %2$lld bytes, maximum is %3$lld bytes."
        case .documentTooLarge: "Document is too large to save safely: %1$@ would be %2$lld bytes, maximum is %3$lld bytes."
        case .regularFilesOnly: "Only regular files can be opened safely: %1$@."
        case .fileChangedOnDisk: "The file changed on disk after MacPad opened it: %1$@. Reload it or use Save As to avoid overwriting another edit."
        case .coordinatedWriteDenied: "macOS did not grant coordinated write access to the file: %1$@."
        case .unsupportedTextEncoding: "File is not readable as supported plain text: %1$@."
        case .unrepresentableText: "The document contains text that cannot be represented as %1$@: %2$@."
        case .emptyFontName: "Editor font name must not be empty."
        case .invalidFontPointSize: "Editor font size must be between 6 and 72 points: %1$g."
        case .savedFontUnavailable: "Saved editor font is not available: %1$@."
        case .sessionWindowOrTabLimit: "Session contains more windows or tabs than MacPad supports."
        case .sessionTabLimit: "Session contains more tabs than MacPad supports."
        case .missingPersistentAccess: "MacPad no longer has persistent access to this file: %1$@. Choose the file again to restore access."
        case .securityScopedAccessDenied: "macOS did not grant MacPad access to this file: %1$@. Choose the file again to restore access."
        case .persistentAccessUnavailableAfterWrite: "MacPad saved this file, but could not retain access to it: %1$@. macOS reported: %2$@. Choose Save As and select the file again before closing this document."
        case .invalidRecentDocumentData: "Saved recent-document access data is invalid. Clear the Open Recent menu to remove it."
        }
    }
}

public struct MacPadLocalization: Sendable {
    public let bundle: Bundle

    public init(bundle: Bundle) {
        self.bundle = bundle
    }

    public func string(_ key: MacPadStringKey) -> String {
        bundle.localizedString(
            forKey: key.rawValue,
            value: key.englishValue,
            table: "Localizable"
        )
    }

    public func localized(_ key: MacPadStringKey) -> String {
        string(key)
    }

    public func technicalTerm(_ key: MacPadTechnicalTermKey) -> String {
        bundle.localizedString(
            forKey: key.rawValue,
            value: key.englishValue,
            table: "TechnicalTerms"
        )
    }

    public func windowTitle(documentName: String) -> String {
        formatted(.windowTitle, arguments: [documentName])
    }

    public func statusLine(
        line: Int,
        column: Int,
        zoom: Int,
        lineEnding: String,
        encoding: String
    ) -> String {
        formatted(
            .statusLine,
            arguments: [Int64(line), Int64(column), Int64(zoom), lineEnding, encoding]
        )
    }

    public func sessionRestoreDetail(
        fileName: String,
        errorDescription: String
    ) -> String {
        formatted(.sessionRestoreDetail, arguments: [fileName, errorDescription])
    }

    public func sessionRestoreFailureLine(
        fileName: String,
        errorDescription: String
    ) -> String {
        formatted(.sessionRestoreFailureLine, arguments: [fileName, errorDescription])
    }

    public func openFailure(fileName: String) -> String {
        formatted(.openFailure, arguments: [fileName])
    }

    public func aboutCreatedBy(creator: String) -> String {
        formatted(.aboutCreatedBy, arguments: [creator])
    }

    public func aboutWebsite(host: String) -> String {
        formatted(.aboutWebsite, arguments: [host])
    }

    public func aboutSupport(emailAddress: String) -> String {
        formatted(.aboutSupport, arguments: [emailAddress])
    }

    public func aboutSourceCode(repository: String) -> String {
        formatted(.aboutSourceCode, arguments: [repository])
    }

    public func fileTooLarge(
        path: String,
        sizeBytes: Int64,
        maximumBytes: Int64
    ) -> String {
        formatted(.fileTooLarge, arguments: [path, sizeBytes, maximumBytes])
    }

    public func documentTooLarge(
        path: String,
        sizeBytes: Int64,
        maximumBytes: Int64
    ) -> String {
        formatted(.documentTooLarge, arguments: [path, sizeBytes, maximumBytes])
    }

    public func regularFilesOnly(path: String) -> String {
        formatted(.regularFilesOnly, arguments: [path])
    }

    public func fileChangedOnDisk(path: String) -> String {
        formatted(.fileChangedOnDisk, arguments: [path])
    }

    public func coordinatedWriteDenied(path: String) -> String {
        formatted(.coordinatedWriteDenied, arguments: [path])
    }

    public func unsupportedTextEncoding(path: String) -> String {
        formatted(.unsupportedTextEncoding, arguments: [path])
    }

    public func unrepresentableText(encoding: String, path: String) -> String {
        formatted(.unrepresentableText, arguments: [encoding, path])
    }

    public func invalidFontPointSize(pointSize: Double) -> String {
        formatted(.invalidFontPointSize, arguments: [pointSize])
    }

    public func savedFontUnavailable(fontName: String) -> String {
        formatted(.savedFontUnavailable, arguments: [fontName])
    }

    public func missingPersistentAccess(path: String) -> String {
        formatted(.missingPersistentAccess, arguments: [path])
    }

    public func securityScopedAccessDenied(path: String) -> String {
        formatted(.securityScopedAccessDenied, arguments: [path])
    }

    public func persistentAccessUnavailableAfterWrite(
        path: String,
        reason: String
    ) -> String {
        formatted(
            .persistentAccessUnavailableAfterWrite,
            arguments: [path, reason]
        )
    }

    private func formatted(
        _ key: MacPadStringKey,
        arguments: [any CVarArg]
    ) -> String {
        String(
            format: string(key),
            locale: Locale.current,
            arguments: arguments
        )
    }
}
