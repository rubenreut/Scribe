import Foundation
import SwiftUI

class AIService {
    private let apiKey: String
    private let baseURL: URL
    
    enum AIProvider: String {
        case openAI = "OpenAI"
        case claude = "Claude"
    }
    
    init(apiKey: String, provider: AIProvider = .openAI) {
        self.apiKey = apiKey
        
        switch provider {
        case .openAI:
            self.baseURL = URL(string: Constants.API.openAIBaseURL)!
        case .claude:
            // Would implement different base URL for Claude
            self.baseURL = URL(string: Constants.API.openAIBaseURL)!
        }
    }
    
    // MARK: - Note Organization
    
    func organizeNotes(_ notes: [ScribeNote], existingFolders: [ScribeFolder]) async throws -> [NoteOrganization] {
        // Prepare API request with notes content and existing folders
        let prompt = createOrganizationPrompt(notes, existingFolders)
        let response = try await sendRequest(prompt: prompt)
        
        // Parse response into note organizations
        return try parseOrganizationResponse(response, notes: notes)
    }
    
    private func createOrganizationPrompt(_ notes: [ScribeNote], _ folders: [ScribeFolder]) -> String {
        // Create a prompt that includes all notes and existing folders
        var prompt = "Organize the following notes into folders. You can suggest existing folders or create new ones. Respond in JSON format.\n\nExisting folders:\n"
        
        for (index, folder) in folders.enumerated() {
            prompt += "\(index + 1). \(folder.name)\n"
        }
        
        if folders.isEmpty {
            prompt += "(No existing folders yet)\n"
        }
        
        prompt += "\nNotes to organize:\n"
        
        for (index, note) in notes.enumerated() {
            let content: String
            do {
                // Register necessary classes for secure coding
                NSKeyedUnarchiver.setClass(NSTextAttachment.self, forClassName: "NSTextAttachment")
                NSKeyedUnarchiver.setClass(UIImage.self, forClassName: "UIImage")
                
                content = (try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(note.content) as? NSAttributedString)?.string ?? ""
            } catch {
                content = "Error retrieving content"
                print("Failed to unarchive note content: \(error)")
            }
            
            let safeContent = content.prefix(100)
            prompt += "Note \(index): Index: \(index), Title: \(note.title), Content: \(safeContent)...\n\n"
        }
        
        prompt += """

        Respond with a JSON array where each object has the following properties:
        - 'noteIndex': The index of the note (integer, using the index provided above)
        - 'folderName': Name of the folder to place the note in (string)
        - 'isNewFolder': true if this is a new folder to create, false if using existing folder (boolean)
        
        Example response:
        [
          {
            "noteIndex": 0,
            "folderName": "Work Notes",
            "isNewFolder": true
          },
          {
            "noteIndex": 1,
            "folderName": "Personal",
            "isNewFolder": true
          }
        ]
        """
        
        // Print prompt for debugging
        print("AI Organization Prompt: \(prompt)")
        
        return prompt
    }
    
    private func parseOrganizationResponse(_ response: String, notes: [ScribeNote]) throws -> [NoteOrganization] {
        // Parse JSON response into NoteOrganization structs
        print("API Response to parse: \(response)")
        
        guard let jsonData = response.data(using: .utf8) else {
            print("Failed to convert response to data")
            throw AIServiceError.invalidResponseFormat
        }
        
        // Try to extract JSON array if the response contains extra text
        if let startIndex = response.firstIndex(of: "["), 
           let endIndex = response.lastIndex(of: "]"), 
           startIndex < endIndex {
            let jsonSubstring = response[startIndex...endIndex]
            let cleanJsonData = Data(jsonSubstring.utf8)
            
            do {
                let decoder = JSONDecoder()
                let organizationResults = try decoder.decode([NoteOrganizationResult].self, from: cleanJsonData)
                
                print("Successfully decoded \(organizationResults.count) organization results")
                return organizationResults.compactMap { result in
                    guard result.noteIndex >= 0, result.noteIndex < notes.count else { 
                        print("Invalid note index: \(result.noteIndex)")
                        return nil 
                    }
                    return NoteOrganization(
                        note: notes[result.noteIndex], 
                        folderName: result.folderName, 
                        isNewFolder: result.isNewFolder
                    )
                }
            } catch {
                print("Failed to decode extracted JSON: \(error)")
                // Fallback to original parsing if substring extraction fails
            }
        }
        
        // Attempt standard parsing
        do {
            let decoder = JSONDecoder()
            let organizationResults = try decoder.decode([NoteOrganizationResult].self, from: jsonData)
            
            print("Successfully decoded \(organizationResults.count) organization results")
            return organizationResults.compactMap { result in
                guard result.noteIndex >= 0, result.noteIndex < notes.count else { 
                    print("Invalid note index: \(result.noteIndex)")
                    return nil 
                }
                return NoteOrganization(
                    note: notes[result.noteIndex], 
                    folderName: result.folderName, 
                    isNewFolder: result.isNewFolder
                )
            }
        } catch {
            print("JSON Parsing error: \(error)")
            
            // Try to extract JSON as a string from response if it might be mixed with other content
            if let jsonStart = response.range(of: "```json"), 
               let jsonEnd = response.range(of: "```", range: jsonStart.upperBound..<response.endIndex) {
                let jsonSubstring = response[jsonStart.upperBound..<jsonEnd.lowerBound].trimmingCharacters(in: .whitespacesAndNewlines)
                
                print("Found code block with possible JSON: \(jsonSubstring)")
                if let jsonData = jsonSubstring.data(using: .utf8) {
                    do {
                        let decoder = JSONDecoder()
                        let organizationResults = try decoder.decode([NoteOrganizationResult].self, from: jsonData)
                        
                        print("Successfully decoded JSON from code block")
                        return organizationResults.compactMap { result in
                            guard result.noteIndex >= 0, result.noteIndex < notes.count else { return nil }
                            return NoteOrganization(
                                note: notes[result.noteIndex], 
                                folderName: result.folderName, 
                                isNewFolder: result.isNewFolder
                            )
                        }
                    } catch {
                        print("Failed to decode JSON from code block: \(error)")
                    }
                }
            }
            
            throw AIServiceError.invalidResponseFormat
        }
    }
    
    // MARK: - API Testing
    
    /// Tests the API connection with a simple request
    func testConnection(prompt: String) async throws -> String {
        return try await sendRequest(prompt: prompt)
    }
    
    // MARK: - Note Formatting
    
    func formatNoteContent(_ content: String) async throws -> FormattedContent {
        // Prepare API request with note content
        let prompt = createFormattingPrompt(content)
        let response = try await sendRequest(prompt: prompt)
        
        // Parse response into formatted content instructions
        return try parseFormattingResponse(response, originalContent: content)
    }
    
    private func createFormattingPrompt(_ content: String) -> String {
        return """
        Format the following note content with appropriate headings, subheadings, and bullet points. 
        Do not change the actual content - only add formatting.
        Respond with a JSON object containing format instructions.
        
        Note content:
        \(content)
        
        Example response format:
        {
          "instructions": [
            {"type": "heading", "text": "Meeting Notes", "level": 1},
            {"type": "paragraph", "text": "Discussion about project timeline."},
            {"type": "bulletList", "items": ["Task 1", "Task 2"]}
          ]
        }
        """
    }
    
    private func parseFormattingResponse(_ response: String, originalContent: String) throws -> FormattedContent {
        // Parse JSON response into formatting instructions
        guard let jsonData = response.data(using: .utf8) else {
            throw AIServiceError.invalidResponseFormat
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(FormattedContent.self, from: jsonData)
    }
    
    // MARK: - API Request
    
    private func sendRequest(prompt: String) async throws -> String {
        var request = URLRequest(url: baseURL)
        request.httpMethod = "POST"
        request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Print debug info but mask the API key
        print("📡 Sending request to: \(baseURL)")
        print("🔑 Using API key: \(String(apiKey.prefix(3)))...\(String(apiKey.suffix(3)))")
        
        let requestBody: [String: Any] = [
            "model": "gpt-4",
            "messages": [
                ["role": "system", "content": "You are a helpful assistant for organizing and formatting notes."],
                ["role": "user", "content": prompt]
            ],
            "temperature": 0.3
        ]
        
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)
        
        do {
            print("⏳ Waiting for API response...")
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ Invalid HTTP response")
                throw AIServiceError.networkError
            }
            
            print("📥 Received response with status code: \(httpResponse.statusCode)")
            
            guard httpResponse.statusCode == 200 else {
                let errorBody = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("⚠️ API error (\(httpResponse.statusCode)): \(errorBody)")
                throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorBody)
            }
            
            do {
                let responseDict = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                let choices = responseDict?["choices"] as? [[String: Any]]
                let firstChoice = choices?.first
                let message = firstChoice?["message"] as? [String: Any]
                
                guard let content = message?["content"] as? String else {
                    print("❌ Invalid response format: \(String(data: data, encoding: .utf8) ?? "<unreadable data>")")
                    throw AIServiceError.invalidResponseFormat
                }
                
                print("✅ Successfully parsed API response")
                return content
            } catch {
                print("❌ JSON parsing error: \(error)")
                print("📄 Response data: \(String(data: data, encoding: .utf8) ?? "<unreadable data>")")
                throw AIServiceError.invalidResponseFormat
            }
        } catch {
            print("❌ Network or parsing error: \(error)")
            throw error
        }
    }
}

// MARK: - Models for organization and formatting

struct NoteOrganizationResult: Decodable {
    let noteIndex: Int
    let folderName: String
    let isNewFolder: Bool
}

struct NoteOrganization {
    let note: ScribeNote
    let folderName: String
    let isNewFolder: Bool
}

struct FormattedContent: Decodable {
    let instructions: [FormatInstruction]
}

enum FormatInstruction: Decodable {
    case heading(text: String, level: Int)
    case paragraph(text: String)
    case bulletList(items: [String])
    
    enum CodingKeys: String, CodingKey {
        case type, text, level, items
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(String.self, forKey: .type)
        
        switch type {
        case "heading":
            let text = try container.decode(String.self, forKey: .text)
            let level = try container.decode(Int.self, forKey: .level)
            self = .heading(text: text, level: level)
        case "paragraph":
            let text = try container.decode(String.self, forKey: .text)
            self = .paragraph(text: text)
        case "bulletList":
            let items = try container.decode([String].self, forKey: .items)
            self = .bulletList(items: items)
        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type,
                in: container,
                debugDescription: "Invalid format instruction type"
            )
        }
    }
}

enum AIServiceError: Error {
    case networkError
    case apiError(statusCode: Int, message: String)
    case invalidResponseFormat
    case missingAPIKey
}

extension AIServiceError: LocalizedError {
    var errorDescription: String? {
        switch self {
        case .networkError:
            return "Network error occurred. Please check your internet connection."
        case .apiError(let statusCode, let message):
            return "API error (Status \(statusCode)): \(message)"
        case .invalidResponseFormat:
            return "Invalid response format from the API."
        case .missingAPIKey:
            return "API key is missing. Please set it in Settings."
        }
    }
}
