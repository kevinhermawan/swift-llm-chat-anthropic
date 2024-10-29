//
//  ChatOptions.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 9/29/24.
//

import Foundation
import JSONSchema

/// A struct that represents the options of a chat completion request.
public struct ChatOptions: Encodable, Sendable {
    /// The maximum number of tokens to generate.
    public let maxTokens: Int?
    
    /// Sequences that will cause the model to stop generating further tokens.
    public let stopSequences: [String]?
    
    /// Controls randomness: lowering results in less random completions.
    public let temperature: Double?
    
    /// The number of highest probability vocabulary tokens to keep for top-k-filtering.
    public let topK: Int?
    
    /// The cumulative probability of parameter highest probability vocabulary tokens to keep for nucleus sampling.
    public let topP: Double?
    
    /// The list of tools available for the model to use.
    public let tools: [Tool]?
    
    /// The tool choice for the model.
    public let toolChoice: ToolChoice?
    
    /// The user identifier for the request.
    public let userId: String?
    
    /// Creates a new instance of ``ChatOptions``.
    /// - Parameters:
    ///   - maxTokens: The maximum number of tokens to generate.
    ///   - stopSequences: Sequences that will cause the model to stop generating further tokens.
    ///   - temperature: Controls randomness: lowering results in less random completions.
    ///   - topK: The number of highest probability vocabulary tokens to keep for top-k-filtering.
    ///   - topP: The cumulative probability of parameter highest probability vocabulary tokens to keep for nucleus sampling.
    ///   - tools: The list of tools available for the model to use.
    ///   - toolChoice: The tool choice for the model.
    ///   - userId: The user identifier for the request.
    public init(
        maxTokens: Int? = nil,
        stopSequences: [String]? = nil,
        temperature: Double? = nil,
        topK: Int? = nil,
        topP: Double? = nil,
        tools: [Tool]? = nil,
        toolChoice: ToolChoice? = nil,
        userId: String? = nil
    ) {
        self.maxTokens = maxTokens
        self.stopSequences = stopSequences
        self.temperature = temperature
        self.topK = topK
        self.topP = topP
        self.tools = tools
        self.toolChoice = toolChoice
        self.userId = userId
    }
    
    /// A struct that represents a tool available for the model to use.
    public struct Tool: Encodable, Sendable {
        /// The name of the tool.
        public let name: String
        
        /// A description of the tool.
        public let description: String?
        
        /// The parameters for the tool.
        public let parameters: JSONSchema
        
        /// Creates a new instance of ``Tool``.
        /// - Parameters:
        ///   - name: The name of the tool.
        ///   - description: A description of the tool.
        ///   - parameters: The parameters for the tool.
        public init(name: String, description: String? = nil, parameters: JSONSchema) {
            self.name = name
            self.description = description
            self.parameters = parameters
        }
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(name, forKey: .name)
            try container.encodeIfPresent(description, forKey: .description)
            try container.encode(parameters, forKey: .parameters)
        }
        
        private enum CodingKeys: String, CodingKey {
            case name, description
            case parameters = "input_schema"
        }
    }
    
    /// An enum that represents the tool choice for the model.
    public enum ToolChoice: Encodable, Sendable {
        /// Allows the model to use any available tool.
        case any
        
        /// Lets the model automatically decide whether to use a tool.
        case auto
        
        /// Specifies a particular tool for the model to use.
        case tool(name: String)
        
        public func encode(to encoder: Encoder) throws {
            switch self {
            case .any:
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("any", forKey: .type)
            case .auto:
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("auto", forKey: .type)
            case .tool(let name):
                var container = encoder.container(keyedBy: CodingKeys.self)
                try container.encode("tool", forKey: .type)
                try container.encode(name, forKey: .name)
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case type, name
        }
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        try container.encodeIfPresent(stopSequences, forKey: .stopSequences)
        try container.encodeIfPresent(temperature, forKey: .temperature)
        try container.encodeIfPresent(topK, forKey: .topK)
        try container.encodeIfPresent(topP, forKey: .topP)
        try container.encodeIfPresent(tools, forKey: .tools)
        try container.encodeIfPresent(toolChoice, forKey: .toolChoice)
        
        if let userId {
            var metadataContainer = container.nestedContainer(keyedBy: MetadataCodingKeys.self, forKey: .metadata)
            try metadataContainer.encode(userId, forKey: .userId)
        }
    }
    
    private enum CodingKeys: String, CodingKey {
        case stopSequences = "stop_sequences"
        case temperature
        case topK = "top_k"
        case topP = "top_p"
        case tools
        case toolChoice = "tool_choice"
        case metadata
    }
    
    private enum MetadataCodingKeys: String, CodingKey {
        case userId = "user_id"
    }
}
