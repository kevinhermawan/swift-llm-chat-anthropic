//
//  AppViewModel.swift
//  Playground
//
//  Created by Kevin Hermawan on 9/29/24.
//

import Foundation
import LLMChatAnthropic

@Observable
final class AppViewModel {
    let models: [String] = [
        "claude-3-5-sonnet-20240620",
        "claude-3-opus-20240229",
        "claude-3-sonnet-20240229",
        "claude-3-haiku-20240307"
    ]
    
    var stream = true
    var apiKey: String = ""
    var chat = LLMChatAnthropic(apiKey: "")
    
    var selectedModel: String = "claude-3-5-sonnet-20240620"
    var systemPrompt: String = "You're a helpful AI assistant."
    var temperature = 0.5
    
    init() {
        if let existingApiKey = UserDefaults.standard.string(forKey: "apiKey") {
            self.apiKey = existingApiKey
        }
        
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
        chat = LLMChatAnthropic(apiKey: apiKey, customHeaders: ["anthropic-beta": "prompt-caching-2024-07-31"])
    }
}
