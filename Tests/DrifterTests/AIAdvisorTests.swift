import XCTest
@testable import Drifter

final class AIAdvisorTests: XCTestCase {
    func testAIProviderDefaults() {
        XCTAssertEqual(AIProvider.ollama.defaultModel, "llama3.2")
        XCTAssertFalse(AIProvider.ollama.requiresAPIKey)

        XCTAssertEqual(AIProvider.gemini.defaultModel, "gemini-2.5-flash")
        XCTAssertTrue(AIProvider.gemini.requiresAPIKey)

        XCTAssertEqual(AIProvider.anthropic.defaultModel, "claude-3-5-haiku-latest")
        XCTAssertTrue(AIProvider.anthropic.requiresAPIKey)

        XCTAssertEqual(AIProvider.openai.defaultModel, "gpt-4o-mini")
        XCTAssertTrue(AIProvider.openai.requiresAPIKey)
    }

    func testAISettingsPersistenceAndDefaults() {
        let defaultSettings = AISettings()
        XCTAssertFalse(defaultSettings.enabled)
        XCTAssertEqual(defaultSettings.provider, .ollama)
        XCTAssertEqual(defaultSettings.endpointURL, "http://localhost:11434")
        XCTAssertEqual(defaultSettings.activeModel, "llama3.2")
        XCTAssertFalse(defaultSettings.deepReasoning)

        let customSettings = AISettings(
            enabled: true,
            provider: .gemini,
            apiKey: "test-gemini-key",
            customModelName: "gemini-2.5-flash-lite",
            deepReasoning: true
        )
        XCTAssertTrue(customSettings.enabled)
        XCTAssertEqual(customSettings.activeModel, "gemini-2.5-flash-lite")
        XCTAssertTrue(customSettings.deepReasoning)

        // Test JSON round-trip
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(customSettings),
              let decoded = try? decoder.decode(AISettings.self, from: data) else {
            XCTFail("Failed to encode/decode AISettings")
            return
        }

        XCTAssertEqual(decoded.enabled, customSettings.enabled)
        XCTAssertEqual(decoded.provider, customSettings.provider)
        XCTAssertEqual(decoded.apiKey, customSettings.apiKey)
        XCTAssertEqual(decoded.activeModel, customSettings.activeModel)
        XCTAssertEqual(decoded.deepReasoning, customSettings.deepReasoning)

        // Test backward compatibility: JSON missing deepReasoning field
        let legacyJSON = """
        {"enabled":true,"provider":"Google Gemini","apiKey":"test","endpointURL":"http://localhost:11434","customModelName":""}
        """
        guard let legacyData = legacyJSON.data(using: .utf8),
              let legacyDecoded = try? decoder.decode(AISettings.self, from: legacyData) else {
            XCTFail("Failed to decode legacy AISettings JSON without deepReasoning")
            return
        }
        XCTAssertFalse(legacyDecoded.deepReasoning)
    }

    func testResponseParsingPureJSON() {
        let service = AIAdvisorService()
        let sample = """
        {
          "classification": "Routine",
          "summary": "Espressif device paired on local subnet with web captive portal active.",
          "recommendations": [
            "Verify IP 192.168.86.240 on DHCP table.",
            "Lock into baseline if recognized."
          ]
        }
        """

        let result = service.parseAnalysisResponse(text: sample, providerName: "Ollama (Local)", modelName: "llama3.2")
        XCTAssertEqual(result.classification, "Routine")
        XCTAssertEqual(result.summary, "Espressif device paired on local subnet with web captive portal active.")
        XCTAssertEqual(result.recommendations.count, 2)
        XCTAssertEqual(result.recommendations.first, "Verify IP 192.168.86.240 on DHCP table.")
    }

    func testResponseParsingMarkdownFencedJSON() {
        let service = AIAdvisorService()
        let sample = """
        ```json
        {
          "classification": "Suspicious",
          "summary": "Unknown port 53 listening on non-gateway host.",
          "recommendations": [
            "Run nmap -sV 192.168.86.10 to inspect service banner.",
            "Check iptables on target node."
          ]
        }
        ```
        """

        let result = service.parseAnalysisResponse(text: sample, providerName: "Google Gemini", modelName: "gemini-2.5-flash")
        XCTAssertEqual(result.classification, "Suspicious")
        XCTAssertEqual(result.summary, "Unknown port 53 listening on non-gateway host.")
        XCTAssertEqual(result.recommendations.count, 2)
    }

    func testResponseParsingFallbackText() {
        let service = AIAdvisorService()
        let plain = "Looks like a normal printer reboot. No rogue ports detected."

        let result = service.parseAnalysisResponse(text: plain, providerName: "OpenAI", modelName: "gpt-4o-mini")
        XCTAssertEqual(result.classification, "Expected")
        XCTAssertEqual(result.summary, plain)
        XCTAssertFalse(result.recommendations.isEmpty)
    }

    func testAIKeyResolverClean() {
        XCTAssertEqual(AIKeyResolver.clean("  sk-test-12345  "), "sk-test-12345")
        XCTAssertEqual(AIKeyResolver.clean("\"op://Private/Stash Gemini/password\""), "op://Private/Stash Gemini/password")
        XCTAssertEqual(AIKeyResolver.clean("'op://Vault/Item/field'"), "op://Vault/Item/field")
        XCTAssertEqual(AIKeyResolver.clean("`op://Vault/Item/field`"), "op://Vault/Item/field")
        XCTAssertEqual(AIKeyResolver.clean("\"'op://Vault/Item/field'\""), "op://Vault/Item/field")
    }

    func testAIKeyResolverIsReference() {
        XCTAssertTrue(AIKeyResolver.isReference("op://Private/Item/password"))
        XCTAssertTrue(AIKeyResolver.isReference("\"op://Private/Item/password\""))
        XCTAssertTrue(AIKeyResolver.isReference("  OP://vault/item/field  "))
        XCTAssertFalse(AIKeyResolver.isReference("sk-ant-api03-12345"))
        XCTAssertFalse(AIKeyResolver.isReference("http://localhost:11434"))
        XCTAssertFalse(AIKeyResolver.isReference(""))
    }

    func testAIKeyResolverPassthroughPlainKey() async throws {
        let plain = "sk-plain-test-key"
        let resolved = try await AIKeyResolver.resolve(plain)
        XCTAssertEqual(resolved, plain)

        let quotedPlain = "\"sk-quoted-key\""
        let resolvedQuoted = try await AIKeyResolver.resolve(quotedPlain)
        XCTAssertEqual(resolvedQuoted, "sk-quoted-key")
    }

    func testResponseParsingTruncatedJSONFallback() {
        let service = AIAdvisorService()

        // Test single opening brace (the exact truncation symptom)
        let singleBrace = "{\n"
        let res1 = service.parseAnalysisResponse(text: singleBrace, providerName: "Google Gemini", modelName: "gemini-2.5-flash")
        XCTAssertEqual(res1.classification, "Expected")
        XCTAssertEqual(res1.summary, "Analysis completed. Review detected network changes below.")
        XCTAssertFalse(res1.summary.contains("{"))

        // Test incomplete JSON cut off midway
        let cutOff = "{\"classification\": \"Routine\", \"summary\": \"Incom"
        let res2 = service.parseAnalysisResponse(text: cutOff, providerName: "Google Gemini", modelName: "gemini-2.5-flash")
        XCTAssertEqual(res2.classification, "Expected")
        XCTAssertEqual(res2.summary, "Analysis completed. Review detected network changes below.")
        XCTAssertFalse(res2.summary.contains("{"))
    }

    func testResponseParsingDynamicKeys() {
        let service = AIAdvisorService()
        let sample = """
        {
          "status": "Suspicious",
          "explanation": "Multiple unexpected open ports detected on IoT device.",
          "actions": ["Isolate device on VLAN", "Review firewall logs"]
        }
        """

        let result = service.parseAnalysisResponse(text: sample, providerName: "Ollama (Local)", modelName: "llama3.2")
        XCTAssertEqual(result.classification, "Suspicious")
        XCTAssertEqual(result.summary, "Multiple unexpected open ports detected on IoT device.")
        XCTAssertEqual(result.recommendations.count, 2)
        XCTAssertEqual(result.recommendations.first, "Isolate device on VLAN")
    }

    func testAIAnalysisResultDeepReasoningPersistence() {
        let result = AIAnalysisResult(
            classification: "Suspicious",
            summary: "Potential ARP spoofing between host and gateway.",
            recommendations: ["Check ARP table", "Verify gateway MAC"],
            providerName: "Google Gemini",
            modelName: "gemini-2.5-flash",
            isDeepReasoning: true
        )
        XCTAssertTrue(result.isDeepReasoning)

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        guard let data = try? encoder.encode(result),
              let decoded = try? decoder.decode(AIAnalysisResult.self, from: data) else {
            XCTFail("Failed to encode/decode AIAnalysisResult with isDeepReasoning")
            return
        }
        XCTAssertTrue(decoded.isDeepReasoning)
        XCTAssertEqual(decoded.classification, result.classification)

        // Backward compatibility: JSON missing isDeepReasoning field
        let legacyJSON = """
        {"id":"test-id","classification":"Routine","summary":"Normal host.","recommendations":[],"timestamp":1700000000,"providerName":"Ollama","modelName":"llama3.2"}
        """
        guard let legacyData = legacyJSON.data(using: .utf8),
              let legacyDecoded = try? decoder.decode(AIAnalysisResult.self, from: legacyData) else {
            XCTFail("Failed to decode legacy AIAnalysisResult JSON without isDeepReasoning")
            return
        }
        XCTAssertFalse(legacyDecoded.isDeepReasoning)
    }
}
