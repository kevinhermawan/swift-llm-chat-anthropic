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
        URLProtocolMock.reset()
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
    
    func testHTTPError() async throws {
        URLProtocolMock.mockStatusCode = 429
        URLProtocolMock.mockData = "Rate limit exceeded".data(using: .utf8)
        
        do {
            _ = try await chat.send(model: "claude-3-5-sonnet", messages: messages)
            
            XCTFail("Expected serverError to be thrown")
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .serverError(let message):
                XCTAssertTrue(message.contains("429"))
            default:
                XCTFail("Expected serverError but got \(error)")
            }
        }
    }
    
    func testDecodingError() async throws {
        let invalidJSON = "{ invalid json }"
        URLProtocolMock.mockData = invalidJSON.data(using: .utf8)
        
        do {
            _ = try await chat.send(model: "claude-3-5-sonnet", messages: messages)
            
            XCTFail("Expected decodingError to be thrown")
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .decodingError:
                break
            default:
                XCTFail("Expected decodingError but got \(error)")
            }
        }
    }
    
    func testCancellation() async throws {
        let task = Task {
            _ = try await chat.send(model: "claude-3-5-sonnet", messages: messages)
        }
        
        task.cancel()
        
        do {
            _ = try await task.value
            
            XCTFail("Expected cancelled error to be thrown")
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .cancelled:
                break
            default:
                XCTFail("Expected cancelled but got \(error)")
            }
        }
    }
}

// MARK: - Error Handling (Stream)
extension ChatCompletionTests {
    func testStreamServerError() async throws {
        URLProtocolMock.mockStreamData = ["event: error\ndata: Server error occurred\n\n"]
        
        do {
            for try await _ in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
                XCTFail("Expected streamError to be thrown")
            }
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .streamError:
                break
            default:
                XCTFail("Expected streamError but got \(error)")
            }
        }
    }
    
    func testStreamNetworkError() async throws {
        let networkError = NSError(
            domain: NSURLErrorDomain,
            code: NSURLErrorNetworkConnectionLost,
            userInfo: [NSLocalizedDescriptionKey: "The network connection was lost."]
        )
        
        URLProtocolMock.mockError = networkError
        
        do {
            for try await _ in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
                XCTFail("Expected networkError to be thrown")
            }
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .networkError(let underlyingError):
                XCTAssertEqual((underlyingError as NSError).code, NSURLErrorNetworkConnectionLost)
            default:
                XCTFail("Expected networkError but got \(error)")
            }
        }
    }
    
    func testStreamHTTPError() async throws {
        URLProtocolMock.mockStatusCode = 503
        URLProtocolMock.mockStreamData = [""]
        
        do {
            for try await _ in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
                XCTFail("Expected serverError to be thrown")
            }
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .serverError(let message):
                XCTAssertTrue(message.contains("503"))
            default:
                XCTFail("Expected serverError but got \(error)")
            }
        }
    }
    
    func testStreamDecodingError() async throws {
        URLProtocolMock.mockStreamData = ["event: message_start\ndata: { invalid json }\n\n"]
        
        do {
            for try await _ in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
                XCTFail("Expected decodingError to be thrown")
            }
        } catch let error as LLMChatAnthropicError {
            switch error {
            case .decodingError:
                break
            default:
                XCTFail("Expected decodingError but got \(error)")
            }
        }
    }
    
    func testStreamCancellation() async throws {
        URLProtocolMock.mockStreamData = Array(repeating: "event: content_block_delta\ndata: {\"type\":\"content_block_delta\",\"index\":0,\"delta\":{\"type\":\"text_delta\",\"text\":\"test\"}}\n\n", count: 1000)
        
        let expectation = XCTestExpectation(description: "Stream cancelled")
        
        let task = Task {
            do {
                for try await _ in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
                    try await Task.sleep(nanoseconds: 100_000_000) // 1 second
                }
                
                XCTFail("Expected stream to be cancelled")
            } catch is CancellationError {
                expectation.fulfill()
            } catch {
                XCTFail("Expected CancellationError but got \(error)")
            }
        }
        
        try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
        task.cancel()
        
        await fulfillment(of: [expectation], timeout: 5.0)
    }
}
