//
//  VisionTests.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 10/8/24.
//

import XCTest
@testable import LLMChatAnthropic

final class VisionTests: XCTestCase {
    var chat: LLMChatAnthropic!
    var messages: [ChatMessage]!
    
    override func setUp() {
        super.setUp()
        
        chat = LLMChatAnthropic(apiKey: "mock-api-key")
        messages = [
            ChatMessage(role: .system, content: "You are a helpful assistant."),
            ChatMessage(role: .user, content: [.image("https://example.com/kitten.jpeg"), .text("What is in this image?")])
        ]
        
        URLProtocol.registerClass(URLProtocolMock.self)
    }
    
    override func tearDown() {
        chat = nil
        messages = nil
        URLProtocolMock.mockData = nil
        URLProtocolMock.mockError = nil
        URLProtocolMock.mockStreamData = nil
        URLProtocol.unregisterClass(URLProtocolMock.self)
        
        super.tearDown()
    }
    
    func testVision() async throws {
        let mockResponseString = """
        {
          "id": "chatcmpl-123",
          "type": "message",
          "role": "assistant",
          "model": "claude-3-5-sonnet",
          "content": [
            {
              "type": "text",
              "text": "The image shows a cute kitten or young cat."
            }
          ],
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {
            "input_tokens": 50,
            "output_tokens": 80
          }
        }
        """
        
        URLProtocolMock.mockData = mockResponseString.data(using: .utf8)
        let completion = try await chat.send(model: "claude-3-5-sonnet", messages: messages)
        let content = completion.content.first
        
        XCTAssertEqual(completion.id, "chatcmpl-123")
        XCTAssertEqual(completion.role, "assistant")
        XCTAssertEqual(completion.model, "claude-3-5-sonnet")
        XCTAssertEqual(completion.stopReason, "end_turn")
        XCTAssertEqual(completion.stopSequence, nil)
        
        // Content
        XCTAssertEqual(content?.type, "text")
        XCTAssertEqual(content?.text, "The image shows a cute kitten or young cat.")
        
        // Usage
        XCTAssertEqual(completion.usage?.inputTokens, 50)
        XCTAssertEqual(completion.usage?.outputTokens, 80)
        XCTAssertEqual(completion.usage?.totalTokens, 130)
    }
    
    func testVisionStreaming() async throws {
        URLProtocolMock.mockStreamData = [
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"chatcmpl-123\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-3-5-sonnet\",\"content\":[],\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":50,\"output_tokens\":0}}}\n\n",
            "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"The image shows\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\" a cute kitten\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\" or young cat.\"}}\n\n",
            "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n",
            "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":80}}\n\n",
            "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
        ]
        
        var receivedId: String? = nil
        var receivedRole: String? = nil
        var receivedModel: String? = nil
        var receivedStopReason: String? = nil
        var receivedStopSequence: String? = nil
        var receivedContentType = ""
        var receivedContentText = ""
        var receivedUsage: ChatCompletionChunk.Usage? = nil
        
        for try await chunk in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
            if let type = chunk.delta?.type {
                receivedContentType = type
            }
            
            if let text = chunk.delta?.text {
                receivedContentText += text
            }
            
            receivedId = chunk.id
            receivedRole = chunk.role
            receivedModel = chunk.model
            receivedStopReason = chunk.stopReason
            receivedStopSequence = chunk.stopSequence
            receivedUsage = chunk.usage
        }
        
        XCTAssertEqual(receivedId, "chatcmpl-123")
        XCTAssertEqual(receivedRole, "assistant")
        XCTAssertEqual(receivedModel, "claude-3-5-sonnet")
        XCTAssertEqual(receivedStopReason, "end_turn")
        XCTAssertEqual(receivedStopSequence, nil)
        
        // Content
        XCTAssertEqual(receivedContentType, "text")
        XCTAssertEqual(receivedContentText, "The image shows a cute kitten or young cat.")
        
        // Usage
        XCTAssertEqual(receivedUsage?.inputTokens, 50)
        XCTAssertEqual(receivedUsage?.outputTokens, 80)
        XCTAssertEqual(receivedUsage?.totalTokens, 130)
    }
}
