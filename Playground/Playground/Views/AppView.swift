//
//  AppView.swift
//  Playground
//
//  Created by Kevin Hermawan on 9/29/24.
//

import SwiftUI

struct AppView: View {
    @State private var isPreferencesPresented: Bool = false
    
    var body: some View {
        NavigationStack {
            VStack {
                Form {
                    Section {
                        NavigationLink("Chat") {
                            ChatView()
                        }
                        
                        NavigationLink("Vision") {
                            VisionView()
                        }
                        
                        NavigationLink("Tool Use") {
                            ToolUseView()
                        }
                        
                        NavigationLink("Prompt Caching") {
                            PromptCachingView()
                        }
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    NavigationTitle("Anthropic Playground")
                }
                
                ToolbarItem(placement: .primaryAction) {
                    Button("Preferences", systemImage: "gearshape", action: { isPreferencesPresented.toggle() })
                }
            }
            .sheet(isPresented: $isPreferencesPresented) {
                PreferencesView()
            }
        }
    }
}
