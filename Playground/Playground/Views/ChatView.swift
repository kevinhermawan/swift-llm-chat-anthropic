//
//  ChatView.swift
//  Playground
//
//  Created by Kevin Hermawan on 9/29/24.
//

import SwiftUI
import LLMChatAnthropic

struct ChatView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var isPreferencesPresented: Bool = false
    
    @State private var prompt: String = "Hi!"
    @State private var response: String = ""
    @State private var inputTokens: Int = 0
    @State private var outputTokens: Int = 0
    @State private var totalTokens: Int = 0
    
    @State private var isGenerating: Bool = false
    @State private var generationTask: Task<Void, Never>?
    
    var body: some View {
        VStack {
            Form {
                Section("Prompt") {
                    TextField("Prompt", text: $prompt)
                }
                
                Section("Response") {
                    Text(response)
                }
                
                UsageSection(inputTokens: inputTokens, outputTokens: outputTokens, totalTokens: totalTokens)
            }
            
            VStack {
                if isGenerating {
                    CancelButton(onCancel: { generationTask?.cancel() })
                } else {
                    SendButton(stream: viewModel.stream, onSend: onSend, onStream: onStream)
                }
            }
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationTitle("Chat")
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
        
        isGenerating = true
        
        let messages = [
            ChatMessage(role: .system, content: viewModel.systemPrompt),
            ChatMessage(role: .user, content: prompt)
        ]
        
        let options = ChatOptions(temperature: viewModel.temperature)
        
        generationTask = Task {
            do {
                defer {
                    self.isGenerating = false
                    self.generationTask = nil
                }
                
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
                print(error)
            }
        }
    }
    
    private func onStream() {
        clear()
        
        isGenerating = true
        
        let messages = [
            ChatMessage(role: .system, content: viewModel.systemPrompt),
            ChatMessage(role: .user, content: prompt)
        ]
        
        let options = ChatOptions(temperature: viewModel.temperature)
        
        generationTask = Task {
            do {
                defer {
                    self.isGenerating = false
                    self.generationTask = nil
                }
                
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
                print(error)
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
