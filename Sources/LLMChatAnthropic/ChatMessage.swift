//
//  ChatMessage.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 9/29/24.
//

import Foundation

/// A struct that represents a message in a chat conversation.
public struct ChatMessage: Encodable {
    /// The role of the participant in the chat conversation.
    public let role: Role
    
    /// The content of the message, which can be text or image.
    public let content: [Content]
    
    /// The cache control settings for the message. Only applicable when the role is `system`.
    public var cacheControl: CacheControl?
    
    /// An enum that represents the role of a participant in the chat.
    public enum Role: String, Codable {
        case system
        case user
        case assistant
    }
    
    /// An enum that represents the content of a chat message.
    public enum Content: Encodable {
        /// A case that represents text content.
        case text(String)
        
        /// A case that represents image content.
        case image(String)
        
        public func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            
            switch self {
            case .text(let text):
                try container.encode("text", forKey: .type)
                try container.encode(text, forKey: .text)
            case .image(let imageString):
                try container.encode("image", forKey: .type)
                var sourceContainer = container.nestedContainer(keyedBy: SourceCodingKeys.self, forKey: .source)
                
                if imageString.hasPrefix("http://") || imageString.hasPrefix("https://") {
                    let (base64String, mediaType) = Content.convertImageUrlToBase64(url: imageString)
                    try sourceContainer.encode("base64", forKey: .type)
                    try sourceContainer.encode(mediaType, forKey: .mediaType)
                    try sourceContainer.encode(base64String, forKey: .data)
                } else {
                    let mediaType = Content.detectMediaTypeFromBase64(imageString)
                    try sourceContainer.encode("base64", forKey: .type)
                    try sourceContainer.encode(mediaType, forKey: .mediaType)
                    try sourceContainer.encode(imageString, forKey: .data)
                }
            }
        }
        
        private enum CodingKeys: String, CodingKey {
            case type, text, source
        }
        
        private enum SourceCodingKeys: String, CodingKey {
            case type, mediaType = "media_type", data
        }
        
        private static func convertImageUrlToBase64(url: String) -> (String, String) {
            guard let imageUrl = URL(string: url), let imageData = try? Data(contentsOf: imageUrl) else {
                return ("", "")
            }
            
            let base64String = imageData.base64EncodedString()
            let mediaType = detectMediaType(from: imageData)
            
            return (base64String, mediaType)
        }
        
        private static func detectMediaTypeFromBase64(_ base64String: String) -> String {
            guard let data = Data(base64Encoded: base64String) else {
                return ""
            }
            
            return detectMediaType(from: data)
        }
        
        private static func detectMediaType(from data: Data) -> String {
            let bytes = [UInt8](data.prefix(12))
            
            if bytes.starts(with: [0xFF, 0xD8, 0xFF]) {
                return "image/jpeg"
            } else if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) {
                return "image/png"
            } else if bytes.starts(with: [0x47, 0x49, 0x46, 0x38]) {
                return "image/gif"
            } else if bytes.starts(with: [0x52, 0x49, 0x46, 0x46]) && String(data: data.subdata(in: 8..<12), encoding: .ascii) == "WEBP" {
                return "image/webp"
            } else {
                return ""
            }
        }
    }
    
    /// A struct that represents cache control settings for a system message.
    public struct CacheControl: Encodable {
        /// The type of cache control.
        public let type: `Type`
        
        /// An enum that represents the types of cache control.
        public enum `Type`: String, Encodable, CaseIterable {
            /// A case that represents ephemeral cache control.
            case ephemeral
        }
        
        /// Creates a new instance of ``CacheControl``.
        /// - Parameter type: The type of cache control.
        public init(type: `Type`) {
            self.type = type
        }
    }
    
    
    /// Creates a new instance of ``ChatMessage``.
    /// - Parameters:
    ///   - role: The role of the participant.
    ///   - content: The content of the message.
    public init(role: Role, content: [Content]) {
        self.role = role
        self.content = content
    }
    
    /// Creates a new instance of ``ChatMessage`` with single content.
    /// - Parameters:
    ///   - role: The role of the participant.
    ///   - content: The text content of the message.
    ///   - cacheControl: The cache control settings for the message. Only applicable when the role is `system`.
    public init(role: Role, content: String, cacheControl: CacheControl? = nil) {
        self.init(role: role, content: [.text(content)])
        self.cacheControl = cacheControl
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(role, forKey: .role)
        try container.encode(content, forKey: .content)
        try container.encodeIfPresent(cacheControl, forKey: .cacheControl)
    }
    
    private enum CodingKeys: String, CodingKey {
        case role, content
        case cacheControl = "cache_control"
    }
}
