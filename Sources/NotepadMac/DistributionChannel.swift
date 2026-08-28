import Foundation

enum DistributionChannel: Equatable, Sendable {
    case direct
    case appStore

    static var current: DistributionChannel {
        #if MACPAD_APP_STORE
        return .appStore
        #else
        return .direct
        #endif
    }

    var showsDirectUpdateCommand: Bool {
        self == .direct
    }

    var requiresPersistentSecurityScope: Bool {
        self == .appStore
    }
}

struct CustomerRoutes: Equatable, Sendable {
    let productURL: URL?
    let creatorProfileURL: URL?
    let helpURL: URL?
    let supportURL: URL?
    let privacyURL: URL?
    let securityURL: URL?
    let updateURL: URL?
    let migrationURL: URL?

    init(
        productURL: URL?,
        creatorProfileURL: URL?,
        helpURL: URL?,
        supportURL: URL?,
        privacyURL: URL?,
        securityURL: URL?,
        updateURL: URL?,
        migrationURL: URL?
    ) {
        self.productURL = productURL
        self.creatorProfileURL = creatorProfileURL
        self.helpURL = helpURL
        self.supportURL = supportURL
        self.privacyURL = privacyURL
        self.securityURL = securityURL
        self.updateURL = updateURL
        self.migrationURL = migrationURL
    }

    static func current(for channel: DistributionChannel) -> CustomerRoutes {
        switch channel {
        case .direct:
            #if !MACPAD_APP_STORE
            return CustomerRoutes(
                productURL: URL(string: "https://github.com/anvilfilbert/MacPad"),
                creatorProfileURL: URL(string: "https://github.com/anvilfilbert"),
                helpURL: URL(string: "https://github.com/anvilfilbert/MacPad/wiki"),
                supportURL: URL(
                    string: "https://github.com/anvilfilbert/MacPad/issues/new/choose"
                ),
                privacyURL: nil,
                securityURL: nil,
                updateURL: URL(
                    string: "https://github.com/anvilfilbert/MacPad/releases/latest"
                ),
                migrationURL: nil
            )
            #else
            return unconfigured
            #endif
        case .appStore:
            return unconfigured
        }
    }

    private static var unconfigured: CustomerRoutes {
        CustomerRoutes(
            productURL: nil,
            creatorProfileURL: nil,
            helpURL: nil,
            supportURL: nil,
            privacyURL: nil,
            securityURL: nil,
            updateURL: nil,
            migrationURL: nil
        )
    }
}
