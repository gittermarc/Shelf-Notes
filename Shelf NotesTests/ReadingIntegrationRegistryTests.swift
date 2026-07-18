import Testing
@testable import Shelf_Notes

struct ReadingIntegrationRegistryTests {
    @Test func registryReportsProviderCapabilitiesHonestly() {
        let registry = ReadingIntegrationRegistry.default

        let apple = registry.capabilities(for: .appleBooks)
        #expect(apple.contains(.canOpenReadingDestination))
        #expect(!apple.contains(.canSyncProgress))
        #expect(!apple.contains(.canImportLibrary))
        #expect(apple.contains(.canReceiveShares))
        #expect(registry.supportsCompanionLaunch(for: .appleBooks))

        let kindle = registry.capabilities(for: .kindle)
        #expect(kindle.contains(.canOpenReadingDestination))
        #expect(kindle.contains(.canReceiveShares))
        #expect(!kindle.contains(.canSyncProgress))
        #expect(!kindle.contains(.canImportLibrary))
        #expect(registry.supportsCompanionLaunch(for: .kindle))

        let other = registry.capabilities(for: .other)
        #expect(other == [.canOpenReadingDestination, .canReceiveShares])
        #expect(registry.supportsCompanionLaunch(for: .other))

        #expect(registry.capabilities(for: .googleBooks) == [.canReceiveShares])
        #expect(!registry.supportsCompanionLaunch(for: .googleBooks))
        #expect(registry.capabilities(for: .localFile).isEmpty)
        #expect(!registry.supportsCompanionLaunch(for: .localFile))
        #expect(registry.capabilities(for: .none).isEmpty)
    }

    @Test func availabilityStatesReflectCurrentImplementation() throws {
        let registry = ReadingIntegrationRegistry.default
        let apple = try #require(registry.integration(for: .appleBooks))
        let google = try #require(registry.integration(for: .googleBooks))
        let local = try #require(registry.integration(for: .localFile))

        let appleWithoutLink = ReadingIntegrationAvailabilityResolver.availability(for: apple)
        #expect(appleWithoutLink.title == "Begleitmodus")
        #expect(appleWithoutLink.isUsableNow)

        let appleWithLink = ReadingIntegrationAvailabilityResolver.availability(
            for: apple,
            environment: ReadingIntegrationEnvironment(hasStoredReadingLink: true)
        )
        #expect(appleWithLink.title == "Begleitmodus")
        #expect(appleWithLink.detail.contains("Leselink"))

        let googleAvailability = ReadingIntegrationAvailabilityResolver.availability(for: google)
        #expect(googleAvailability.title == "Nicht verbunden")
        #expect(!googleAvailability.isUsableNow)
        #expect(!googleAvailability.isConnectedPresentation)

        let googleWithAuthorizationFlag = ReadingIntegrationAvailabilityResolver.availability(
            for: google,
            environment: ReadingIntegrationEnvironment(isAuthorized: true)
        )
        #expect(googleWithAuthorizationFlag.title == "Nicht verbunden")
        #expect(!googleWithAuthorizationFlag.isConnectedPresentation)

        let localWithPublication = ReadingIntegrationAvailabilityResolver.availability(
            for: local,
            environment: ReadingIntegrationEnvironment(
                hasLocalPublication: true,
                isLocalReaderFeatureEnabled: true
            )
        )
        #expect(localWithPublication.title == "Folgt später")
        #expect(!localWithPublication.isUsableNow)
    }
}