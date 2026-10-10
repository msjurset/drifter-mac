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

        let customSettings = AISettings(
            enabled: true,
            provider: .gemini,
            apiKey: "test-gemini-key",
            customModelName: "gemini-2.5-flash-lite"
        )
        XCTAssertTrue(customSettings.enabled)
        XCTAssertEqual(customSettings.activeModel, "gemini-2.5-flash-lite")

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
}
