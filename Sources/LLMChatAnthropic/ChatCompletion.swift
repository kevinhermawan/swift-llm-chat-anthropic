//
//  ChatCompletion.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 9/29/24.
//

import Foundation

/// A struct that represents a chat completion response.
public struct ChatCompletion: Decodable, Sendable {
    /// A unique identifier for the chat completion.
    public let id: String
    
    /// The model used for the chat completion.
    public let model: String
    
    /// The role of the chat participant for this completion.
    public let role: String
    
    /// An array of contents in the chat completion.
    public let content: [Content]
    
    /// The reason that the chat completion stopped.
    public let stopReason: String?
    
    /// The sequence that caused the chat completion to stop.
    public let stopSequence: String?
    
    /// Usage statistics for the chat completion.
    public let usage: Usage?
    
    /// A struct that represents a content in the chat completion.
    public struct Content: Decodable, Sendable {
        /// The type of the content element.
        public let type: String
        
        /// The text content.
        public let text: String?
        
        /// The name of the tool.
        public let toolName: String?
        
        /// The tool input.
        public let toolInput: String?
        
        public init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            type = try container.decode(String.self, forKey: .type)
            text = try container.decodeIfPresent(String.self, forKey: .text)
            toolName = try container.decodeIfPresent(String.self, forKey: .toolName)
            
            if let toolValue = try? container.decodeIfPresent(JSON.self, forKey: .toolInput) {
                toolInput = toolValue.stringValue
            } else {
                toolInput = nil
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case type, text, toolName = "name", toolInput = "input"
        }
    }
    
    /// A struct that represents usage statistics for the chat completion.
    public struct Usage: Decodable, Sendable {
        /// The number of input tokens used.
        public let inputTokens: Int
        
        /// The number of output tokens generated.
        public let outputTokens: Int
        
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

private struct JSON: Decodable {
    let value: Any
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) {
            value = intVal
        } else if let doubleVal = try? container.decode(Double.self) {
            value = doubleVal
        } else if let boolVal = try? container.decode(Bool.self) {
            value = boolVal
        } else if let stringVal = try? container.decode(String.self) {
            value = stringVal
        } else if let arrayVal = try? container.decode([JSON].self) {
            value = arrayVal.map { $0.value }
        } else if let dictVal = try? container.decode([String: JSON].self) {
            value = dictVal.mapValues { $0.value }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Invalid value")
        }
    }
    
    var stringValue: String {
        if JSONSerialization.isValidJSONObject(value) {
            if let data = try? JSONSerialization.data(withJSONObject: value, options: [.sortedKeys]), let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        
        return String(describing: value)
    }
}
