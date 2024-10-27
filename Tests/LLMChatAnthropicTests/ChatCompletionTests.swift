//
//  ChatCompletionTests.swift
//  LLMChatAnthropic
//
//  Created by Kevin Hermawan on 10/8/24.
//

import XCTest
@testable import LLMChatAnthropic

final class ChatCompletionTests: XCTestCase {
    var chat: LLMChatAnthropic!
    var messages: [ChatMessage]!
    
    override func setUp() {
        super.setUp()
        
        chat = LLMChatAnthropic(apiKey: "mock-api-key")
        
        messages = [
            ChatMessage(role: .system, content: "You are a helpful assistant."),
            ChatMessage(role: .system, content: "Jakarta is the capital of Indonesia.", cacheControl: .init(type: .ephemeral)),
            ChatMessage(role: .user, content: "What is the capital of Indonesia?")
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
    
    func testSendChatCompletion() async throws {
        let mockResponseString = """
        {
          "id": "chatcmpl-123",
          "type": "message",
          "role": "assistant",
          "model": "claude-3-5-sonnet",
          "content": [
            {
              "type": "text",
              "text": "The capital of Indonesia is Jakarta."
            }
          ],
          "stop_reason": "end_turn",
          "stop_sequence": null,
          "usage": {
            "input_tokens": 5,
            "output_tokens": 10
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
        XCTAssertEqual(content?.text, "The capital of Indonesia is Jakarta.")
        
        // Usage
        XCTAssertEqual(completion.usage?.inputTokens, 5)
        XCTAssertEqual(completion.usage?.outputTokens, 10)
        XCTAssertEqual(completion.usage?.totalTokens, 15)
    }
    
    func testStreamChatCompletion() async throws {
        URLProtocolMock.mockStreamData = [
            "event: message_start\ndata: {\"type\":\"message_start\",\"message\":{\"id\":\"chatcmpl-123\",\"type\":\"message\",\"role\":\"assistant\",\"model\":\"claude-3-5-sonnet\",\"content\":[],\"stop_reason\":null,\"stop_sequence\":null,\"usage\":{\"input_tokens\":5,\"output_tokens\":0}}}\n\n",
            "event: content_block_start\ndata: {\"type\":\"content_block_start\",\"index\":0,\"content_block\":{\"type\":\"text\",\"text\":\"\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"The capital\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\" of Indonesia\"}}\n\n",
            "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\" is Jakarta.\"}}\n\n",
            "event: content_block_stop\ndata: {\"type\":\"content_block_stop\",\"index\":0}\n\n",
            "event: message_delta\ndata: {\"type\":\"message_delta\",\"delta\":{\"stop_reason\":\"end_turn\",\"stop_sequence\":null},\"usage\":{\"output_tokens\":10}}\n\n",
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
        XCTAssertEqual(receivedContentText, "The capital of Indonesia is Jakarta.")
        
        // Usage
        XCTAssertEqual(receivedUsage?.inputTokens, 5)
        XCTAssertEqual(receivedUsage?.outputTokens, 10)
        XCTAssertEqual(receivedUsage?.totalTokens, 15)
    }
}
// MARK: - Error Handling
extension ChatCompletionTests {
    func testServerError() async throws {
        let mockErrorResponse = """
        {
            "error": {
                "message": "Invalid API key provided"
            }
        }
        """
        
        URLProtocolMock.mockData = mockErrorResponse.data(using: .utf8)
        
        do {
            _ = try await chat.send(model: "claude-3-5-sonnet", messages: messages)
            
            XCTFail("Expected serverError to be thrown")
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .serverError(let message):
                XCTAssertEqual(message, "Invalid API key provided")
            default:
                XCTFail("Expected serverError but got \(error)")
            }
        }
    }
    
    func testNetworkError() async throws {
        URLProtocolMock.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        
        do {
            _ = try await chat.send(model: "claude-3-5-sonnet", messages: messages)
            
            XCTFail("Expected networkError to be thrown")
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .networkError(let underlyingError):
                XCTAssertEqual((underlyingError as NSError).code, NSURLErrorNotConnectedToInternet)
            default:
                XCTFail("Expected networkError but got \(error)")
            }
        }
    }
    
    func testStreamServerError() async throws {
        let mockErrorResponse = """
        {
            "error": {
                "message": "Rate limit exceeded"
            }
        }
        """
        
        URLProtocolMock.mockStreamData = [mockErrorResponse]
        
        do {
            for try await _ in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
                XCTFail("Expected serverError to be thrown")
            }
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .serverError(let message):
                XCTAssertEqual(message, "Rate limit exceeded")
            default:
                XCTFail("Expected serverError but got \(error)")
            }
        }
    }
    
    func testStreamNetworkError() async throws {
        URLProtocolMock.mockError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNotConnectedToInternet,
            userInfo: [NSLocalizedDescriptionKey: "The Internet connection appears to be offline."]
        )
        
        do {
            for try await _ in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
                XCTFail("Expected networkError to be thrown")
            }
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .networkError(let underlyingError):
                XCTAssertEqual((underlyingError as NSError).code, NSURLErrorNotConnectedToInternet)
            default:
                XCTFail("Expected networkError but got \(error)")
            }
        }
    }
}
