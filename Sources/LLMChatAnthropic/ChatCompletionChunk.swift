//
//  ChatCompletionChunk.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 9/29/24.
//

import Foundation

/// A struct that represents a streamed chunk of a chat completion response.
public struct ChatCompletionChunk {
    /// A unique identifier for the chat completion.
    public var id: String
    
    /// The model used for the chat completion.
    public var model: String
    
    /// The role of the chat participant for this chunk.
    public var role: String
    
    /// The delta content for this chunk.
    public var delta: Delta?
    
    /// The reason that the chat completion stopped.
    public var stopReason: String?
    
    /// The sequence that caused the chat completion to stop.
    public var stopSequence: String?
    
    /// Usage statistics for the chat completion chunk.
    public var usage: Usage?
    
    /// A struct that represents the delta content in a chat completion chunk.
    public struct Delta: Decodable {
        /// The type of the delta content.
        public var type: String
        
        /// The text content.
        public var text: String?
        
        /// The name of the tool.
        public var toolName: String?
        
        /// The tool input.
        public var toolInput: String?
        
        private enum CodingKeys: String, CodingKey {
            case type, text, toolName = "name", toolInput = "input"
        }
    }
    
    /// A struct that represents usage statistics for the chat completion chunk.
    public struct Usage: Decodable {
        /// The number of input tokens used.
        public var inputTokens: Int
        
        /// The number of output tokens generated.
        public var outputTokens: Int
        
        /// The total number of tokens used (input + output).
        public var totalTokens: Int {
            inputTokens + outputTokens
        }
        
        private enum CodingKeys: String, CodingKey {
            case inputTokens = "input_tokens"
            case outputTokens = "output_tokens"
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case id, content, model, role
        case stopReason = "stop_reason"
        case stopSequence = "stop_sequence"
        case usage
    }
}
