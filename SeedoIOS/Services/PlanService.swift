import Foundation

class PlanService {
    static let shared = PlanService()
    private init() {}
    
    private var dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        return df
    }()
    
    enum PlanScope {
        case daily, monthly, yearly
        
        var keyPrefix: String {
            switch self {
            case .daily: return "plan_daily"
            case .monthly: return "plan_monthly"
            case .yearly: return "plan_yearly"
            }
        }
        
        func dateKey(for date: Date) -> String {
            let df = DateFormatter()
            df.locale = Locale(identifier: "en_US_POSIX")
            switch self {
            case .daily: df.dateFormat = "yyyy-MM-dd"
            case .monthly: df.dateFormat = "yyyy-MM"
            case .yearly: df.dateFormat = "yyyy"
            }
            return "\(keyPrefix):\(df.string(from: date))"
        }
    }
    
    func savePlan(content: String, scope: PlanScope, date: Date = Date()) {
        UserDefaults.standard.set(content, forKey: scope.dateKey(for: date))
    }
    
    func getPlan(scope: PlanScope, date: Date = Date()) -> String {
        return UserDefaults.standard.string(forKey: scope.dateKey(for: date)) ?? ""
    }
}
