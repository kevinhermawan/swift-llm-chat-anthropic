//
//  ToolUseView.swift
//  Playground
//
//  Created by Kevin Hermawan on 10/5/24.
//

import SwiftUI
import LLMChatAnthropic

struct ToolUseView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var isPreferencesPresented: Bool = false
    
    @State private var prompt: String = "Recommend a book similar to '1984'"
    @State private var selectedToolChoiceKey: String = "auto"
    
    @State private var responseText: String = ""
    @State private var responseToolUse: String = ""
    @State private var inputTokens: Int = 0
    @State private var outputTokens: Int = 0
    @State private var totalTokens: Int = 0
    
    private let toolChoices: [String: ChatOptions.ToolChoice] = [
        "any": .any,
        "auto": .auto,
        "recommend_book": .tool(name: "recommend_book")
    ]
    
    private let recommendBookTool = ChatOptions.Tool(
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
    
    var body: some View {
        VStack {
            Form {
                Section("Prompt") {
                    TextField("Prompt", text: $prompt)
                }
                
                Section("Response Text") {
                    Text(responseText)
                }
                
                Section("Response Tool Use") {
                    Text(responseToolUse)
                }
                
                Section("Usage") {
                    Text("Input Tokens")
                        .badge(inputTokens.formatted())
                    
                    Text("Output Tokens")
                        .badge(outputTokens.formatted())
                    
                    Text("Total Tokens")
                        .badge(totalTokens.formatted())
                }
            }
            
            VStack {
                SendButton(stream: viewModel.stream, onSend: onSend, onStream: onStream)
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationTitle("Tool Use")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Preferences", systemImage: "gearshape", action: { isPreferencesPresented.toggle() })
            }
        }
        .sheet(isPresented: $isPreferencesPresented) {
            PreferencesView()
        }
    }
    
    private func onSend() {
        clear()
        
        let messages = [
            ChatMessage(role: .system, content: viewModel.systemPrompt),
            ChatMessage(role: .user, content: prompt)
        ]
        
        let options = ChatOptions(
            temperature: viewModel.temperature,
            tools: [recommendBookTool],
            toolChoice: toolChoices[selectedToolChoiceKey]
        )
        
        Task {
            do {
                let completion = try await viewModel.chat.send(model: viewModel.selectedModel, messages: messages, options: options)
                
                if let text = completion.content.first(where: { $0.type == "text" })?.text {
                    self.responseText = text
                }
                
                if let toolInput = completion.content.first(where: { $0.type == "tool_use" })?.toolInput {
                    self.responseToolUse = toolInput
                }
                
                if let usage = completion.usage {
                    self.inputTokens = usage.inputTokens
                    self.outputTokens = usage.outputTokens
                    self.totalTokens = usage.totalTokens
                }
            } catch {
                print(String(describing: error))
            }
        }
    }
    
    private func onStream() {
        clear()
        
        let messages = [
            ChatMessage(role: .system, content: viewModel.systemPrompt),
            ChatMessage(role: .user, content: prompt)
        ]
        
        let options = ChatOptions(
            temperature: viewModel.temperature,
            tools: [recommendBookTool],
            toolChoice: toolChoices[selectedToolChoiceKey]
        )
        
        Task {
            do {
                for try await chunk in viewModel.chat.stream(model: viewModel.selectedModel, messages: messages, options: options) {
                    if let text = chunk.delta?.text, chunk.delta?.type == "text" {
                        self.responseText += text
                    }
                    
                    if let toolInput = chunk.delta?.toolInput, chunk.delta?.type == "tool_use" {
                        self.responseToolUse += toolInput
                    }
                    
                    if let usage = chunk.usage {
                        self.inputTokens = usage.inputTokens
                        self.outputTokens = usage.outputTokens
                        self.totalTokens = usage.totalTokens
                    }
                }
            } catch {
                print(String(describing: error))
            }
        }
    }
    
    private func clear() {
        self.responseText = ""
        self.responseToolUse = ""
        self.inputTokens = 0
        self.outputTokens = 0
        self.totalTokens = 0
    }
}
