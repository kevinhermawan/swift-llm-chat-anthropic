//
//  PromptCachingView.swift
//  Playground
//
//  Created by Kevin Hermawan on 10/6/24.
//

import SwiftUI
import LLMChatAnthropic

struct PromptCachingView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var isPreferencesPresented: Bool = false
    
    @State private var cachedPrompt: String = ""
    @State private var prompt: String = "Who discovered gravity in the 17th century?"
    @State private var response: String = ""
    @State private var inputTokens: Int = 0
    @State private var outputTokens: Int = 0
    @State private var totalTokens: Int = 0
    
    var body: some View {
        VStack {
            Form {
                Section("Cached Prompt") {
                    TextField("Cached Prompt", text: $cachedPrompt)
                }
                
                Section("Prompt") {
                    TextField("Prompt", text: $prompt)
                }
                
                Section("Response") {
                    Text(response)
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
                NavigationTitle("Prompt Caching")
            }
            
            ToolbarItem(placement: .primaryAction) {
                Button("Preferences", systemImage: "gearshape", action: { isPreferencesPresented.toggle() })
            }
        }
        .sheet(isPresented: $isPreferencesPresented) {
            PreferencesView()
        }
        .onAppear {
            if let fileURL = Bundle.main.url(forResource: "prompt-caching", withExtension: "txt"),
               let contents = try? String(contentsOf: fileURL, encoding: .utf8) {
                self.cachedPrompt = contents
            }
        }
    }
    
    private func onSend() {
        clear()
        
        let messages = [
            ChatMessage(role: .system, content: viewModel.systemPrompt),
            ChatMessage(role: .system, content: cachedPrompt, cacheControl: .init(type: .ephemeral)),
            ChatMessage(role: .user, content: prompt)
        ]
        
        let options = ChatOptions(temperature: viewModel.temperature)
        
        Task {
            do {
                let completion = try await viewModel.chat.send(model: viewModel.selectedModel, messages: messages, options: options)
                
                if let text = completion.content.first?.text {
                    self.response = text
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
            ChatMessage(role: .system, content: cachedPrompt, cacheControl: .init(type: .ephemeral)),
            ChatMessage(role: .user, content: prompt)
        ]
        
        let options = ChatOptions(temperature: viewModel.temperature)
        
        Task {
            do {
                for try await chunk in viewModel.chat.stream(model: viewModel.selectedModel, messages: messages, options: options) {
                    if let text = chunk.delta?.text {
                        self.response += text
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
        self.response = ""
        self.inputTokens = 0
        self.outputTokens = 0
        self.totalTokens = 0
    }
}
