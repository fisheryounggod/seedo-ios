import SwiftUI
import WidgetKit
import ActivityKit

@main
struct SeedoWidgetBundle: WidgetBundle {
    var body: some Widget {
        SeedoActivityWidget()
    }
}

struct SeedoActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: FocusActivityAttributes.self) { context in
            // Lock Screen UI - Simplified to only show timer
            HStack {
                Spacer()
                if context.state.isPaused {
                    Text(formatTime(context.state.remainingSeconds))
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.endTime, style: .timer)
                        .font(.system(size: 48, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                        .frame(width: 160) // Ensure stable width for timer
                }
                Spacer()
            }
            .padding(.vertical, 24)
            .activityBackgroundTint(Color.black.opacity(0.8))

        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded UI
                DynamicIslandExpandedRegion(.leading) {
                    Label("Seedo", systemImage: context.state.isPaused ? "pause.circle" : "seedling")
                        .foregroundStyle(context.state.isPaused ? .orange : .green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isPaused {
                        Text(formatTime(context.state.remainingSeconds))
                            .monospacedDigit()
                            .font(.headline)
                            .foregroundStyle(.orange)
                    } else {
                        Text(context.state.endTime, style: .timer)
                            .monospacedDigit()
                            .font(.headline)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    Text(context.state.isPaused ? "已暂停：\(context.state.modeName)" : "保持专注：\(context.state.modeName)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } compactLeading: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(context.state.isPaused ? .orange : .green)
            } compactTrailing: {
                if context.state.isPaused {
                    Text(formatTime(context.state.remainingSeconds))
                        .monospacedDigit()
                        .font(.caption2)
                        .foregroundStyle(.orange)
                } else {
                    Text(context.state.endTime, style: .timer)
                        .monospacedDigit()
                        .font(.caption2)
                }
            } minimal: {
                Image(systemName: context.state.isPaused ? "pause.fill" : "timer")
                    .foregroundStyle(context.state.isPaused ? .orange : .green)
            }
        }
    }
    
    private func formatTime(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%02d:%02d", m, s)
    }
}
