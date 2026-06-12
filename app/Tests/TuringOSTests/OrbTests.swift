// OrbTests.swift — A1_16 Orb + Facilitator shell unit tests.
//
// Six test functions:
//   1. State machine transitions (idle->listening->thinking->idle; degraded entry).
//   2. MockProbe three-branch detection drives correct OrbState + projection prefix.
//   3. IntentRouter determinism: same input -> identical doc; unknown -> intent_suggestions.
//   4. KeychainStore roundtrip (save/load/delete; tolerates CI keychain unavailability).
//   5. No-plaintext-leak: MetaAIConfig encodes WITHOUT the secret.
//   6. metaAIConfigCard factory schema-conformance (roundtrip; derive_source non-empty).

import Foundation
import XCTest
@testable import TuringOS

final class OrbTests: XCTestCase {

    // MARK: - Test 1: State machine transitions

    func testStateMachineTransitions() {
        // idle -> listening -> thinking -> idle
        var s: OrbStateValue = .idle
        s = OrbReducer.reduce(state: s, event: .inputSubmitted(text: "hello"))
        XCTAssertEqual(s, .listening, "idle + inputSubmitted -> listening")

        s = OrbReducer.reduce(state: s, event: .facilitatorReceived)
        XCTAssertEqual(s, .thinking, "listening + facilitatorReceived -> thinking")

        s = OrbReducer.reduce(state: s, event: .taskCompleted)
        XCTAssertEqual(s, .idle, "thinking + taskCompleted -> idle")

        // Degraded entry from thinking via runtimeResolved(.degraded)
        var d: OrbStateValue = .thinking
        d = OrbReducer.reduce(state: d, event: .runtimeResolved(.degraded))
        XCTAssertEqual(d, .degraded, "thinking + runtimeResolved(.degraded) -> degraded")

        // Degraded entry from idle via runtimeResolved(.degraded)
        var d2: OrbStateValue = .idle
        d2 = OrbReducer.reduce(state: d2, event: .runtimeResolved(.degraded))
        XCTAssertEqual(d2, .degraded, "idle + runtimeResolved(.degraded) -> degraded")

        // Recovery: degraded + resetIdle -> idle
        var r: OrbStateValue = .degraded
        r = OrbReducer.reduce(state: r, event: .resetIdle)
        XCTAssertEqual(r, .idle, "degraded + resetIdle -> idle")

        // needsRuling: thinking -> needsRuling -> thinking (after ruling)
        var n: OrbStateValue = .thinking
        n = OrbReducer.reduce(state: n, event: .rulingRequested)
        XCTAssertEqual(n, .needsRuling, "thinking + rulingRequested -> needsRuling")
        n = OrbReducer.reduce(state: n, event: .rulingCompleted)
        XCTAssertEqual(n, .thinking, "needsRuling + rulingCompleted -> thinking")

        // faultDetected always yields degraded
        for state in OrbStateValue.allCases {
            let next = OrbReducer.reduce(state: state, event: .faultDetected(reason: "test"))
            XCTAssertEqual(next, .degraded, "\(state) + faultDetected -> degraded")
        }
    }

    // MARK: - Test 2: MockProbe three-branch detection

    @MainActor
    func testMockProbeThreeBranchDetection() async {
        // Branch A: localFM
        let localVM = OrbViewModel(probe: MockFacilitatorProbe(.localFM))
        localVM.resolveRuntime()
        XCTAssertEqual(localVM.runtimeKind, .localFM, "localFM probe sets runtimeKind")
        XCTAssertNotEqual(localVM.state, .degraded, "localFM does not degrade")

        // Branch B: apiBacked
        let apiVM = OrbViewModel(probe: MockFacilitatorProbe(.apiBacked))
        apiVM.resolveRuntime()
        XCTAssertEqual(apiVM.runtimeKind, .apiBacked)
        XCTAssertNotEqual(apiVM.state, .degraded, "apiBacked does not degrade")

        // Branch C: degraded — OrbState must be .degraded
        let degradedVM = OrbViewModel(probe: MockFacilitatorProbe(.degraded))
        degradedVM.resolveRuntime()
        XCTAssertEqual(degradedVM.runtimeKind, .degraded)
        XCTAssertEqual(degradedVM.state, .degraded, "degraded probe sets state=degraded")

        // Degraded projection prefix: after input submission, first block
        // must be a summary_card with "系统降级" title.
        degradedVM.send(.inputSubmitted(text: "unknown gibberish xyz"))
        if let doc = degradedVM.currentProjection {
            XCTAssertFalse(doc.deriveSource.isEmpty, "projection has derive_source")
            let hasNotice = doc.blocks.contains { block in
                if case .summaryCard(let p) = block { return p.title == "系统降级" }
                return false
            }
            XCTAssertTrue(hasNotice, "degraded projection must be prefixed with 系统降级 notice")
        } else {
            XCTFail("degraded + inputSubmitted must produce a projection")
        }

        // Non-degraded projection: no degraded notice prefix
        let localVM2 = OrbViewModel(probe: MockFacilitatorProbe(.localFM))
        localVM2.resolveRuntime()
        localVM2.send(.inputSubmitted(text: "unknown gibberish xyz"))
        if let doc = localVM2.currentProjection {
            let hasNotice = doc.blocks.contains { block in
                if case .summaryCard(let p) = block { return p.title == "系统降级" }
                return false
            }
            XCTAssertFalse(hasNotice, "non-degraded projection must NOT have 系统降级 notice")
        } else {
            XCTFail("localFM + inputSubmitted must produce a projection")
        }
    }

    // MARK: - Test 3: IntentRouter determinism

    func testIntentRouterDeterminism() {
        // Use a mock catalog with one entry so the "项目" picker branch always
        // has a project to list — regardless of what is or isn't on disk in CI.
        let mockCatalog = MockCatalogSource(items: [
            CatalogItem(displayName: "TuringOS",
                        remoteKey: "github.com/zephryj/turingos.app",
                        localPath: "/Users/zephryj/Developer/turingos.app",
                        pushedAt: nil)
        ], tag: "catalog:mock")

        // Same input -> identical ViewIRDocument (pure function law)
        let input = "项目列表"
        let doc1 = IntentRouter.route(input: input, runtimeKind: .localFM, catalog: mockCatalog)
        let doc2 = IntentRouter.route(input: input, runtimeKind: .localFM, catalog: mockCatalog)
        XCTAssertEqual(doc1, doc2, "IntentRouter must be deterministic: same input -> identical output")

        // "项目" / "project" -> project_picker kind
        let projDoc = IntentRouter.route(input: "查看项目", runtimeKind: .localFM, catalog: mockCatalog)
        XCTAssertEqual(projDoc.kind, "project_init", "项目 intent routes to project_init kind")
        let hasProjectPicker = projDoc.blocks.contains {
            if case .projectPicker = $0 { return true }
            return false
        }
        XCTAssertTrue(hasProjectPicker, "项目 intent doc must contain project_picker block")

        // "早" / "morning" -> morning_ritual kind
        let morningDoc = IntentRouter.route(input: "早晨仪式", runtimeKind: .localFM)
        XCTAssertEqual(morningDoc.kind, "morning_ritual", "早 intent routes to morning_ritual kind")

        // "meta" -> general kind with metaAIConfigCard
        let metaDoc = IntentRouter.route(input: "meta 设置", runtimeKind: .localFM)
        XCTAssertEqual(metaDoc.kind, "general")

        // Unknown input -> intent_suggestions block (discoverability escape hatch §4)
        let unknownDoc = IntentRouter.route(input: "xxxxxxxxunknownintentxxx", runtimeKind: .localFM)
        let hasSuggestions = unknownDoc.blocks.contains {
            if case .intentSuggestions = $0 { return true }
            return false
        }
        XCTAssertTrue(hasSuggestions, "unknown intent must produce intent_suggestions block (§4 escape hatch)")

        // All routed docs must have non-empty derive_source (P1 predicate)
        let allDocs = [projDoc, morningDoc, metaDoc, unknownDoc]
        for doc in allDocs {
            XCTAssertFalse(doc.deriveSource.isEmpty, "all projections must have derive_source (P1)")
        }
    }

    // MARK: - Test 4: KeychainStore roundtrip

    func testKeychainStoreRoundtrip() {
        // Use a test-unique service name to avoid collisions with real keys.
        let service = "turingos.test.\(UUID().uuidString)"
        let account = "test_account"
        let secret  = "s3cr3t_\(UUID().uuidString)"

        let ks = KeychainStore()

        // Clean up before: remove any pre-existing item (ignore errors)
        _ = try? ks.delete(service: service, account: account)

        do {
            // Save
            let descriptor = try ks.save(service: service, account: account, secret: secret)
            // Descriptor is the service name — never the secret.
            XCTAssertEqual(descriptor, service, "save() returns scope descriptor")
            XCTAssertFalse(descriptor.contains(secret), "descriptor must not contain the secret")

            // Load
            let loaded = try ks.load(service: service, account: account)
            XCTAssertEqual(loaded, secret, "load() must return the saved secret")

            // hasSecret
            XCTAssertTrue(ks.hasSecret(service: service, account: account),
                          "hasSecret must be true after save")

            // Delete
            let deleteDescriptor = try ks.delete(service: service, account: account)
            XCTAssertEqual(deleteDescriptor, service, "delete() returns scope descriptor")

            // hasSecret after delete
            XCTAssertFalse(ks.hasSecret(service: service, account: account),
                           "hasSecret must be false after delete")

            // Load after delete -> itemNotFound
            do {
                _ = try ks.load(service: service, account: account)
                XCTFail("load after delete must throw")
            } catch KeychainError.itemNotFound {
                // expected
            } catch {
                XCTFail("unexpected error after delete: \(error)")
            }

        } catch KeychainError.unexpectedStatus(let status) {
            // CI environments may have restricted Keychain access (errSecMissingEntitlement
            // = -34018, errSecInteractionNotAllowed = -25308). Treat as a tolerant pass —
            // the wrapper returns a typed error, never crashes.
            let restrictedStatuses: Set<OSStatus> = [-34018, -25308, -67072]
            if restrictedStatuses.contains(status) {
                // Keychain unavailable in this CI environment — typed failure accepted.
                return
            }
            XCTFail("KeychainStore roundtrip failed with status \(status)")
        } catch {
            XCTFail("Unexpected KeychainStore error: \(error)")
        }
    }

    // MARK: - Test 5: No-plaintext-leak

    func testNoPlaintextLeak() throws {
        // A MetaAIConfig must encode to JSON without any secret value.
        // The secret lives only in Keychain; the config carries only the scope descriptor.
        let secret = "sk-definitely-secret-key-\(UUID().uuidString)"
        let config = MetaAIConfig(
            providerKind: .openaiCompatible,
            endpointURL: URL(string: "https://api.meta.ai/v1"),
            credentialScope: "meta_ai_api_key",
            displayName: "Meta AI"
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(config)
        let json = String(data: data, encoding: .utf8) ?? ""

        // Secret must NOT appear in the JSON encoding.
        XCTAssertFalse(json.contains(secret),
                       "MetaAIConfig JSON must not contain the API key secret")

        // The credential_scope descriptor IS present (it's metadata, not a secret).
        XCTAssertTrue(json.contains("meta_ai_api_key"),
                      "credential_scope descriptor must appear in config JSON")

        // Round-trip decode must be equal.
        let decoded = try JSONDecoder().decode(MetaAIConfig.self, from: data)
        XCTAssertEqual(decoded, config, "MetaAIConfig encode/decode roundtrip must be lossless")

        // Additional guard: no field named "secret", "key", "password", "token"
        // with a suspicious value in the JSON.
        let lowercased = json.lowercased()
        // The only allowed occurrences of "key" are in "api_key" (scope name)
        // and "credential_scope". There must be no raw secret value.
        XCTAssertFalse(lowercased.contains("sk-"),
                       "MetaAIConfig JSON must not contain sk- prefixed secrets")
    }

    // MARK: - Test 6: metaAIConfigCard factory schema-conformance

    func testMetaAIConfigCardSchemaConformance() throws {
        let config = MetaAIConfig(
            providerKind: .anthropicMessages,
            endpointURL: URL(string: "https://api.anthropic.com/v1/messages"),
            credentialScope: "anthropic_api_key",
            displayName: "Anthropic"
        )
        let doc = TemplateProjections.metaAIConfigCard(config: config)

        // Schema version
        XCTAssertEqual(doc.schemaVersion, viewIRSchemaVersion,
                       "metaAIConfigCard must use canonical schema version")

        // Kind non-empty
        XCTAssertFalse(doc.kind.isEmpty, "kind must be non-empty")

        // derive_source non-empty (P1 predicate)
        XCTAssertFalse(doc.deriveSource.isEmpty,
                       "metaAIConfigCard derive_source must be non-empty (P1)")
        for src in doc.deriveSource {
            XCTAssertFalse(src.isEmpty, "each derive_source entry must be non-empty")
        }

        // blocks non-empty
        XCTAssertFalse(doc.blocks.isEmpty, "metaAIConfigCard blocks must be non-empty")

        // Must contain a credential_field block
        let hasCredentialField = doc.blocks.contains {
            if case .credentialField = $0 { return true }
            return false
        }
        XCTAssertTrue(hasCredentialField,
                      "metaAIConfigCard must include a credential_field block (§7.1)")

        // credential_field block must NOT contain the secret — only the scope descriptor
        for block in doc.blocks {
            if case .credentialField(let p) = block {
                XCTAssertEqual(p.credentialScope, "anthropic_api_key",
                               "credential_scope must be the scope descriptor")
                // The scope descriptor itself is not a secret value
                XCTAssertFalse(p.credentialScope.isEmpty,
                               "credentialScope must be non-empty")
            }
        }

        // Encode → decode roundtrip must be lossless
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let data = try encoder.encode(doc)
        let roundTripped = try JSONDecoder().decode(ViewIRDocument.self, from: data)
        XCTAssertEqual(doc, roundTripped,
                       "metaAIConfigCard encode/decode roundtrip must be lossless")

        // derive_source in encoded JSON must be non-empty (P1 in the wire format)
        let json = String(data: data, encoding: .utf8) ?? ""
        XCTAssertTrue(json.contains("derive_source"),
                      "encoded JSON must contain derive_source field")
    }
}
