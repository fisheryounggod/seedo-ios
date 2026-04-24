import Foundation

class GeminiService {
    static let shared = GeminiService()
    private let baseUrl = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"
    
    func reviewSessions(sessions: [WorkSession], apiKey: String) async throws -> String {
        guard !apiKey.isEmpty else { return "请在设置中配置 API 密钥。" }
        
        let sessionData = sessions.map { "标题: \($0.title), 详情: \($0.summary), 时长: \(Int($0.duration/60))min" }.joined(separator: "\n")
        
        let prompt = """
        作为一个生产力教练，请分析以下专注记录并提供简洁、有启发性的复盘建议（150字以内）：
        
        \(sessionData)
        """
        
        let payload: [String: Any] = [
            "contents": [
                ["parts": [["text": prompt]]]
            ]
        ]
        
        var request = URLRequest(url: URL(string: "\(baseUrl)?key=\(apiKey)")!)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)
        
        let (data, _) = try await URLSession.shared.data(for: request)
        let response = try JSONDecoder().decode(GeminiResponse.self, from: data)
        return response.candidates.first?.content.parts.first?.text ?? "无法生成复盘。"
    }
}

struct GeminiResponse: Codable {
    struct Candidate: Codable {
        struct Content: Codable {
            struct Part: Codable {
                let text: String
            }
            let parts: [Part]
        }
        let content: Content
    }
    let candidates: [Candidate]
}
