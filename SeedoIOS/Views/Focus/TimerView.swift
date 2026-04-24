import SwiftUI
import SwiftData

struct TimerView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.modelContext) private var modelContext
    
    var body: some View {
        ZStack {
            // Premium background gradient
            LinearGradient(colors: [Color(white: 0.05), .black], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            
            VStack(spacing: 40) {
                // Header
                HStack(spacing: 12) {
                    Button(action: { appState.toggleMode() }) {
                        Text(appState.activeMode == .countdown ? "蕃茄钟" : "正计时")
                            .font(.system(size: 14, weight: .bold))
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Capsule())
                    }
                    
                    Button(action: { appState.showingManualEntry = true }) {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 14, weight: .bold))
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Button(action: {
                        let current = UserDefaults.standard.bool(forKey: "isTickingEnabled")
                        UserDefaults.standard.set(!current, forKey: "isTickingEnabled")
                    }) {
                        Image(systemName: UserDefaults.standard.bool(forKey: "isTickingEnabled") ? "speaker.wave.2.fill" : "speaker.slash.fill")
                            .foregroundStyle(.secondary)
                            .padding(8)
                            .background(Color.white.opacity(0.1))
                            .clipShape(Circle())
                    }
                }
                .padding()
                
                Spacer()
                
                // Timer Circle
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.05), lineWidth: 15)
                    
                    let progress = appState.activeMode == .countdown 
                        ? (1.0 - Double(appState.remainingSeconds) / Double(25 * 60))
                        : 1.0
                    
                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            appState.activeMode == .countdown ? Color.green : Color.blue,
                            style: StrokeStyle(lineWidth: 15, lineCap: .round)
                        )
                        .shadow(color: (appState.activeMode == .countdown ? Color.green : Color.blue).opacity(0.5), radius: 10)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: progress)
                    
                    VStack(spacing: 8) {
                        let displaySecs = appState.activeMode == .countdown ? appState.remainingSeconds : appState.elapsedSeconds
                        Text(appState.formatTime(displaySecs))
                            .font(.system(size: 85, weight: .bold, design: .monospaced))
                            .shadow(color: .white.opacity(0.1), radius: 5)
                            .contentTransition(.numericText())
                        
                        Text(appState.activeMode == .countdown ? "剩余时间" : "已用时间")
                            .font(.caption)
                            .tracking(2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 300, height: 300)
                
                Spacer()
                
                // Controls
                HStack(spacing: 50) {
                    if appState.isTimerRunning {
                        Button(action: { appState.pauseTimer() }) {
                            CircleControl(icon: "pause.fill", color: .orange)
                        }
                    } else {
                        Button(action: { appState.startTimer() }) {
                            CircleControl(icon: "play.fill", color: .green)
                        }
                    }
                    
                    Button(action: { appState.stopTimer(completed: true) }) {
                        CircleControl(icon: "stop.fill", color: .red)
                    }
                }
                .padding(.bottom, 50)
            }
            .foregroundStyle(.white)
        }
    }
}

struct CircleControl: View {
    let icon: String
    let color: Color
    
    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.2))
                .frame(width: 80, height: 80)
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
        }
    }
}
