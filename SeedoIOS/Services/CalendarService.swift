import Foundation
import EventKit
import SwiftUI

struct SessionSyncData: Sendable {
    let id: UUID
    let title: String
    let startTimestamp: Date
    let endTimestamp: Date
    let summary: String
    let outcome: String
    
    init(from session: WorkSession) {
        self.id = session.id
        self.title = session.title
        self.startTimestamp = session.startTimestamp
        self.endTimestamp = session.endTimestamp
        self.summary = session.summary
        self.outcome = session.outcome
    }
}

class CalendarService: @unchecked Sendable {
    static let shared = CalendarService()
    
    private let eventStore = EKEventStore()
    private let calendarName = "Seedo"
    
    @AppStorage("calendar_sync_enabled") var isSyncEnabled: Bool = false
    
    private init() {}
    
    func requestAccess(completion: @escaping (Bool) -> Void) {
        let status = EKEventStore.authorizationStatus(for: .event)
        
        switch status {
        case .authorized, .fullAccess:
            completion(true)
        case .notDetermined:
            eventStore.requestFullAccessToEvents { granted, error in
                DispatchQueue.main.async {
                    completion(granted)
                }
            }
        case .denied, .restricted:
            completion(false)
        case .writeOnly:
            completion(true)
        @unknown default:
            completion(false)
        }
    }
    
    private func findOrCreateCalendar() throws -> EKCalendar {
        let calendars = eventStore.calendars(for: .event)
        if let existing = calendars.first(where: { $0.title == calendarName }) {
            return existing
        }
        
        let newCalendar = EKCalendar(for: .event, eventStore: eventStore)
        newCalendar.title = calendarName
        
        // Pick a source (prefer iCloud, then Local)
        let source = eventStore.sources.first(where: { $0.sourceType == .calDAV && $0.title.localizedCaseInsensitiveContains("iCloud") })
                  ?? eventStore.sources.first(where: { $0.sourceType == .local })
                  ?? eventStore.defaultCalendarForNewEvents?.source
        
        if let source = source {
            newCalendar.source = source
        } else {
            throw NSError(domain: "CalendarService", code: 1, userInfo: [NSLocalizedDescriptionKey: "No suitable calendar source found."])
        }
        
        try eventStore.saveCalendar(newCalendar, commit: true)
        return newCalendar
    }
    
    func sync(session: WorkSession) {
        let data = SessionSyncData(from: session)
        syncData(data)
    }
    
    func syncData(_ data: SessionSyncData) {
        guard isSyncEnabled else { return }
        
        requestAccess { [weak self] granted in
            guard let self = self, granted else { return }
            
            do {
                let calendar = try self.findOrCreateCalendar()
                
                // Check if event already exists for this session using title and ID marker in notes
                let predicate = self.eventStore.predicateForEvents(withStart: data.startTimestamp.addingTimeInterval(-5),
                                                                    end: data.startTimestamp.addingTimeInterval(5),
                                                                    calendars: [calendar])
                let existingEvents = self.eventStore.events(matching: predicate)
                
                let event: EKEvent
                let idMarker = "SeedoID: \(data.id.uuidString)"
                
                if let existing = existingEvents.first(where: { ($0.notes ?? "").contains(idMarker) }) {
                    event = existing
                } else if let existing = existingEvents.first(where: { $0.title == data.title }) {
                    event = existing
                } else {
                    event = EKEvent(eventStore: self.eventStore)
                    event.calendar = calendar
                }
                
                event.title = data.title
                event.startDate = data.startTimestamp
                event.endDate = data.endTimestamp
                
                let durationMins = Int(data.endTimestamp.timeIntervalSince(data.startTimestamp) / 60)
                var notes = "专注时长: \(durationMins) 分钟\n状态: \(data.outcome == "completed" ? "完成" : "中断")\n"
                if !data.summary.isEmpty {
                    notes += "备注: \(data.summary)\n"
                }
                notes += "\n\(idMarker)"
                event.notes = notes
                
                // Save event
                try self.eventStore.save(event, span: .thisEvent, commit: true)
                print("[Calendar] Synced session: \(data.title)")
            } catch {
                print("[Calendar] Sync failed: \(error.localizedDescription)")
            }
        }
    }
    
    func delete(session: WorkSession) {
        let start = session.startTimestamp
        let title = session.title
        
        requestAccess { [weak self] granted in
            guard let self = self, granted else { return }
            
            do {
                let calendars = self.eventStore.calendars(for: .event).filter { $0.title == self.calendarName }
                guard !calendars.isEmpty else { return }
                
                let predicate = self.eventStore.predicateForEvents(withStart: start.addingTimeInterval(-5),
                                                                    end: start.addingTimeInterval(5),
                                                                    calendars: calendars)
                let existingEvents = self.eventStore.events(matching: predicate)
                
                for event in existingEvents {
                    if event.title.contains(title) {
                        try self.eventStore.remove(event, span: .thisEvent, commit: true)
                    }
                }
            } catch {
                print("[Calendar] Delete failed: \(error.localizedDescription)")
            }
        }
    }
    
    func forceSyncAll(sessions: [WorkSession]) async {
        // Map to Sendable data on the calling thread (MainActor)
        let dataToSync = sessions.map { SessionSyncData(from: $0) }
        
        await withCheckedContinuation { continuation in
            requestAccess { granted in
                guard granted else { 
                    continuation.resume()
                    return 
                }
                
                // Offload the heavy loop to a background thread with safe data
                DispatchQueue.global(qos: .userInitiated).async {
                    for data in dataToSync {
                        self.syncData(data)
                    }
                    continuation.resume()
                }
            }
        }
    }
}
