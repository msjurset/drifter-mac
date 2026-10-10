import Foundation

public enum AIAdvisorError: LocalizedError, Sendable {
    case disabled
    case missingAPIKey(AIProvider)
    case invalidEndpoint(String)
    case apiError(Int, String)
    case invalidResponse(String)

    public var errorDescription: String? {
        switch self {
        case .disabled:
            return "AI Security Advisor is currently disabled in Settings."
        case .missingAPIKey(let provider):
            return "An API key is required for \(provider.rawValue). Please configure it in Settings."
        case .invalidEndpoint(let url):
            return "Invalid endpoint URL: \(url)"
        case .apiError(let code, let message):
            return "API Error (\(code)): \(message)"
        case .invalidResponse(let detail):
            return "Could not parse advisor response: \(detail)"
        }
    }
}

public struct AIAnalysisResult: Codable, Equatable, Sendable, Identifiable {
    public var id: String
    public var classification: String // "Routine", "Expected", or "Suspicious"
    public var summary: String
    public var recommendations: [String]
    public var timestamp: Date
    public var providerName: String
    public var modelName: String

    public init(id: String = UUID().uuidString,
                classification: String,
                summary: String,
                recommendations: [String],
                timestamp: Date = Date(),
                providerName: String,
                modelName: String) {
        self.id = id
        self.classification = classification
        self.summary = summary
        self.recommendations = recommendations
        self.timestamp = timestamp
        self.providerName = providerName
        self.modelName = modelName
    }
}

public final class AIAdvisorService: Sendable {
    public static let shared = AIAdvisorService()

    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    /// Verifies provider connectivity and API key validity with a lightweight ping
    public func testConnection(settings: AISettings) async throws -> String {
        let effectiveSettings = try await resolveEffectiveSettings(settings)

        let systemPrompt = "Respond with strictly valid JSON: {\"status\": \"ok\", \"message\": \"Drifter Advisor connected\"}"
        let userPrompt = "Ping test"

        let responseText = try await dispatchQuery(
            systemPrompt: systemPrompt,
            userPrompt: userPrompt,
            settings: effectiveSettings,
            maxTokens: 100
        )

        if responseText.contains("ok") || responseText.contains("connected") || responseText.contains("status") {
            return "Connected successfully to \(settings.provider.rawValue) (\(settings.activeModel))"
        }
        return "Received response from \(settings.provider.rawValue)"
    }

    /// Synthesizes active drift alerts into a high-level security triage
    public func triageDriftAlerts(events: [DriftEvent], hosts: [HostItem], settings: AISettings) async throws -> AIAnalysisResult {
        guard settings.enabled else {
            throw AIAdvisorError.disabled
        }

        let unackEvents = events.filter { !$0.acknowledged }
        guard !unackEvents.isEmpty else {
            return AIAnalysisResult(
                classification: "Routine",
                summary: "Network baseline is clean. No unacknowledged drift alerts require investigation.",
                recommendations: ["Maintain periodic background scanning cadence."],
                providerName: settings.provider.rawValue,
                modelName: settings.activeModel
            )
        }

        let effectiveSettings = try await resolveEffectiveSettings(settings)

        // Build compact JSON payload
        var eventItems: [[String: Any]] = []
        for event in unackEvents.prefix(10) {
            let matchedHost = hosts.first(where: { $0.id == event.hostId || $0.ip == event.hostIp })
            let item: [String: Any] = [
                "ip": event.hostIp,
                "hostname": event.hostname.isEmpty ? (matchedHost?.hostname ?? "") : event.hostname,
                "vendor": matchedHost?.vendor ?? "Unknown",
                "category": matchedHost?.category ?? "unknown",
                "drift_type": event.type,
                "detail": event.detail
            ]
            eventItems.append(item)
        }

        let payloadData = try JSONSerialization.data(withJSONObject: [
            "active_drift_events": eventItems,
            "total_monitored_hosts": hosts.count
        ], options: [])
        let jsonInput = String(decoding: payloadData, as: UTF8.self)

        let systemPrompt = """
        You are Drifter AI Advisor, a local network security auditor for homelab and IoT subnets.
        Analyze the provided network drift events. Determine whether the shifts reflect routine homelab activity (e.g. smart bulb pairing, reboot, standard web port) or an anomaly requiring inspection.
        Return ONLY valid JSON in this exact structure with no markdown code blocks:
        {
          "classification": "Routine" | "Expected" | "Suspicious",
          "summary": "1 to 2 concise sentences explaining the vendor context and significance of the changes.",
          "recommendations": ["Actionable verification step or command 1", "Actionable verification step or command 2"]
        }
        """

        let responseText = try await dispatchQuery(
            systemPrompt: systemPrompt,
            userPrompt: jsonInput,
            settings: effectiveSettings,
            maxTokens: 2048
        )

        return parseAnalysisResponse(
            text: responseText,
            providerName: settings.provider.rawValue,
            modelName: settings.activeModel
        )
    }

    /// Evaluates the security posture and open ports of an individual host
    public func analyzeHostSecurity(host: HostItem, events: [DriftEvent], settings: AISettings) async throws -> AIAnalysisResult {
        let effectiveSettings = try await resolveEffectiveSettings(settings)

        let hostEvents = events.filter { $0.hostId == host.id || $0.hostIp == host.ip }
        let payload: [String: Any] = [
            "ip": host.ip,
            "mac": host.mac,
            "hostname": host.hostname,
            "vendor": host.vendor,
            "category": host.category,
            "open_ports": host.openPorts,
            "baseline_ports": host.baselinePorts ?? [],
            "approved_host": host.isApprovedHost,
            "mdns_services": host.mdnsServices,
            "recent_events": hostEvents.prefix(5).map { ["type": $0.type, "detail": $0.detail] }
        ]

        let payloadData = try JSONSerialization.data(withJSONObject: payload, options: [])
        let jsonInput = String(decoding: payloadData, as: UTF8.self)

        let systemPrompt = """
        You are Drifter AI Advisor. Audit the security profile of this local network host.
        Identify any unexpected ports, missing service baselines, or vulnerabilities typical for this hardware vendor.
        Return ONLY valid JSON in this exact structure with no markdown code blocks:
        {
          "classification": "Routine" | "Expected" | "Suspicious",
          "summary": "1 to 2 concise sentences assessing this host's current posture.",
          "recommendations": ["Actionable verification step 1", "Actionable verification step 2"]
        }
        """

        let responseText = try await dispatchQuery(
            systemPrompt: systemPrompt,
            userPrompt: jsonInput,
            settings: effectiveSettings,
            maxTokens: 2048
        )

        return parseAnalysisResponse(
            text: responseText,
            providerName: settings.provider.rawValue,
            modelName: settings.activeModel
        )
    }

    private func resolveEffectiveSettings(_ settings: AISettings) async throws -> AISettings {
        guard settings.enabled else {
            throw AIAdvisorError.disabled
        }
        var effective = settings
        if effective.provider.requiresAPIKey {
            let cleaned = AIKeyResolver.clean(effective.apiKey)
            guard !cleaned.isEmpty else {
                throw AIAdvisorError.missingAPIKey(effective.provider)
            }
            effective.apiKey = try await AIKeyResolver.resolve(cleaned)
        }
        return effective
    }

    // MARK: - Provider Query Dispatching

    private func dispatchQuery(systemPrompt: String, userPrompt: String, settings: AISettings, maxTokens: Int) async throws -> String {
        switch settings.provider {
        case .ollama:
            return try await queryOllama(systemPrompt: systemPrompt, userPrompt: userPrompt, settings: settings)
        case .gemini:
            return try await queryGemini(systemPrompt: systemPrompt, userPrompt: userPrompt, settings: settings, maxTokens: maxTokens)
        case .anthropic:
            return try await queryAnthropic(systemPrompt: systemPrompt, userPrompt: userPrompt, settings: settings, maxTokens: maxTokens)
        case .openai:
            return try await queryOpenAI(systemPrompt: systemPrompt, userPrompt: userPrompt, settings: settings, maxTokens: maxTokens)
        }
    }

    // MARK: - Ollama Implementation

    private func queryOllama(systemPrompt: String, userPrompt: String, settings: AISettings) async throws -> String {
        guard let url = URL(string: "\(settings.endpointURL.trimmingCharacters(in: CharacterSet(charactersIn: "/")))/api/chat") else {
            throw AIAdvisorError.invalidEndpoint(settings.endpointURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "model": settings.activeModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "stream": false,
            "format": "json"
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAdvisorError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(decoding: data, as: UTF8.self)
            throw AIAdvisorError.apiError(httpResponse.statusCode, errorText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let message = json["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIAdvisorError.invalidResponse("Missing 'message.content' in Ollama response")
        }

        return content
    }

    // MARK: - Google Gemini Implementation

    private func queryGemini(systemPrompt: String, userPrompt: String, settings: AISettings, maxTokens: Int) async throws -> String {
        let model = settings.activeModel
        let key = settings.apiKey.trimmingCharacters(in: .whitespaces)
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(key)") else {
            throw AIAdvisorError.invalidEndpoint("Gemini URL construction failed")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        let combined = "\(systemPrompt)\n\nInput Data:\n\(userPrompt)"
        let genConfig: [String: Any] = [
            "responseMimeType": "application/json",
            "temperature": 0.2,
            "maxOutputTokens": max(maxTokens, 2048)
        ]

        let body: [String: Any] = [
            "contents": [
                [
                    "role": "user",
                    "parts": [["text": combined]]
                ]
            ],
            "generationConfig": genConfig
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAdvisorError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(decoding: data, as: UTF8.self)
            throw AIAdvisorError.apiError(httpResponse.statusCode, errorText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let candidates = json["candidates"] as? [[String: Any]],
              let firstCandidate = candidates.first,
              let content = firstCandidate["content"] as? [String: Any],
              let parts = content["parts"] as? [[String: Any]],
              let firstPart = parts.first,
              let text = firstPart["text"] as? String else {
            throw AIAdvisorError.invalidResponse("Malformed Gemini response structure")
        }

        return text
    }

    // MARK: - Anthropic Implementation

    private func queryAnthropic(systemPrompt: String, userPrompt: String, settings: AISettings, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "https://api.anthropic.com/v1/messages") else {
            throw AIAdvisorError.invalidEndpoint("Anthropic URL construction failed")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(settings.apiKey.trimmingCharacters(in: .whitespaces), forHTTPHeaderField: "x-api-key")
        request.addValue("2023-06-01", forHTTPHeaderField: "anthropic-version")

        let body: [String: Any] = [
            "model": settings.activeModel,
            "max_tokens": maxTokens,
            "system": systemPrompt,
            "messages": [
                ["role": "user", "content": userPrompt]
            ]
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAdvisorError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(decoding: data, as: UTF8.self)
            throw AIAdvisorError.apiError(httpResponse.statusCode, errorText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let contentArray = json["content"] as? [[String: Any]],
              let firstBlock = contentArray.first,
              let text = firstBlock["text"] as? String else {
            throw AIAdvisorError.invalidResponse("Malformed Anthropic response structure")
        }

        return text
    }

    // MARK: - OpenAI Implementation

    private func queryOpenAI(systemPrompt: String, userPrompt: String, settings: AISettings, maxTokens: Int) async throws -> String {
        guard let url = URL(string: "https://api.openai.com/v1/chat/completions") else {
            throw AIAdvisorError.invalidEndpoint("OpenAI URL construction failed")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("Bearer \(settings.apiKey.trimmingCharacters(in: .whitespaces))", forHTTPHeaderField: "Authorization")

        let body: [String: Any] = [
            "model": settings.activeModel,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user", "content": userPrompt]
            ],
            "response_format": ["type": "json_object"],
            "max_tokens": maxTokens
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIAdvisorError.invalidResponse("Invalid HTTP response")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            let errorText = String(decoding: data, as: UTF8.self)
            throw AIAdvisorError.apiError(httpResponse.statusCode, errorText)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let choices = json["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let text = message["content"] as? String else {
            throw AIAdvisorError.invalidResponse("Malformed OpenAI response structure")
        }

        return text
    }

    // MARK: - Response Parsing

    public func parseAnalysisResponse(text: String, providerName: String, modelName: String) -> AIAnalysisResult {
        // Strip potential markdown code fences
        var sanitized = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("```json") {
            sanitized = String(sanitized.dropFirst(7))
        } else if sanitized.hasPrefix("```") {
            sanitized = String(sanitized.dropFirst(3))
        }
        if sanitized.hasSuffix("```") {
            sanitized = String(sanitized.dropLast(3))
        }
        sanitized = sanitized.trimmingCharacters(in: .whitespacesAndNewlines)

        struct ParsedDTO: Codable {
            let classification: String?
            let summary: String?
            let recommendations: [String]?
        }

        if let data = sanitized.data(using: .utf8) {
            if let dto = try? JSONDecoder().decode(ParsedDTO.self, from: data),
               (dto.classification != nil || dto.summary != nil || dto.recommendations != nil) {
                let classification = dto.classification?.trimmingCharacters(in: .whitespaces) ?? "Expected"
                let summary = dto.summary?.trimmingCharacters(in: .whitespaces) ?? "Analysis completed."
                let recommendations = dto.recommendations?.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty } ?? []

                return AIAnalysisResult(
                    classification: classification.isEmpty ? "Expected" : classification,
                    summary: summary.isEmpty ? "Analysis completed." : summary,
                    recommendations: recommendations.isEmpty ? ["Continue routine subnet monitoring."] : recommendations,
                    providerName: providerName,
                    modelName: modelName
                )
            }

            if let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let rawClass = (dict["classification"] as? String)
                    ?? (dict["status"] as? String)
                    ?? (dict["category"] as? String)
                    ?? "Expected"
                let rawSummary = (dict["summary"] as? String)
                    ?? (dict["explanation"] as? String)
                    ?? (dict["description"] as? String)
                    ?? (dict["analysis"] as? String)
                    ?? "Analysis completed."
                let rawRecs = (dict["recommendations"] as? [String])
                    ?? (dict["actions"] as? [String])
                    ?? (dict["steps"] as? [String])
                    ?? []

                let classification = rawClass.trimmingCharacters(in: .whitespaces)
                let summary = rawSummary.trimmingCharacters(in: .whitespaces)
                let recommendations = rawRecs.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

                return AIAnalysisResult(
                    classification: classification.isEmpty ? "Expected" : classification,
                    summary: summary.isEmpty ? "Analysis completed." : summary,
                    recommendations: recommendations.isEmpty ? ["Continue routine subnet monitoring."] : recommendations,
                    providerName: providerName,
                    modelName: modelName
                )
            }
        }

        // Graceful fallback if model output was freeform text or truncated/malformed JSON
        let fallbackSummary: String
        if sanitized.isEmpty || sanitized.hasPrefix("{") || sanitized.hasPrefix("[") || sanitized.count < 5 {
            fallbackSummary = "Analysis completed. Review detected network changes below."
        } else {
            fallbackSummary = sanitized
        }

        return AIAnalysisResult(
            classification: "Expected",
            summary: fallbackSummary,
            recommendations: ["Review host open ports against network baseline."],
            providerName: providerName,
            modelName: modelName
        )
    }
}
