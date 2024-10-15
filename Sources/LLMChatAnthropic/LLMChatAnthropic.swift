//
//  LLMChatAnthropic.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 9/29/24.
//

import Foundation

/// A struct that facilitates interactions with Anthropic and Anthropic-compatible chat completion APIs.
public struct LLMChatAnthropic {
    private let apiKey: String
    private let endpoint: URL
    private var headers: [String: String]? = nil
    
    /// Creates a new instance of ``LLMChatAnthropic``.
    ///
    /// - Parameters:
    ///   - apiKey: Your Anthropic API key.
    ///   - endpoint: The Anthropic-compatible endpoint.
    ///   - headers: Additional HTTP headers to include in the requests.
    ///
    /// - Note: Make sure to include the complete URL for the `endpoint`, including the protocol (http:// or https://) and its path.
    public init(apiKey: String, endpoint: URL? = nil, headers: [String: String]? = nil) {
        self.apiKey = apiKey
        self.endpoint = endpoint ?? URL(string: "https://api.anthropic.com/v1/messages")!
        self.headers = headers
    }
}

extension LLMChatAnthropic {
    /// Sends a chat completion request.
    ///
    /// - Parameters:
    ///   - model: The model to use for completion.
    ///   - messages: An array of ``ChatMessage`` objects that represent the conversation history.
    ///   - options: Optional ``ChatOptions`` that customize the completion request.
    ///
    /// - Returns: A ``ChatCompletion`` object that contains the API's response.
    public func send(model: String, messages: [ChatMessage], options: ChatOptions? = nil) async throws -> ChatCompletion {
        let body = RequestBody(stream: false, model: model, messages: messages, options: options)
        let request = try createRequest(for: endpoint, with: body)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        try validateHTTPResponse(response)
        
        return try JSONDecoder().decode(ChatCompletion.self, from: data)
    }
    
    /// Streams a chat completion request.
    ///
    /// - Parameters:
    ///   - model: The model to use for completion.
    ///   - messages: An array of ``ChatMessage`` objects that represent the conversation history.
    ///   - options: Optional ``ChatOptions`` that customize the completion request.
    ///
    /// - Returns: An `AsyncThrowingStream` of ``ChatCompletionChunk`` objects.
    public func stream(model: String, messages: [ChatMessage], options: ChatOptions? = nil) -> AsyncThrowingStream<ChatCompletionChunk, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let body = RequestBody(stream: true, model: model, messages: messages, options: options)
                    let request = try createRequest(for: endpoint, with: body)
                    
                    let (bytes, response) = try await URLSession.shared.bytes(for: request)
                    try validateHTTPResponse(response)
                    
                    var currentChunk = ChatCompletionChunk(id: "", model: "", role: "")
                    
                    for try await line in bytes.lines {
                        if line.hasPrefix("data: ") {
                            let jsonData = line.dropFirst(6)
                            
                            if let data = jsonData.data(using: .utf8) {
                                let rawChunk = try JSONDecoder().decode(RawChatCompletionChunk.self, from: data)
                                
                                switch rawChunk.type {
                                case "message_start":
                                    if let message = rawChunk.message {
                                        currentChunk.id = message.id
                                        currentChunk.role = message.role
                                        currentChunk.model = message.model
                                        
                                        if let usage = message.usage, let inputTokens = usage.inputTokens, let outputTokens = usage.outputTokens {
                                            currentChunk.usage = ChatCompletionChunk.Usage(inputTokens: inputTokens, outputTokens: outputTokens)
                                        }
                                        
                                        continuation.yield(currentChunk)
                                    }
                                case "content_block_start":
                                    if let contentBlock = rawChunk.contentBlock {
                                        currentChunk.delta = ChatCompletionChunk.Delta(type: contentBlock.type, toolName: contentBlock.name)
                                        
                                        continuation.yield(currentChunk)
                                    }
                                case "content_block_delta":
                                    if let delta = rawChunk.delta {
                                        currentChunk.delta?.text = delta.text
                                        currentChunk.delta?.toolInput = delta.partialJson
                                        
                                        continuation.yield(currentChunk)
                                    }
                                case "message_delta":
                                    if let delta = rawChunk.delta {
                                        currentChunk.delta?.text = nil
                                        currentChunk.delta?.toolInput = nil
                                        currentChunk.stopReason = delta.stopReason
                                        currentChunk.stopSequence = delta.stopSequence
                                        
                                        if let outputTokens = rawChunk.usage?.outputTokens {
                                            currentChunk.usage?.outputTokens = outputTokens
                                        }
                                        
                                        continuation.yield(currentChunk)
                                    }
                                case "message_stop":
                                    continuation.finish()
                                default:
                                    break
                                }
                            }
                        }
                    }
                    
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}

// MARK: - Helper Methods
private extension LLMChatAnthropic {
    var allHeaders: [String: String] {
        var defaultHeaders = [
            "Anthropic-Version": "2023-06-01",
            "Content-Type": "application/json",
            "X-Api-Key": apiKey
        ]
        
        if let headers {
            defaultHeaders.merge(headers) { _, new in new }
        }
        
        return defaultHeaders
    }
    
    func createRequest(for url: URL, with body: RequestBody) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = try JSONEncoder().encode(body)
        request.allHTTPHeaderFields = allHeaders
        
        return request
    }
    
    func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse, 200...299 ~= httpResponse.statusCode else {
            throw URLError(.badServerResponse)
        }
    }
}

// MARK: - Supporting Types
private extension LLMChatAnthropic {
    struct RequestBody: Encodable {
        let stream: Bool
        let model: String
        let messages: [ChatMessage]
        let options: ChatOptions?
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(options?.maxTokens ?? 4096, forKey: .maxTokens)
            try container.encode(stream, forKey: .stream)
            try container.encode(model, forKey: .model)
            
            var systemMessages: [[String: String]] = []
            var nonSystemMessages: [ChatMessage] = []
            
            for message in messages {
                if message.role == .system {
                    for content in message.content {
                        if case .text(let text) = content {
                            var encodedContent: [String: String] = ["type": "text", "text": text]
                            
                            if let cacheControl = message.cacheControl {
                                encodedContent["cacheControl"] = cacheControl.type.rawValue
                            }
                            
                            systemMessages.append(encodedContent)
                        }
                    }
                } else {
                    nonSystemMessages.append(message)
                }
            }
            
            if systemMessages.isEmpty == false {
                try container.encode(systemMessages, forKey: .system)
            }
            
            try container.encode(nonSystemMessages, forKey: .messages)
            
            if let options {
                try options.encode(to: encoder)
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case stream, model
            case maxTokens = "max_tokens"
            case system, messages
        }
        
        enum ContentCodingKeys: String, CodingKey {
            case type, text
            case cacheControl = "cache_control"
        }
        
        enum CacheControlCodingKeys: String, CodingKey {
            case type
        }
    }
    
    struct RawChatCompletionChunk: Decodable {
        let type: String
        let message: Message?
        let contentBlock: ContentBlock?
        let delta: Delta?
        let usage: Usage?
        
        struct Message: Decodable {
            let id: String
            let type: String
            let role: String
            let model: String
            let usage: Usage?
        }
        
        struct ContentBlock: Decodable {
            let type: String
            let text: String?
            let name: String?
        }
        
        struct Delta: Decodable {
            let text: String?
            let partialJson: String?
            let stopReason: String?
            let stopSequence: String?
            
            enum CodingKeys: String, CodingKey {
                case text
                case partialJson = "partial_json"
                case stopReason = "stop_reason"
                case stopSequence = "stop_sequence"
            }
        }
        
        struct Usage: Decodable {
            let inputTokens: Int?
            let outputTokens: Int?
            
            enum CodingKeys: String, CodingKey {
                case inputTokens = "input_tokens"
                case outputTokens = "output_tokens"
            }
        }
        
        enum CodingKeys: String, CodingKey {
            case type, message
            case contentBlock = "content_block"
            case delta, usage
        }
    }
}
