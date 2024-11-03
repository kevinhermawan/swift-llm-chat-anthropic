//
//  PDFSupportView.swift
//  Playground
//
//  Created by Kevin Hermawan on 11/3/24.
//

import SwiftUI
import LLMChatAnthropic

struct PDFSupportView: View {
    @Environment(AppViewModel.self) private var viewModel
    @State private var isPreferencesPresented: Bool = false
    
    @State private var document: String = "https://arxiv.org/pdf/1706.03762"
    @State private var prompt: String = "Explain this document"
    
    @State private var response: String = ""
    @State private var inputTokens: Int = 0
    @State private var outputTokens: Int = 0
    @State private var totalTokens: Int = 0
    
    var body: some View {
        @Bindable var viewModelBindable = viewModel
        
        VStack {
            Form {
                Section("Prompts") {
                    TextField("Document", text: $document)
                    TextField("Prompt", text: $prompt)
                }
                
                Section("Response") {
                    Text(response)
                }
                
                UsageSection(inputTokens: inputTokens, outputTokens: outputTokens, totalTokens: totalTokens)
            }
            
            VStack {
                SendButton(stream: viewModel.stream, onSend: onSend, onStream: onStream)
            }
        }
        .onAppear {
            viewModel.setHeaders(["anthropic-beta": "pdfs-2024-09-25"])
        }
        .toolbar {
            ToolbarItem(placement: .principal) {
                NavigationTitle("PDF Support")
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
            ChatMessage(role: .user, content: [.text(prompt), .document(document)])
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
            ChatMessage(role: .user, content: [.text(prompt), .document(document)])
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
