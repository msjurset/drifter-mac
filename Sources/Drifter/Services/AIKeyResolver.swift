import Foundation

/// Resolves API key field values. Pass-through for plain strings;
/// shells out to `op read` for `op://` references so the actual
/// secret never lives in UserDefaults / JSON storage — only the 1Password reference
/// does. Resolution happens just before every network call.
public enum AIKeyResolver {
    public enum ResolverError: LocalizedError, Sendable {
        case opNotFound
        case opFailed(stderr: String, exit: Int32)

        public var errorDescription: String? {
            switch self {
            case .opNotFound:
                return "1Password CLI (`op`) not found. Install with `brew install 1password-cli` and sign in via `op signin`."
            case .opFailed(let stderr, let exit):
                let snippet = stderr.count > 240 ? String(stderr.prefix(240)) + "…" : stderr
                let trimmed = snippet.trimmingCharacters(in: .whitespacesAndNewlines)
                return "`op read` failed (exit \(exit)): \(trimmed.isEmpty ? "no stderr" : trimmed)"
            }
        }
    }

    /// If `raw` is an `op://vault/item/field` reference, runs `op
    /// read` to fetch the actual secret. Otherwise returns the
    /// cleaned input as-is (whitespace + surrounding quotes stripped).
    ///
    /// **Caching**: resolved `op://` secrets are kept in an
    /// in-memory cache keyed by the reference string, for the
    /// lifetime of the running app process. Without it every
    /// triage call (and every Test click in Settings) shells
    /// out to `op read`, which triggers a Touch ID prompt — a
    /// rapid burst of calls means a burst of prompts. The
    /// cache preserves the security property "secret never lives
    /// in Drifter storage on disk" while removing the per-call
    /// auth tax inside one launch. Cache is cleared when the
    /// user changes the key in Settings.
    public static func resolve(_ raw: String) async throws -> String {
        let cleaned = clean(raw)
        guard cleaned.lowercased().hasPrefix("op://") else { return cleaned }

        if let cached = await ResolvedKeyCache.shared.get(cleaned) {
            return cached
        }
        guard let opPath = findOpBinary() else {
            throw ResolverError.opNotFound
        }
        let resolved = try await runOpRead(opPath: opPath, reference: cleaned)
        await ResolvedKeyCache.shared.set(cleaned, value: resolved)
        return resolved
    }

    /// Drop any cached resolved values. Call when the key is updated or saved.
    public static func clearCache() async {
        await ResolvedKeyCache.shared.clear()
    }

    /// True when the value is a 1Password reference.
    public static func isReference(_ raw: String) -> Bool {
        clean(raw).lowercased().hasPrefix("op://")
    }

    /// Normalised version of a pasted field value: outer whitespace
    /// and any layers of matched surrounding single / double / back-tick quotes stripped.
    public static func clean(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        while s.count >= 2, let first = s.first, let last = s.last,
              first == last,
              first == "\"" || first == "'" || first == "`" {
            s = String(s.dropFirst().dropLast()).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return s
    }

    /// Probe whether the 1Password CLI is installed.
    public static var opAvailable: Bool { findOpBinary() != nil }

    public static func findOpBinary() -> String? {
        // GUI apps don't inherit the user's shell PATH — search
        // the well-known install locations explicitly.
        let candidates = [
            "/opt/homebrew/bin/op",
            "/usr/local/bin/op",
            "/Applications/1Password.app/Contents/MacOS/op",
        ]
        for path in candidates where FileManager.default.isExecutableFile(atPath: path) {
            return path
        }
        return nil
    }

    private static func runOpRead(opPath: String, reference: String) async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    let proc = Process()
                    proc.executableURL = URL(fileURLWithPath: opPath)
                    proc.arguments = ["read", "--no-newline", reference]
                    let outPipe = Pipe()
                    let errPipe = Pipe()
                    proc.standardOutput = outPipe
                    proc.standardError = errPipe
                    try proc.run()
                    proc.waitUntilExit()
                    let outData = outPipe.fileHandleForReading.readDataToEndOfFile()
                    let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
                    if proc.terminationStatus != 0 {
                        let stderr = String(data: errData, encoding: .utf8) ?? ""
                        continuation.resume(throwing: ResolverError.opFailed(stderr: stderr, exit: proc.terminationStatus))
                        return
                    }
                    let secret = (String(data: outData, encoding: .utf8) ?? "")
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    continuation.resume(returning: secret)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}

/// In-memory cache for resolved `op://` secrets.
private actor ResolvedKeyCache {
    static let shared = ResolvedKeyCache()

    private var entries: [String: String] = [:]

    func get(_ reference: String) -> String? { entries[reference] }
    func set(_ reference: String, value: String) { entries[reference] = value }
    func clear() { entries.removeAll() }
}
