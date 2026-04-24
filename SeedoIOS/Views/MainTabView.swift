import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TimerView()
                .tabItem {
                    Label("专注", systemImage: "timer")
                }
                .tag(0)
            
            StatsView()
                .tabItem {
                    Label("洞察", systemImage: "chart.bar.fill")
                }
                .tag(1)
            
            SettingsView()
                .tabItem {
                    Label("设置", systemImage: "gearshape.fill")
                }
                .tag(2)
        }
        .tint(.green)
        .sheet(isPresented: $appState.showingLogOverlay) {
            SessionLogView()
        }
        .sheet(isPresented: $appState.showingManualEntry) {
            SessionEditorView()
        }
    }
}
