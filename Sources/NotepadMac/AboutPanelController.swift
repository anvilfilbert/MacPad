import AppKit

struct AboutApplicationIdentity {
    let name: String
    let version: String
    let build: String

    init(name: String, version: String, build: String) {
        precondition(!name.isEmpty, "About application name must not be empty.")
        precondition(!version.isEmpty, "About application version must not be empty.")
        precondition(!build.isEmpty, "About application build must not be empty.")
        self.name = name
        self.version = version
        self.build = build
    }

    init(bundle: Bundle) {
        self.init(
            name: Self.requiredString(forKey: "CFBundleDisplayName", in: bundle),
            version: Self.requiredString(forKey: "CFBundleShortVersionString", in: bundle),
            build: Self.requiredString(forKey: "CFBundleVersion", in: bundle)
        )
    }

    var versionAndBuild: String {
        "Version \(version) (\(build))"
    }

    private static func requiredString(forKey key: String, in bundle: Bundle) -> String {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty else {
            preconditionFailure("About panel requires non-empty bundle value for \(key).")
        }
        return value
    }
}

struct AboutLinkPresentation {
    let identifier: NSUserInterfaceItemIdentifier
    let title: String
    let action: Selector

    init(identifier: String, title: String, action: Selector) {
        precondition(!identifier.isEmpty, "About link identifier must not be empty.")
        precondition(!title.isEmpty, "About link title must not be empty.")
        self.identifier = NSUserInterfaceItemIdentifier(identifier)
        self.title = title
        self.action = action
    }
}

@MainActor
final class AboutPanelController: NSWindowController {
    init(
        identity: AboutApplicationIdentity,
        icon: NSImage,
        title: String,
        links: [AboutLinkPresentation],
        target: AnyObject
    ) {
        precondition(!title.isEmpty, "About panel title must not be empty.")
        precondition(!links.isEmpty, "About panel requires at least one customer link.")

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 440, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = title
        panel.identifier = NSUserInterfaceItemIdentifier("about.panel")
        panel.isReleasedWhenClosed = false
        panel.isMovableByWindowBackground = true
        panel.animationBehavior = .documentWindow
        panel.autorecalculatesKeyViewLoop = false

        super.init(window: panel)

        let contentView = NSView()
        panel.contentView = contentView

        let iconView = NSImageView(image: icon)
        iconView.imageScaling = .scaleProportionallyUpOrDown
        iconView.setAccessibilityLabel(identity.name)

        let nameLabel = NSTextField(labelWithString: identity.name)
        nameLabel.alignment = .center
        nameLabel.font = NSFont.systemFont(ofSize: 20, weight: .semibold)
        nameLabel.identifier = NSUserInterfaceItemIdentifier("about.appName")

        let versionLabel = NSTextField(labelWithString: identity.versionAndBuild)
        versionLabel.alignment = .center
        versionLabel.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        versionLabel.textColor = .secondaryLabelColor
        versionLabel.identifier = NSUserInterfaceItemIdentifier("about.version")

        let linkButtons = links.map { link in
            Self.makeLinkButton(link, target: target)
        }
        Self.configureKeyViewLoop(linkButtons, in: panel)

        let linkStack = NSStackView(views: linkButtons)
        linkStack.orientation = .vertical
        linkStack.alignment = .centerX
        linkStack.spacing = 4

        let stack = NSStackView(views: [iconView, nameLabel, versionLabel, linkStack])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 8
        stack.setCustomSpacing(14, after: iconView)
        stack.setCustomSpacing(18, after: versionLabel)
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        NSLayoutConstraint.activate([
            iconView.widthAnchor.constraint(equalToConstant: 128),
            iconView.heightAnchor.constraint(equalToConstant: 128),
            stack.centerXAnchor.constraint(equalTo: contentView.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: contentView.leadingAnchor, constant: 24),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: contentView.trailingAnchor, constant: -24)
        ])

        panel.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        preconditionFailure("AboutPanelController does not support coder initialization.")
    }

    private static func makeLinkButton(
        _ link: AboutLinkPresentation,
        target: AnyObject
    ) -> NSButton {
        let button = NSButton(title: link.title, target: target, action: link.action)
        button.identifier = link.identifier
        button.isBordered = false
        button.focusRingType = .default
        button.font = NSFont.systemFont(ofSize: NSFont.smallSystemFontSize)
        button.contentTintColor = .linkColor
        button.setAccessibilityLabel(link.title)
        button.setAccessibilityRole(.link)
        return button
    }

    private static func configureKeyViewLoop(_ buttons: [NSButton], in panel: NSPanel) {
        for index in buttons.indices {
            let nextIndex = buttons.index(after: index) == buttons.endIndex
                ? buttons.startIndex
                : buttons.index(after: index)
            buttons[index].nextKeyView = buttons[nextIndex]
        }
        panel.initialFirstResponder = buttons[0]
    }
}
