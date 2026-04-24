import Foundation
import SwiftData

class SummaryContextBuilder {
    private var modelContext: ModelContext
    
    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }
    
    func build(for date: Date) throws -> SummaryContext {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: date)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay)!
        
        // Fetch sessions for the day
        let predicate = #Predicate<WorkSession> {
            $0.startTimestamp >= startOfDay && $0.startTimestamp < endOfDay
        }
        
        let descriptor = FetchDescriptor<WorkSession>(predicate: predicate)
        let sessions = (try? modelContext.fetch(descriptor)) ?? []
        
        let dateStr = AIService.dateFormatter.string(from: date)
        
        return SummaryContext(
            dateRange: dateStr,
            workSessions: sessions,
            planDaily: PlanService.shared.getPlan(scope: .daily, date: date),
            planMonthly: PlanService.shared.getPlan(scope: .monthly, date: date),
            planYearly: PlanService.shared.getPlan(scope: .yearly, date: date)
        )
    }
}

extension AIService {
    static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()
}
