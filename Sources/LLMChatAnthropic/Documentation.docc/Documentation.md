# ``LLMChatAnthropic``

Interact with Anthropic and Anthropic-compatible chat completion APIs in a simple and elegant way.

### Overview

`LLMChatAnthropic` is a simple yet powerful Swift package that elegantly encapsulates the complexity of interacting with Anthropic and Anthropic-compatible chat completion APIs. It offers a complete set of Swift-idiomatic methods for sending chat completion requests and streaming responses.

## Usage

#### Initialization

```swift
import LLMChatAnthropic

// Basic initialization
let chat = LLMChatAnthropic(apiKey: "<YOUR_ANTHROPIC_API_KEY>")

// Initialize with custom endpoint and headers
let chat = LLMChatAnthropic(
    apiKey: "<YOUR_API_KEY>",
    endpoint: URL(string: "https://custom-api.example.com/v1/messages")!,
    headers: ["Custom-Header": "Value"]
)
```

#### Sending Chat Completion

```swift
let messages = [
    ChatMessage(role: .system, content: "You are a helpful assistant."),
    ChatMessage(role: .user, content: "What is the capital of Indonesia?")
]

let task = Task {
    do {
        let completion = try await chat.send(model: "claude-3-5-sonnet", messages: messages)

        print(completion.content.first?.text ?? "No response")
    } catch {
        print(String(describing: error))
    }
}

// To cancel completion
task.cancel()
```

#### Streaming Chat Completion

```swift
let messages = [
    ChatMessage(role: .system, content: "You are a helpful assistant."),
    ChatMessage(role: .user, content: "What is the capital of Indonesia?")
]

let task = Task {
    do {
        for try await chunk in chat.stream(model: "claude-3-5-sonnet", messages: messages) {
            if let text = chunk.delta?.text {
                print(text, terminator: "")
            }
        }
    } catch {
        print(String(describing: error))
    }
}

// To cancel completion
task.cancel()
```

### Advanced Usage

#### Vision

```swift
let messages = [
    ChatMessage(
        role: .user,
        content: [
            .image("https://images.pexels.com/photos/45201/kitty-cat-kitten-pet-45201.jpeg"), // Also supports base64 strings
            .text("What is in this image?")
        ]
    )
]

Task {
    do {
        let completion = try await chat.send(model: "claude-3-5-sonnet", messages: messages)

        print(completion.content.first?.text ?? "")
    } catch {
        print(String(describing: error))
    }
}
```

To learn more about vision, check out the [Anthropic documentation](https://docs.anthropic.com/en/docs/build-with-claude/vision).

#### Tool Use

```swift
let messages = [
    ChatMessage(role: .user, content: "Recommend a book similar to '1984'")
]

let recommendBookTool = ChatOptions.Tool(
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
        required: ["reference_book", "genre"],
        additionalProperties: .boolean(false)
    )
)

let options = ChatOptions(tools: [recommendBookTool])

Task {
    do {
        let completion = try await chat.send(model: "claude-3-5-sonnet", messages: messages, options: options)

        if let toolInput = completion.content.first(where: { $0.type == "tool_use" })?.toolInput {
            print(toolInput)
       }
    } catch {
        print(String(describing: error))
    }
}
```

To learn more about tool use, check out the [Anthropic documentation](https://docs.anthropic.com/en/docs/build-with-claude/tool-use).

#### Prompt Caching (Beta)

```swift
let chat = LLMChatAnthropic(
    apiKey: "<YOUR_ANTHROPIC_API_KEY>",
    headers: ["anthropic-beta": "prompt-caching-2024-07-31"] // Required
)

let messages = [
    ChatMessage(role: .system, content: "<YOUR_LONG_PROMPT>", cacheControl: .init(type: .ephemeral)),
    ChatMessage(role: .user, content: "What is the capital of Indonesia?")
]

let task = Task {
    do {
        let completion = try await chat.send(model: "claude-3-5-sonnet", messages: messages)

        print(completion.content.first?.text ?? "No response")
    } catch {
        print(String(describing: error))
    }
}
```

To learn more about prompt caching, check out the [Anthropic documentation](https://docs.anthropic.com/en/docs/build-with-claude/prompt-caching).

### Error Handling

``LLMChatAnthropic`` provides structured error handling through the ``LLMChatAnthropicError`` enum. This enum contains three cases that represent different types of errors you might encounter:

```swift
let messages = [
    ChatMessage(role: .system, content: "You are a helpful assistant."),
    ChatMessage(role: .user, content: "What is the capital of Indonesia?")
]

do {
    let completion = try await chat.send(model: "claude-3-5-sonnet", messages: messages)

    print(completion.content.first?.text ?? "No response")
} catch let error as LLMChatAnthropicError {
    switch error {
    case .serverError(let message):
        // Handle server-side errors (e.g., invalid API key, rate limits)
        print("Server Error: \(message)")
    case .networkError(let error):
        // Handle network-related errors (e.g., no internet connection)
        print("Network Error: \(error.localizedDescription)")
    case .decodingError(let error):
        // Handle errors that occur when the response cannot be decoded
        print("Decoding Error: \(error.localizedDescription)")
    case .streamError:
        // Handle errors that occur when streaming responses
        print("Stream Error")
    case .cancelled:
        // Handle requests that are cancelled
        print("Request was cancelled")
    }
} catch {
    // Handle any other errors
    print("An unexpected error occurred: \(error)")
}
```

## Related Packages

- [swift-ai-model-retriever](https://github.com/kevinhermawan/swift-ai-model-retriever)
- [swift-json-schema](https://github.com/kevinhermawan/swift-json-schema)
- [swift-llm-chat-openai](https://github.com/kevinhermawan/swift-llm-chat-openai)
