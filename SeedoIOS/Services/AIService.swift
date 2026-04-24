import Foundation

enum AIError: LocalizedError {
    case noAPIKey, invalidConfig, badResponse, networkError(Error)
    
    var errorDescription: String? {
        switch self {
        case .noAPIKey: return "未配置 API Key，请前往设置添加。"
        case .invalidConfig: return "无效的 AI 配置。"
        case .badResponse: return "AI 返回了非预期的响应。"
        case .networkError(let e): return "网络错误: \(e.localizedDescription)"
        }
    }
}

struct SummaryContext {
    let dateRange: String
    let workSessions: [WorkSession]
    let planDaily: String?
    let planMonthly: String?
    let planYearly: String?
}

class AIService {
    static let shared = AIService()
    private init() {}
    
    private var baseURL: String {
        let saved = UserDefaults.standard.string(forKey: "ai_base_url") ?? ""
        return saved.isEmpty ? "https://api.siliconflow.cn/v1" : saved
    }
    
    private var model: String {
        let saved = UserDefaults.standard.string(forKey: "ai_model") ?? ""
        return saved.isEmpty ? "deepseek-ai/DeepSeek-V3" : saved
    }
    
    func generateSummary(
        context: SummaryContext,
        periodLabel: String,
        completion: @escaping (Result<DailySummary, Error>) -> Void
    ) {
        guard let apiKey = KeychainHelper.shared.load(), !apiKey.isEmpty else {
            completion(.failure(AIError.noAPIKey))
            return
        }
        
        let systemPrompt = """
        你正在为寻求极致效能的专业人士提供工作复盘。
        请根据数据生成一份“深度工作复盘报告”，包含以下模块，并使用 Markdown 格式：

        - **工具磨刀时间（非核心产出）**：量化低效能行为。
        - **核心产出时间**：量化核心目标产出。
        - **效能比率**：核心时间占比及评价。
        - **效能痛点**：如碎片化过高、工具沉迷、无效维护等。
        - **目标进度**：对比计划，列举完成度（使用 ✅/❌ 引导）。
        - **明日前三专注块建议（最小阻力原则）**：给出具体的时间点、时长和任务（如 09:00-10:30 | 90m | 任务名）。

        规则：
        1. 语气严谨、专业、不啰嗦。
        2. 最后务必附带以下解析行：
        SCORE: X
        KEYWORDS: 关键字1, 关键字2, 关键字3
        """
        
        let userContent = buildPrompt(context: context, periodLabel: periodLabel)
        
        let body: [String: Any] = [
            "model": model,
            "stream": false,
            "messages": [
                ["role": "system", "content": systemPrompt],
                ["role": "user",   "content": userContent],
            ],
            "temperature": 0.7
        ]
        
        guard let url = URL(string: "\(baseURL)/chat/completions"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            completion(.failure(AIError.invalidConfig))
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = bodyData
        request.timeoutInterval = 60
        
        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(AIError.networkError(error))); return
            }
            
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let choices = json["choices"] as? [[String: Any]],
                  let message = choices.first?["message"] as? [String: Any],
                  let content = message["content"] as? String else {
                completion(.failure(AIError.badResponse)); return
            }
            
            let summary = self.parseSummary(date: context.dateRange, content: content)
            completion(.success(summary))
        }.resume()
    }
    
    private func buildPrompt(context: SummaryContext, periodLabel: String) -> String {
        var lines = ["时间范围：\(periodLabel)", ""]
        
        // Focused Work Sessions
        if !context.workSessions.isEmpty {
            lines += ["# 工作实绩 (专注会话 & 手动记录)", "共计：\(context.workSessions.count) 段"]
            for ws in context.workSessions.sorted(by: { $0.startTimestamp < $1.startTimestamp }) {
                let timeStr = ws.startTimestamp.formatted(date: .omitted, time: .shortened)
                let typePrefix = ws.isManual ? "[手动]" : "[自动]"
                lines.append("- \(typePrefix) \(timeStr) | \(Int(ws.duration/60))m | \(ws.displayTitle)")
                if !ws.summary.isEmpty && ws.displayTitle != ws.summary {
                    lines.append("  背景/备注：\(ws.summary)")
                }
            }
        }
        
        // Goals/Plans
        if (context.planDaily?.isEmpty == false) || (context.planMonthly?.isEmpty == false) || (context.planYearly?.isEmpty == false) {
            lines += ["", "# 目标对齐 (Target Goals)", "请结合以下设定的目标评估："]
            if let d = context.planDaily, !d.isEmpty { lines.append("- 今日任务: \(d)") }
            if let m = context.planMonthly, !m.isEmpty { lines.append("- 本阶段计划: \(m)") }
            if let y = context.planYearly, !y.isEmpty { lines.append("- 长期愿景: \(y)") }
        }
        
        return lines.joined(separator: "\n")
    }
    
    private func parseSummary(date: String, content: String) -> DailySummary {
        var score = 0
        var keywords = ""
        var bodyLines: [String] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("SCORE:") {
                let val = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
                score = Int(val) ?? 0
            } else if trimmed.hasPrefix("KEYWORDS:") {
                keywords = trimmed.dropFirst(9).trimmingCharacters(in: .whitespaces)
            } else {
                bodyLines.append(line)
            }
        }

        return DailySummary(
            date: date,
            content: bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines),
            score: min(5, max(0, score)),
            keywords: keywords,
            createdAt: Date()
        )
    }
}
