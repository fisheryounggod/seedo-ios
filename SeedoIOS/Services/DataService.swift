import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

// Compatible with SeedoMac version 2.0.0
struct BackupData: Codable {
    var version: String = "2.0.0"
    var exportDate: Date = Date()
    var workSessions: [WorkSession]
    var dailySummaries: [DailySummary] = []
    var categories: [SessionCategory]
}

class DataService {
    static let shared = DataService()
    
    // MARK: - JSON (Mac Compatible)
    
    func exportToJSON(sessions: [WorkSession], categories: [SessionCategory]) -> Data? {
        let backup = BackupData(workSessions: sessions, categories: categories)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        encoder.dateEncodingStrategy = .iso8601
        return try? encoder.encode(backup)
    }
    
    func parseJSON(data: Data, existingSessions: [WorkSession], categories: [SessionCategory]) -> 
        (sessions: [WorkSession], categories: [SessionCategory], summaries: [DailySummary], skipped: Int) {
        
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        guard let backup = try? decoder.decode(BackupData.self, from: data) else {
            print("[DataService] JSON decode failed")
            return ([], [], [], 0)
        }
        
        var newCategories: [SessionCategory] = []
        for cat in backup.categories {
            if !categories.contains(where: { $0.id == cat.id }) {
                newCategories.append(cat)
            }
        }
        
        var newSessions: [WorkSession] = []
        var skippedCount = 0
        for session in backup.workSessions {
            // Deduplication: check if a session with same start and end time already exists
            let isDuplicate = existingSessions.contains { 
                abs($0.startTimestamp.timeIntervalSince(session.startTimestamp)) < 1 && 
                abs($0.endTimestamp.timeIntervalSince(session.endTimestamp)) < 1
            } || newSessions.contains {
                abs($0.startTimestamp.timeIntervalSince(session.startTimestamp)) < 1 && 
                abs($0.endTimestamp.timeIntervalSince(session.endTimestamp)) < 1
            }
            
            if !isDuplicate {
                // Resolve relationship: Prefer existing categories from DB, then new ones from JSON
                if let catId = session.categoryId {
                    session.category = categories.first { $0.id == catId } 
                        ?? newCategories.first { $0.id == catId }
                }
                newSessions.append(session)
            } else {
                skippedCount += 1
            }
        }
        
        return (newSessions, newCategories, backup.dailySummaries, skippedCount)
    }
    
    /// Finds and returns a list of duplicate sessions that should be removed
    func findDuplicates(in sessions: [WorkSession]) -> [WorkSession] {
        var uniqueSessions: [WorkSession] = []
        var duplicates: [WorkSession] = []
        
        for session in sessions {
            let isDuplicate = uniqueSessions.contains {
                abs($0.startTimestamp.timeIntervalSince(session.startTimestamp)) < 0.1 && 
                abs($0.endTimestamp.timeIntervalSince(session.endTimestamp)) < 0.1
            }
            
            if isDuplicate {
                duplicates.append(session)
            } else {
                uniqueSessions.append(session)
            }
        }
        
        return duplicates
    }

    // MARK: - CSV (Legacy)
    
    private let headers = "ID,Title,Category,StartTime,EndTime,Summary,Outcome\n"
    private let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return df
    }()
    
    func exportToCSV(sessions: [WorkSession]) -> String {
        var csvString = headers
        for session in sessions {
            let categoryName = session.category?.name ?? "None"
            let row = [
                session.id.uuidString,
                session.title.replacingOccurrences(of: ",", with: " "),
                categoryName,
                dateFormatter.string(from: session.startTimestamp),
                dateFormatter.string(from: session.endTimestamp),
                session.summary.replacingOccurrences(of: ",", with: " "),
                session.outcome
            ].joined(separator: ",")
            csvString += row + "\n"
        }
        return csvString
    }
    
    func parseCSV(content: String, existingSessions: [WorkSession], categories: [SessionCategory]) -> [WorkSession] {
        let rows = content.components(separatedBy: "\n").filter { !$0.isEmpty }
        guard rows.count > 1 else { return [] }
        
        var newSessions: [WorkSession] = []
        for i in 1..<rows.count {
            let columns = rows[i].components(separatedBy: ",")
            guard columns.count >= 7 else { continue }
            
            let title = columns[1]
            let categoryName = columns[2]
            guard let start = dateFormatter.date(from: columns[3]),
                  let end = dateFormatter.date(from: columns[4]) else { continue }
            let summary = columns[5]
            let outcome = columns[6]
            
            let isDuplicate = existingSessions.contains { 
                abs($0.startTimestamp.timeIntervalSince(start)) < 1 && abs($0.endTimestamp.timeIntervalSince(end)) < 1
            }
            
            if !isDuplicate {
                let category = categories.first { $0.name == categoryName }
                let session = WorkSession(title: title, summary: summary, startTimestamp: start, endTimestamp: end, category: category, isManual: true, outcome: outcome)
                newSessions.append(session)
            }
        }
        return newSessions
    }
}

// MARK: - Document Wrappers

struct JSONDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data
    
    init(data: Data) { self.data = data }
    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: data)
    }
}

struct CSVDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.commaSeparatedText] }
    var text: String
    
    init(text: String) { self.text = text }
    init(configuration: ReadConfiguration) throws {
        if let data = configuration.file.regularFileContents {
            text = String(data: data, encoding: .utf8) ?? ""
        } else {
            text = ""
        }
    }
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return .init(regularFileWithContents: text.data(using: .utf8)!)
    }
}
