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

    @Test("current Store routes fail closed")
    func currentStoreRoutesFailClosed() {
        let routes = CustomerRoutes.current(for: .appStore)

        #expect(routes.productURL == nil)
        #expect(routes.creatorProfileURL == nil)
        #expect(routes.helpURL == nil)
        #expect(routes.supportURL == nil)
        #expect(routes.privacyURL == nil)
        #expect(routes.securityURL == nil)
        #expect(routes.updateURL == nil)
        #expect(routes.migrationURL == nil)
    }

    #if !MACPAD_APP_STORE
    @Test("current direct routes preserve the transition destinations")
    func currentDirectRoutesPreserveTransitionDestinations() {
        let routes = CustomerRoutes.current(for: .direct)

        #expect(routes.productURL?.absoluteString == "https://github.com/anvilfilbert/MacPad")
        #expect(routes.creatorProfileURL?.absoluteString == "https://github.com/anvilfilbert")
        #expect(routes.helpURL?.absoluteString == "https://github.com/anvilfilbert/MacPad/wiki")
        #expect(
            routes.supportURL?.absoluteString
                == "https://github.com/anvilfilbert/MacPad/issues/new/choose"
        )
        #expect(
            routes.updateURL?.absoluteString
                == "https://github.com/anvilfilbert/MacPad/releases/latest"
        )
        #expect(routes.privacyURL == nil)
        #expect(routes.securityURL == nil)
        #expect(routes.migrationURL == nil)
    }
    #endif
}
