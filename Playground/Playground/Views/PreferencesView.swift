//
//  PreferencesView.swift
//  Playground
//
//  Created by Kevin Hermawan on 10/7/24.
//

import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(AppViewModel.self) private var viewModel
    
    var body: some View {
        @Bindable var viewModelBindable = viewModel
        
        NavigationStack {
            Form {
                Section("API Key") {
                    TextField("API Key", text: $viewModelBindable.apiKey)
                }
                
                Section("System Prompt") {
                    TextField("System Prompt", text: $viewModelBindable.systemPrompt)
                }
                .disabled(viewModel.apiKey.isEmpty)
                
                Section("General") {
                    Toggle("Stream Response", isOn: $viewModelBindable.stream)
                    
                    Picker("Model", selection: $viewModelBindable.selectedModel) {
                        ForEach(viewModelBindable.models, id: \.self) { model in
                            Text(model).tag(model)
                        }
                    }
                }
                .disabled(viewModel.apiKey.isEmpty)
                
                Section("Temperature") {
                    Stepper(viewModel.temperature.formatted(), value: $viewModelBindable.temperature, in: 0...1, step: 0.1)
                }
                .disabled(viewModel.apiKey.isEmpty)
            }
            .navigationTitle("Preferences")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: { dismiss() })
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: saveAction)
                        .disabled(viewModel.apiKey.isEmpty)
                }
            }
        }
    }
    
    private func saveAction() {
        viewModel.saveSettings()
        
        dismiss()
    }
}
