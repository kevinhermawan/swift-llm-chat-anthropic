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
        configureChat()
        fetchModels()
    }
    
    func setHeaders(_ headers: [String: String]) {
        chat = LLMChatAnthropic(apiKey: apiKey, headers: headers)
    }
    
    func saveSettings() {
        UserDefaults.standard.set(apiKey, forKey: "apiKey")
        configureChat()
    }
    
    private func configureChat() {
        if let apiKey = UserDefaults.standard.string(forKey: "apiKey") {
            self.apiKey = apiKey
        }
        
        chat = LLMChatAnthropic(apiKey: apiKey)
    }
    
    private func fetchModels() {
        let llmModels = modelRetriever.anthropic()
        models = llmModels.map(\.id)
        
        if let firstModel = models.first {
            selectedModel = firstModel
        }
    }
}
