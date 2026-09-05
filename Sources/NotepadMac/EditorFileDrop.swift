import AppKit
import UniformTypeIdentifiers

enum EditorFileDropDecision: Equatable {
    case openFiles([URL])
    case rejectFileDrop
    case deferToTextView
}

enum EditorFileDropClassifier {
    static func classify(pasteboard: NSPasteboard) -> EditorFileDropDecision {
        guard pasteboard.availableType(from: [.fileURL]) != nil else {
            return .deferToTextView
        }
        guard let objects = pasteboard.readObjects(
            forClasses: [NSURL.self],
            options: [.urlReadingFileURLsOnly: true]
        ),
        !objects.isEmpty else {
            return .rejectFileDrop
        }

        let urls = objects.compactMap { object -> URL? in
            guard let url = object as? NSURL else { return nil }
            return (url as URL).resolvingSymlinksInPath().standardizedFileURL
        }
        guard urls.count == objects.count,
              urls.allSatisfy(isSupportedRegularTextFile) else {
            return .rejectFileDrop
        }
        return .openFiles(urls)
    }

    private static func isSupportedRegularTextFile(_ url: URL) -> Bool {
        guard url.isFileURL else { return false }
        do {
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .contentTypeKey])
            guard values.isRegularFile == true,
                  let contentType = values.contentType else {
                return false
            }
            return contentType.conforms(to: .text)
        } catch {
            return false
        }
    }
}

@MainActor
final class EditorTextView: NSTextView {
    var onOpenDroppedFiles: (([URL]) -> Void)?

    override func dragOperation(
        for dragInfo: any NSDraggingInfo,
        type: NSPasteboard.PasteboardType
    ) -> NSDragOperation {
        switch EditorFileDropClassifier.classify(pasteboard: dragInfo.draggingPasteboard) {
        case .openFiles:
            return .copy
        case .rejectFileDrop:
            return []
        case .deferToTextView:
            return super.dragOperation(for: dragInfo, type: type)
        }
    }

    override func performDragOperation(_ sender: any NSDraggingInfo) -> Bool {
        switch EditorFileDropClassifier.classify(pasteboard: sender.draggingPasteboard) {
        case .openFiles:
            return handleFileDrop(pasteboard: sender.draggingPasteboard)
        case .rejectFileDrop:
            return false
        case .deferToTextView:
            return super.performDragOperation(sender)
        }
    }

    func handleFileDrop(pasteboard: NSPasteboard) -> Bool {
        guard case let .openFiles(urls) = EditorFileDropClassifier.classify(pasteboard: pasteboard) else {
            return false
        }
        return openDroppedFiles(urls)
    }

    private func openDroppedFiles(_ urls: [URL]) -> Bool {
        guard let onOpenDroppedFiles else { return false }
        onOpenDroppedFiles(urls)
        return true
    }
}
