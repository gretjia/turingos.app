// CredentialSaveTests.swift — A1_32 predicate coverage.
// P1: default MetaAIConfig scope == DeepSeekPresets.credentialScope (seam closed)
// P2: submit handler — injected saver receives (scope, "api_key", secret);
//     empty secret/scope short-circuit WITHOUT calling the saver
// P3: success path returns the scope descriptor (caller clears the field);
//     saver errors surface as .saverFailed without the secret

import XCTest
@testable import TuringOS

final class CredentialSaveTests: XCTestCase {

    // MARK: - P1: scope seam

    func testDeepSeekDefaultScopeMatchesPresets() {
        let config = MetaAIConfig.deepSeekDefault()
        XCTAssertEqual(config.credentialScope, DeepSeekPresets.credentialScope,
            "Config-card scope must be byte-identical to the scope the gateway resolves")
        XCTAssertEqual(config.endpointURL, DeepSeekPresets.endpoint)
        XCTAssertEqual(config.providerKind, .openaiCompatible)
    }

    func testHandlerAccountMatchesPresetsDocumentedAccount() {
        // DeepSeekPresets documents KeychainStore.load(service: scope, account: "api_key").
        XCTAssertEqual(CredentialSubmitHandler.account, "api_key")
    }

    // MARK: - P2: saver receives exact triple; empty input short-circuits

    func testSubmitCallsSaverWithExactTriple() {
        nonisolated(unsafe) var captured: (service: String, account: String, secret: String)?
        let handler = CredentialSubmitHandler { service, account, secret in
            captured = (service, account, secret)
            return service
        }
        let result = handler.submit(scope: "deepseek-api", secret: "test-secret-value")
        XCTAssertEqual(captured?.service, "deepseek-api")
        XCTAssertEqual(captured?.account, "api_key")
        XCTAssertEqual(captured?.secret, "test-secret-value")
        XCTAssertEqual(result, .success("deepseek-api"))
    }

    func testSubmitTrimsWhitespaceBeforeSaving() {
        nonisolated(unsafe) var captured: String?
        let handler = CredentialSubmitHandler { _, _, secret in
            captured = secret
            return "scope"
        }
        _ = handler.submit(scope: "s", secret: "  padded-secret  \n")
        XCTAssertEqual(captured, "padded-secret")
    }

    func testEmptySecretShortCircuitsWithoutCallingSaver() {
        nonisolated(unsafe) var saverCalled = false
        let handler = CredentialSubmitHandler { _, _, _ in
            saverCalled = true
            return "scope"
        }
        let result = handler.submit(scope: "deepseek-api", secret: "   ")
        XCTAssertFalse(saverCalled, "Empty secret must never reach the saver")
        XCTAssertEqual(result, .failure(.emptySecret))
    }

    func testEmptyScopeShortCircuitsWithoutCallingSaver() {
        nonisolated(unsafe) var saverCalled = false
        let handler = CredentialSubmitHandler { _, _, _ in
            saverCalled = true
            return "scope"
        }
        let result = handler.submit(scope: "", secret: "real-secret")
        XCTAssertFalse(saverCalled)
        XCTAssertEqual(result, .failure(.emptyScope))
    }

    // MARK: - P3: error path carries description, never the secret

    func testSaverErrorSurfacesWithoutSecret() {
        struct FakeError: Error {}
        let handler = CredentialSubmitHandler { _, _, _ in
            throw FakeError()
        }
        let result = handler.submit(scope: "deepseek-api", secret: "super-secret-981")
        guard case .failure(.saverFailed(let description)) = result else {
            XCTFail("Expected saverFailed, got \(result)"); return
        }
        XCTAssertFalse(description.contains("super-secret-981"),
            "Error description must never contain the secret")
    }

    // MARK: - load() default

    func testStoreLoadFallsBackToDeepSeekDefault() {
        // Only valid when no config has been persisted in this test environment;
        // clear first to make the assertion deterministic.
        MetaAIConfigStore.clear()
        let loaded = MetaAIConfigStore.load()
        XCTAssertEqual(loaded, MetaAIConfig.deepSeekDefault())
    }
}

// MARK: - A1_33: probe scope follows config

extension CredentialSaveTests {
    func testProbeDefaultScopeFollowsCurrentConfig() {
        MetaAIConfigStore.clear()
        let probe = SystemFacilitatorProbe()
        XCTAssertEqual(probe.metaAIKeyScope, MetaAIConfigStore.load().credentialScope,
            "Probe must look where the key is actually saved (A1_33)")
        XCTAssertEqual(probe.metaAIKeyScope, DeepSeekPresets.credentialScope,
            "With no saved config, that is the user-ruled DeepSeek scope")
    }
}
