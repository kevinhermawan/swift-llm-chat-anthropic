# LLMChatAnthropic

[![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkevinhermawan%2Fswift-llm-chat-anthropic%2Fbadge%3Ftype%3Dswift-versions)](https://swiftpackageindex.com/kevinhermawan/swift-llm-chat-anthropic) [![](https://img.shields.io/endpoint?url=https%3A%2F%2Fswiftpackageindex.com%2Fapi%2Fpackages%2Fkevinhermawan%2Fswift-llm-chat-anthropic%2Fbadge%3Ftype%3Dplatforms)](https://swiftpackageindex.com/kevinhermawan/swift-llm-chat-anthropic)

Interact with Anthropic and Anthropic-compatible chat completion APIs in a simple and elegant way.

### Overview

`LLMChatAnthropic` is a simple yet powerful Swift package that elegantly encapsulates the complexity of interacting with Anthropic and Anthropic-compatible chat completion APIs. It offers a complete set of Swift-idiomatic methods for sending chat completion requests and streaming responses.

## Installation

You can add `LLMChatAnthropic` as a dependency to your project using Swift Package Manager by adding it to the dependencies value of your `Package.swift`.

```swift
dependencies: [
    .package(url: "https://github.com/kevinhermawan/swift-llm-chat-anthropic.git", .upToNextMajor(from: "1.0.0"))
],
targets: [
    .target(
        /// ...
        dependencies: [.product(name: "LLMChatAnthropic", package: "swift-llm-chat-anthropic")])
]
```

Alternatively, in Xcode:

1. Open your project in Xcode.
2. Click on `File` -> `Swift Packages` -> `Add Package Dependency...`
3. Enter the repository URL: `https://github.com/kevinhermawan/swift-llm-chat-anthropic.git`
4. Choose the version you want to add. You probably want to add the latest version.
5. Click `Add Package`.

## Documentation

You can find the documentation here: [https://kevinhermawan.github.io/swift-llm-chat-anthropic/documentation/llmchatanthropic](https://kevinhermawan.github.io/swift-llm-chat-anthropic/documentation/llmchatanthropic)

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

#### PDF Support (Beta)

```swift
let chat = LLMChatAnthropic(
    apiKey: "<YOUR_ANTHROPIC_API_KEY>",
    headers: ["anthropic-beta": "pdfs-2024-09-25"] // Required
)

let messages = [
    ChatMessage(role: .user, content: [.text("Explain this document"), .document(document)])
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

To learn more about PDF support, check out the [Anthropic documentation](https://docs.anthropic.com/en/docs/build-with-claude/pdf-support).

### Error Handling

`LLMChatAnthropic` provides structured error handling through the `LLMChatAnthropicError` enum. This enum contains three cases that represent different types of errors you might encounter:

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
    case .serverError(let statusCode, let message):
        // Handle server-side errors (e.g., invalid API key, rate limits)
        print("Server Error [\(statusCode)]: \(message)")
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

## Support

If you find `LLMChatAnthropic` helpful and would like to support its development, consider making a donation. Your contribution helps maintain the project and develop new features.

- [GitHub Sponsors](https://github.com/sponsors/kevinhermawan)
- [Buy Me a Coffee](https://buymeacoffee.com/kevinhermawan)

Your support is greatly appreciated! ❤️

## Contributing

Contributions are welcome! Please open an issue or submit a pull request if you have any suggestions or improvements.

## License

This repository is available under the [Apache License 2.0](LICENSE).
