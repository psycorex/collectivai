import SwiftUI
import Foundation

struct Message: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
}

struct ContentView: View {
    @State private var messages: [Message] = []
    @State private var inputText: String = ""
    @State private var isLoading: Bool = false
    @State private var apiKey: String = "API Key" // Replace with your key
    
    var body: some View {
        VStack {
            // Header
            Text("Simple LLM Chat")
                .font(.title2)
                .fontWeight(.bold)
                .padding()
            
            // Chat Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(messages) { message in
                        MessageBubble(message: message)
                    }
                    
                    if isLoading {
                        HStack {
                            Text("Thinking...")
                                .italic()
                                .foregroundColor(.gray)
                            ProgressView()
                                .scaleEffect(0.8)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.horizontal)
            
            // Input Area
            HStack {
                TextField("Type your message...", text: $inputText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .disabled(isLoading)
                
                Button(action: sendMessage) {
                    if isLoading {
                        ProgressView()
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                    }
                }
                .disabled(inputText.trimmingCharacters(in: .whitespaces).isEmpty || isLoading)
                .buttonStyle(.borderedProminent)
            }
            .padding()
            
            // Footer note
            Text("Note: Uses OpenAI API directly")
                .font(.caption)
                .foregroundColor(.gray)
        }
    }
    
    func sendMessage() {
        let userMessage = inputText.trimmingCharacters(in: .whitespaces)
        guard !userMessage.isEmpty else { return }
        
        // Add user message to chat
        messages.append(Message(content: userMessage, isUser: true))
        inputText = ""
        isLoading = true
        
        // Send to OpenAI API
        Task {
            do {
                let response = try await sendToOpenAI(message: userMessage)
                await MainActor.run {
                    messages.append(Message(content: response, isUser: false))
                    isLoading = false
                }
            } catch {
                await MainActor.run {
                    messages.append(Message(content: "Error: \(error.localizedDescription)", isUser: false))
                    isLoading = false
                }
            }
        }
    }
    
    func sendToOpenAI(message: String) async throws -> String {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        
        let requestBody: [String: Any] = [
            "model": "gpt-3.5-turbo",
            "messages": [
                ["role": "user", "content": message]
            ],
            "max_tokens": 150
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw URLError(.badServerResponse)
        }
        
        if httpResponse.statusCode == 429 {
            throw NSError(domain: "API", code: 429, userInfo: [NSLocalizedDescriptionKey: "Too many requests. Please wait."])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        guard let choices = json?["choices"] as? [[String: Any]],
              let firstChoice = choices.first,
              let message = firstChoice["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw URLError(.cannotParseResponse)
        }
        
        return content.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct MessageBubble: View {
    let message: Message
    
    var body: some View {
        HStack {
            if message.isUser {
                Spacer()
            }
            
            Text(message.content)
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(message.isUser ? Color.blue : Color.gray.opacity(0.2))
                .foregroundColor(message.isUser ? .white : .primary)
                .cornerRadius(18)
            
            if !message.isUser {
                Spacer()
            }
        }
    }
}
