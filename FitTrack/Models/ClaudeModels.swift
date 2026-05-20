import Foundation

struct ClaudeRequest: Encodable {
    let model: String
    let max_tokens: Int
    let messages: [ClaudeMessage]

    init(prompt: String, maxTokens: Int = 4096) {
        self.model = "claude-haiku-4-5-20251001"
        self.max_tokens = maxTokens
        self.messages = [ClaudeMessage(role: "user", content: prompt)]
    }
}

struct ClaudeMessage: Codable {
    let role: String
    let content: String
}

struct ClaudeResponse: Decodable {
    let content: [ContentBlock]
    let usage: Usage?
}

struct ContentBlock: Decodable {
    let type: String
    let text: String
}

struct Usage: Decodable {
    let input_tokens: Int
    let output_tokens: Int
}
