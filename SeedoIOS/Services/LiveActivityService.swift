import Foundation
import ActivityKit

class LiveActivityService {
    static let shared = LiveActivityService()
    private var currentActivity: Activity<FocusActivityAttributes>?
    
    func startSession(modeName: String, duration: Int) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        // If there's already an active session, just update it to "running" state
        if !Activity<FocusActivityAttributes>.activities.isEmpty {
            updateSession(isPaused: false, remainingSeconds: duration, modeName: modeName)
            return
        }
        
        let attributes = FocusActivityAttributes(totalSeconds: duration)
        let state = FocusActivityAttributes.ContentState(
            endTime: Date().addingTimeInterval(Double(duration)),
            modeName: modeName,
            isPaused: false,
            remainingSeconds: duration
        )
        
        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: .init(state: state, staleDate: nil)
            )
        } catch {
            print("Failed to start Live Activity: \(error)")
        }
    }
    
    func updateSession(isPaused: Bool, remainingSeconds: Int, modeName: String) {
        Task {
            let state = FocusActivityAttributes.ContentState(
                endTime: Date().addingTimeInterval(Double(remainingSeconds)),
                modeName: modeName,
                isPaused: isPaused,
                remainingSeconds: remainingSeconds
            )
            for activity in Activity<FocusActivityAttributes>.activities {
                await activity.update(.init(state: state, staleDate: nil))
            }
        }
    }
    
    func endSession() {
        Task {
            for activity in Activity<FocusActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
