import Foundation
import Testing
@testable import NotepadMac

@Suite("Distribution channel")
struct DistributionChannelTests {
    @Test("distribution capabilities are explicit")
    func distributionCapabilities() {
        #expect(DistributionChannel.direct.showsDirectUpdateCommand)
        #expect(!DistributionChannel.direct.requiresPersistentSecurityScope)
        #expect(!DistributionChannel.appStore.showsDirectUpdateCommand)
        #expect(DistributionChannel.appStore.requiresPersistentSecurityScope)
    }

    @Test("current Store routes expose only permanent customer destinations")
    func currentStoreRoutesExposePermanentDestinations() {
        let routes = CustomerRoutes.current(for: .appStore)

        #expect(routes.productURL?.absoluteString == "https://macpad.net")
        #expect(routes.creatorProfileURL == nil)
        #expect(routes.sourceCodeURL == nil)
        #expect(routes.helpURL == nil)
        #expect(routes.supportURL?.absoluteString == "https://macpad.net/support")
        #expect(routes.supportEmailURL?.absoluteString == "mailto:support@macpad.net")
        #expect(routes.privacyURL?.absoluteString == "https://macpad.net/privacy")
        #expect(routes.securityURL == nil)
        #expect(routes.updateURL == nil)
        #expect(routes.migrationURL == nil)
    }

    #if !MACPAD_APP_STORE
    @Test("current direct routes combine permanent and transition destinations")
    func currentDirectRoutesCombinePermanentAndTransitionDestinations() {
        let routes = CustomerRoutes.current(for: .direct)

        #expect(routes.productURL?.absoluteString == "https://macpad.net")
        #expect(routes.creatorProfileURL?.absoluteString == "https://github.com/anvilfilbert")
        #expect(
            routes.sourceCodeURL?.absoluteString
                == "https://github.com/anvilfilbert/MacPad"
        )
        #expect(routes.helpURL?.absoluteString == "https://github.com/anvilfilbert/MacPad/wiki")
        #expect(routes.supportURL?.absoluteString == "https://macpad.net/support")
        #expect(routes.supportEmailURL?.absoluteString == "mailto:support@macpad.net")
        #expect(routes.privacyURL?.absoluteString == "https://macpad.net/privacy")
        #expect(
            routes.updateURL?.absoluteString
                == "https://github.com/anvilfilbert/MacPad/releases/latest"
        )
        #expect(routes.securityURL == nil)
        #expect(routes.migrationURL == nil)
    }
    #endif
}
