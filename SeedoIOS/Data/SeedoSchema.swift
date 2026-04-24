import Foundation
import SwiftData
import SwiftUI

@Model
final class SessionCategory: Identifiable, Codable {
    @Attribute(.unique) var id: String
    var name: String
    var colorHex: String
    var displayOrder: Int = 0
    
    init(id: String, name: String, colorHex: String, displayOrder: Int = 0) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.displayOrder = displayOrder
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name
        case colorHex = "color"
        case displayOrder = "display_order"
    }
    
    // Codable implementation for @Model is needed because SwiftData doesn't auto-generate it well for relationships
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        colorHex = try container.decode(String.self, forKey: .colorHex)
        displayOrder = try container.decodeIfPresent(Int.self, forKey: .displayOrder) ?? 0
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(colorHex, forKey: .colorHex)
        try container.encode(displayOrder, forKey: .displayOrder)
    }
    
    var color: Color {
        Color(hex: colorHex) ?? .gray
    }
    
    static var defaults: [SessionCategory] {
        [
            SessionCategory(id: "focus", name: "专注", colorHex: "#FF3B30", displayOrder: 0),
            SessionCategory(id: "work", name: "工作", colorHex: "#007AFF", displayOrder: 1),
            SessionCategory(id: "study", name: "学习", colorHex: "#34C759", displayOrder: 2),
            SessionCategory(id: "other", name: "其他", colorHex: "#8E8E93", displayOrder: 3)
        ]
    }
}

@Model
final class DailySummary: Identifiable, Codable {
    @Attribute(.unique) var date: String // YYYY-MM-DD
    var content: String
    var score: Int
    var keywords: String
    var createdAt: Date
    
    init(date: String, content: String = "", score: Int = 0, keywords: String = "", createdAt: Date = Date()) {
        self.date = date
        self.content = content
        self.score = score
        self.keywords = keywords
        self.createdAt = createdAt
    }
    
    enum CodingKeys: String, CodingKey {
        case date, content, score, keywords
        case created_at
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        date = try container.decode(String.self, forKey: .date)
        content = try container.decode(String.self, forKey: .content)
        score = try container.decode(Int.self, forKey: .score)
        keywords = try container.decode(String.self, forKey: .keywords)
        let createdTs = try container.decode(Int64.self, forKey: .created_at)
        createdAt = Date(timeIntervalSince1970: Double(createdTs) / 1000.0)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(date, forKey: .date)
        try container.encode(content, forKey: .content)
        try container.encode(score, forKey: .score)
        try container.encode(keywords, forKey: .keywords)
        try container.encode(Int64(createdAt.timeIntervalSince1970 * 1000), forKey: .created_at)
    }
}

@Model
final class WorkSession: Identifiable, Codable {
    @Attribute(.unique) var id: UUID
    var title: String
    var summary: String
    var startTimestamp: Date
    var endTimestamp: Date
    var createdAt: Date
    var isManual: Bool
    var outcome: String // "completed", "interrupted"
    var categoryId: String? // Transitory property for JSON import
    
    @Relationship(deleteRule: .nullify)
    var category: SessionCategory?
    
    init(title: String, summary: String = "", startTimestamp: Date, endTimestamp: Date, category: SessionCategory? = nil, isManual: Bool = true, outcome: String = "completed") {
        self.id = UUID()
        self.title = title
        self.summary = summary
        self.startTimestamp = startTimestamp
        self.endTimestamp = endTimestamp
        self.createdAt = Date()
        self.category = category
        self.isManual = isManual
        self.outcome = outcome
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case startTs = "start_ts"
        case endTs = "end_ts"
        case summary = "title" // IOS summary (notes) maps to JSON title
        case outcome
        case createdAt = "created_at"
        case isManual = "is_manual"
        case title = "summary" // IOS title (task name) maps to JSON summary
        case categoryId = "category_id"
    }
    
    required init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle ID which could be Int or UUID
        if (try? container.decode(Int64.self, forKey: .id)) != nil {
            // Convert numeric ID to a deterministic UUID or just a new one
            id = UUID() 
        } else if let uuidStr = try? container.decode(String.self, forKey: .id), let uuid = UUID(uuidString: uuidStr) {
            id = uuid
        } else {
            id = UUID()
        }
        
        title = try container.decode(String.self, forKey: .title)
        summary = try container.decode(String.self, forKey: .summary)
        
        let startTs = try container.decode(Int64.self, forKey: .startTs)
        let endTs = try container.decode(Int64.self, forKey: .endTs)
        startTimestamp = Date(timeIntervalSince1970: Double(startTs) / 1000.0)
        endTimestamp = Date(timeIntervalSince1970: Double(endTs) / 1000.0)
        
        let createdTs = try container.decode(Int64.self, forKey: .createdAt)
        createdAt = Date(timeIntervalSince1970: Double(createdTs) / 1000.0)
        
        isManual = try container.decode(Bool.self, forKey: .isManual)
        outcome = try container.decode(String.self, forKey: .outcome)
        categoryId = try container.decodeIfPresent(String.self, forKey: .categoryId)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(summary, forKey: .summary)
        try container.encode(Int64(startTimestamp.timeIntervalSince1970 * 1000), forKey: .startTs)
        try container.encode(Int64(endTimestamp.timeIntervalSince1970 * 1000), forKey: .endTs)
        try container.encode(Int64(createdAt.timeIntervalSince1970 * 1000), forKey: .createdAt)
        try container.encode(isManual, forKey: .isManual)
        try container.encode(outcome, forKey: .outcome)
        try container.encode(category?.id, forKey: .categoryId)
    }
    
    var displayTitle: String {
        if !title.isEmpty { return title }
        if !summary.isEmpty { return summary }
        return "专注记录"
    }

    var duration: TimeInterval {
        endTimestamp.timeIntervalSince(startTimestamp)
    }
}

// Helper for Color Hex
extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else { return nil }

        let r, g, b: Double
        if hexSanitized.count == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            self.init(.sRGB, red: r, green: g, blue: b, opacity: 1.0)
        } else {
            return nil
        }
    }
}
