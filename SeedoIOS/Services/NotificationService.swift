import Foundation
import UserNotifications

class NotificationService: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationService()
    
    override init() {
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }
    
    func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if granted {
                print("[NotificationService] Permission granted")
            } else if let error = error {
                print("[NotificationService] Permission error: \(error.localizedDescription)")
            }
        }
    }
    
    func scheduleReminders(times: [Date]) {
        // Deterministic removal of potential old focus reminders to avoid race conditions
        let dailyIds = (0..<20).map { "daily_focus_reminder_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: dailyIds)
        
        let content = UNMutableNotificationContent()
        content.title = "该开启专注了"
        content.body = "设定一个小目标，开始今天的深度工作吧！"
        content.sound = .default
        
        let calendar = Calendar.current
        for (index, time) in times.enumerated() {
            // Cap at 20 to match our cleanup range
            guard index < 20 else { break }
            
            let components = calendar.dateComponents([.hour, .minute], from: time)
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            let request = UNNotificationRequest(identifier: "daily_focus_reminder_\(index)", content: content, trigger: trigger)
            
            UNUserNotificationCenter.current().add(request)
        }
        print("[NotificationService] Scheduled \(times.count) daily reminders")
    }
    
    func scheduleUsageReminder(intervalMinutes: Int) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["usage_reminder"])
        
        guard intervalMinutes > 0 else { return }
        
        let content = UNMutableNotificationContent()
        content.title = "使用手机太久啦"
        content.body = "您已经连续使用手机一段时间了，不如开启一轮专注来换个脑筋？"
        content.sound = .default
        
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: Double(intervalMinutes * 60), repeats: true)
        let request = UNNotificationRequest(identifier: "usage_reminder", content: content, trigger: trigger)
        
        UNUserNotificationCenter.current().add(request)
        print("[NotificationService] Scheduled usage reminder every \(intervalMinutes) mins")
    }
    
    func cancelAllReminders() {
        // Synchronous removal by identifiers (queued in system)
        let dailyIds = (0..<20).map { "daily_focus_reminder_\($0)" }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: dailyIds + ["usage_reminder"])
        print("[NotificationService] All relevant reminders cancelled")
    }
    
    func rescheduleIfEnabled() {
        if UserDefaults.standard.bool(forKey: "isReminderEnabled") {
            let times = getStoredReminderTimes()
            scheduleReminders(times: times)
        } else {
            let dailyIds = (0..<20).map { "daily_focus_reminder_\($0)" }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: dailyIds)
        }
        
        if UserDefaults.standard.bool(forKey: "isUsageReminderEnabled") {
            let interval = UserDefaults.standard.integer(forKey: "usageReminderInterval")
            scheduleUsageReminder(intervalMinutes: interval)
        } else {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["usage_reminder"])
        }
    }
    
    func getStoredReminderTimes() -> [Date] {
        guard let data = UserDefaults.standard.data(forKey: "reminderTimes"),
              let dates = try? JSONDecoder().decode([Date].self, from: data) else {
            return [defaultTime()]
        }
        return dates
    }
    
    private func defaultTime() -> Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
    
    // MARK: - UNUserNotificationCenterDelegate
    
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // Show banner and play sound even if app is in foreground
        completionHandler([.banner, .sound])
    }
}
