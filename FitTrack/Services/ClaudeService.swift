import Foundation

enum ClaudeError: Error, LocalizedError {
    case invalidApiKey
    case rateLimited
    case badRequest(String)
    case apiError(Int, String)
    case emptyResponse
    case networkError(String)

    var errorDescription: String? {
        switch self {
        case .invalidApiKey: return "Invalid API key (401)"
        case .rateLimited: return "Rate limit exceeded — try again shortly"
        case .badRequest(let msg): return "Bad request: \(msg)"
        case .apiError(let code, let msg): return "API error \(code): \(msg)"
        case .emptyResponse: return "Empty response from Claude"
        case .networkError(let msg): return "Network error: \(msg)"
        }
    }
}

class ClaudeService {
    static let shared = ClaudeService()

    private let baseURL = URL(string: "https://api.anthropic.com/v1/messages")!

    func send(apiKey: String, prompt: String, maxTokens: Int = 4096) async throws -> String {
        // Client-side rate limiting — prevents burst usage and runaway API key drain.
        try await RateLimiter.shared.checkAndRecord()

        var request = URLRequest(url: baseURL, timeoutInterval: 90)
        request.httpMethod = "POST"
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = ClaudeRequest(prompt: prompt, maxTokens: maxTokens)
        request.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ClaudeError.networkError("Invalid response")
        }

        guard http.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8) ?? ""
            switch http.statusCode {
            case 401: throw ClaudeError.invalidApiKey
            case 429: throw ClaudeError.rateLimited
            case 400: throw ClaudeError.badRequest(body)
            default:  throw ClaudeError.apiError(http.statusCode, body)
            }
        }

        let decoded = try JSONDecoder().decode(ClaudeResponse.self, from: data)
        guard let text = decoded.content.first?.text else {
            throw ClaudeError.emptyResponse
        }
        return text
    }

    func extractJson(_ text: String) -> String {
        guard let start = text.firstIndex(of: "{"),
              let end = text.lastIndex(of: "}"),
              start < end else { return text }
        return String(text[start...end])
    }
}
