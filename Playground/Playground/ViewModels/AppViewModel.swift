//
//  AppViewModel.swift
//  Playground
//
//  Created by Kevin Hermawan on 9/29/24.
//

import Foundation
import AIModelRetriever
import LLMChatAnthropic

@Observable
final class AppViewModel {
    var stream = true
    var apiKey: String = ""
    
    var chat = LLMChatAnthropic(apiKey: "")
    var modelRetriever = AIModelRetriever()
    
    var models = [String]()
    var selectedModel: String = ""
    var systemPrompt: String = "You're a helpful AI assistant."
    var temperature = 0.5
    
    init() {
        if let existingApiKey = UserDefaults.standard.string(forKey: "apiKey") {
            self.apiKey = existingApiKey
        }
        
        fetchModels()
        configureChat()
    }
    
    func saveSettings() {
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        
        if let newApiKey = UserDefaults.standard.string(forKey: "apiKey") {
            self.apiKey = newApiKey
        }
        
        configureChat()
    }
    
    private func configureChat() {
        chat = LLMChatAnthropic(apiKey: apiKey, headers: ["anthropic-beta": "prompt-caching-2024-07-31"])
    }
    
    private func fetchModels() {
        let llmModels = modelRetriever.anthropic()
        models = llmModels.map(\.id)
        
        if let firstModel = models.first {
            selectedModel = firstModel
        }
    }
}
