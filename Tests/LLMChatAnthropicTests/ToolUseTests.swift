//
//  ToolUseTests.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 10/8/24.
//

import XCTest
@testable import LLMChatAnthropic

final class ToolUseTests: XCTestCase {
    var chat: LLMChatAnthropic!
    var recommendBookTool: ChatOptions.Tool!
    
    override func setUp() {
        super.setUp()
        
        chat = LLMChatAnthropic(apiKey: "mock-api-key")
        recommendBookTool = ChatOptions.Tool(
            name: "recommend_book",
            description: "Recommend a book based on a given book and genre",
            parameters: .object(
                properties: [
                    "reference_book": .string(description: "The name of a book the user likes"),
                    "genre": .enum(
                        description: "The preferred genre for the book recommendation",
                        values: [.string("fiction"), .string("non-fiction")]
                    )
                ],
                required: ["reference_book", "genre"]
            )
        )
        
        URLProtocol.registerClass(URLProtocolMock.self)
    }
    
    override func tearDown() {
        chat = nil
        recommendBookTool = nil
        URLProtocolMock.mockData = nil
        URLProtocolMock.mockError = nil
        URLProtocolMock.mockStreamData = nil
        URLProtocol.unregisterClass(URLProtocolMock.self)
        
        super.tearDown()
    }
    
    func testToolUse() async throws {
        let mockResponseString = """
        {
          "id": "chatcmpl-123",
          "type": "message",
          "role": "assistant",
          "model": "claude-3-5-sonnet",
          "content": [
            {
              "type": "text",
              "text": "Certainly!"
            },
            {
              "type": "tool_use",
              "id": "tool_abc123",
              "name": "recommend_book",
              "input": {
                "reference_book": "1984",
                "genre": "fiction"
              }
            }
          ],
          "stop_reason": "tool_use",
          "stop_sequence": null,
          "usage": {
            "input_tokens": 5,
            "output_tokens": 10
          }
        }
        """
        
        let messages = [ChatMessage(role: .user, content: "Recommend a book similar to '1984'")]
        let options = ChatOptions(tools: [recommendBookTool])
        
        URLProtocolMock.mockData = mockResponseString.data(using: .utf8)
        let completion = try await chat.send(model: "claude-3-5-sonnet", messages: messages, options: options)
        let content = completion.content[0]
        let contentTool = completion.content[1]
        
        XCTAssertEqual(completion.id, "chatcmpl-123")
        XCTAssertEqual(completion.role, "assistant")
        XCTAssertEqual(completion.model, "claude-3-5-sonnet")
        XCTAssertEqual(completion.stopReason, "tool_use")
        XCTAssertEqual(completion.stopSequence, nil)
        
        // Content
        XCTAssertEqual(content.type, "text")
        XCTAssertEqual(content.text, "Certainly!")
        
        // Content Tool
        XCTAssertEqual(contentTool.type, "tool_use")
        XCTAssertEqual(contentTool.toolName, "recommend_book")
        XCTAssertEqual(contentTool.toolInput, "{\"genre\":\"fiction\",\"reference_book\":\"1984\"}")
        
        // Usage
        XCTAssertEqual(completion.usage?.inputTokens, 5)
        XCTAssertEqual(completion.usage?.outputTokens, 10)
        XCTAssertEqual(completion.usage?.totalTokens, 15)
    }
    
    func testToolUseStreaming() async throws {
        URLProtocolMock.mockStreamData = [
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"chatcmpl-123\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-3-5-sonnet\",\"content\":[],\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":5,\"output_tokens\":0}}}\n\n",
            "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"Certainly!\"}}\n\n",
            "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n",
            "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":1,\"content_block\":{\"type\":\"tool_use\",\"id\":\"tool_abc123\",\"name\":\"recommend_book\",\"input\":{}}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"{\\\"reference_book\\\": \\\"1984\\\", \\\"\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":1,\"delta\":{\"type\":\"input_json_delta\",\"partial_json\":\"genre\\\": \\\"fiction\\\"}\"}}\n\n",
            "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":1}\n\n",
            "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"tool_use\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":10}}\n\n",
            "event: message_stop\ndata: {\"type\":\"message_stop\"}\n\n"
        ]
        
        var receivedId: String? = nil
        var receivedRole: String? = nil
        var receivedModel: String? = nil
        var receivedStopReason: String? = nil
        var receivedStopSequence: String? = nil
        var receivedContentType = ""
        var receivedContentText = ""
        var receivedContentToolType = ""
        var receivedContentToolName = ""
        var receivedContentToolInput = ""
        var receivedUsage: ChatCompletionChunk.Usage? = nil
        
        let messages = [ChatMessage(role: .user, content: "Recommend a book similar to '1984'")]
        let options = ChatOptions(tools: [recommendBookTool])
        
        for try await chunk in chat.stream(model: "claude-3-5-sonnet", messages: messages, options: options) {
            if let type = chunk.delta?.type, chunk.delta?.type == "text" {
                receivedContentType = type
            }
            
            if let text = chunk.delta?.text, chunk.delta?.type == "text" {
                receivedContentText += text
            }
            
            if let type = chunk.delta?.type, chunk.delta?.type == "tool_use" {
                receivedContentToolType = type
            }
            
            if let toolName = chunk.delta?.toolName, chunk.delta?.type == "tool_use" {
                receivedContentToolName = toolName
            }
            
            if let toolInput = chunk.delta?.toolInput, chunk.delta?.type == "tool_use" {
                receivedContentToolInput += toolInput
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
        XCTAssertEqual(receivedStopReason, "tool_use")
        XCTAssertEqual(receivedStopSequence, nil)
        
        print("Received JSON: \(receivedContentToolInput)")
        print("Expected JSON: {\"reference_book\":\"1984\", \"genre\":\"fiction\"}")
        
        // Content
        XCTAssertEqual(receivedContentType, "text")
        XCTAssertEqual(receivedContentText, "Certainly!")
        
        // Content Tool
        XCTAssertEqual(receivedContentToolType, "tool_use")
        XCTAssertEqual(receivedContentToolName, "recommend_book")
        XCTAssertTrue(areJSONStringsEquivalent(receivedContentToolInput, "{\"reference_book\":\"1984\", \"genre\":\"fiction\"}"))
        
        // Usage
        XCTAssertEqual(receivedUsage?.inputTokens, 5)
        XCTAssertEqual(receivedUsage?.outputTokens, 10)
        XCTAssertEqual(receivedUsage?.totalTokens, 15)
    }
    
    private func areJSONStringsEquivalent(_ json1: String, _ json2: String) -> Bool {
        guard let data1 = json1.data(using: .utf8),
              let data2 = json2.data(using: .utf8) else {
            return false
        }
        
        guard let dict1 = try? JSONSerialization.jsonObject(with: data1, options: []) as? [String: Any],
              let dict2 = try? JSONSerialization.jsonObject(with: data2, options: []) as? [String: Any] else {
            return false
        }
        
        return NSDictionary(dictionary: dict1).isEqual(to: dict2)
    }
}
