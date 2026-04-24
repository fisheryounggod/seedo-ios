import Foundation
import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    @Published var selectedTab = 0
    @Published var isTimerRunning = false
    @Published var elapsedSeconds: Int = 0
    @Published var remainingSeconds: Int = 25 * 60
    @Published var activeMode: FocusMode = .countdown
    @Published var showingLogOverlay = false
    @Published var showingManualEntry = false
    
    enum FocusMode: String {
        case countdown
        case stopwatch
    }
    
    private var timer: AnyCancellable?
    private var sessionStart: Date?
    
    init() {
        loadPersistedState()
    }
    
    func handleQuickAction(_ shortcutType: String) {
        switch shortcutType {
        case "tech.seedo.ios.focus25":
            selectedTab = 0
            resetTimer()
            startTimer()
        case "tech.seedo.ios.insights":
            selectedTab = 1
        case "tech.seedo.ios.settings":
            selectedTab = 2
        case "tech.seedo.ios.add_record":
            showingManualEntry = true
        default:
            break
        }
    }
    
    func startTimer() {
        isTimerRunning = true
        if sessionStart == nil {
            sessionStart = Date()
        }
        
        persistState()
        
        let modeName = activeMode == .countdown ? "蕃茄钟" : "正计时"
        LiveActivityService.shared.startSession(modeName: modeName, duration: remainingSeconds)
        NotificationService.shared.cancelAllReminders()
        
        timer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self else { return }
                self.updateTimerUI()
            }
    }
    
    private func updateTimerUI() {
        guard let start = sessionStart else { return }
        let now = Date()
        let totalElapsed = Int(now.timeIntervalSince(start))
        
        // Play ticking sound
        if isTimerRunning {
            SoundService.shared.playTick()
        }
        
        if activeMode == .countdown {
            let initial = UserDefaults.standard.integer(forKey: "timer_initial_remaining")
            let remaining = initial - totalElapsed
            if remaining <= 0 {
                self.remainingSeconds = 0
                self.stopTimer(completed: true)
            } else {
                self.remainingSeconds = remaining
                self.elapsedSeconds = totalElapsed
            }
        } else {
            self.elapsedSeconds = totalElapsed
        }
    }
    
    func pauseTimer() {
        isTimerRunning = false
        timer?.cancel()
        persistState()
        let modeName = activeMode == .countdown ? "蕃茄钟" : "正计时"
        LiveActivityService.shared.updateSession(isPaused: true, remainingSeconds: remainingSeconds, modeName: modeName)
    }
    
    func stopTimer(completed: Bool = false) {
        isTimerRunning = false
        timer?.cancel()
        sessionStart = nil
        clearPersistedState()
        
        LiveActivityService.shared.endSession()
        NotificationService.shared.rescheduleIfEnabled()
        if completed {
            SoundService.shared.playDing()
            showingLogOverlay = true
        }
    }
    
    func resetTimer() {
        stopTimer()
        elapsedSeconds = 0
        remainingSeconds = 25 * 60
    }
    
    func toggleMode() {
        activeMode = (activeMode == .countdown) ? .stopwatch : .countdown
        resetTimer()
    }
    
    // MARK: - Persistence
    private func persistState() {
        UserDefaults.standard.set(isTimerRunning, forKey: "timer_is_running")
        UserDefaults.standard.set(activeMode.rawValue, forKey: "timer_mode")
        UserDefaults.standard.set(sessionStart, forKey: "timer_start_date")
        if activeMode == .countdown && sessionStart != nil {
            // Store the initial countdown value to accurately recalculate later
            let initial = UserDefaults.standard.integer(forKey: "timer_initial_remaining")
            if initial == 0 {
                UserDefaults.standard.set(remainingSeconds, forKey: "timer_initial_remaining")
            }
        }
    }
    
    private func loadPersistedState() {
        let running = UserDefaults.standard.bool(forKey: "timer_is_running")
        if let modeStr = UserDefaults.standard.string(forKey: "timer_mode"),
           let mode = FocusMode(rawValue: modeStr) {
            activeMode = mode
        }
        
        if let start = UserDefaults.standard.object(forKey: "timer_start_date") as? Date {
            sessionStart = start
            if running {
                updateTimerUI()
                startTimer()
            } else {
                // Handle paused state if needed
            }
        }
    }
    
    private func clearPersistedState() {
        UserDefaults.standard.removeObject(forKey: "timer_is_running")
        UserDefaults.standard.removeObject(forKey: "timer_mode")
        UserDefaults.standard.removeObject(forKey: "timer_start_date")
        UserDefaults.standard.removeObject(forKey: "timer_initial_remaining")
    }
    
    func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
