import SwiftUI
import SwiftData

class AppDelegate: NSObject, UIApplicationDelegate, UIWindowSceneDelegate {
    var appState: AppState? {
        didSet {
            if let pending = pendingQuickAction {
                Task { @MainActor in
                    appState?.handleQuickAction(pending)
                    pendingQuickAction = nil
                }
            }
        }
    }
    private var pendingQuickAction: String?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil) -> Bool {
        print("SeedoApp: Registering Quick Actions...")
        UIApplication.shared.shortcutItems = [
            UIApplicationShortcutItem(
                type: "tech.seedo.ios.focus25",
                localizedTitle: "开始 25 分钟专注",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "play.circle.fill"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: "tech.seedo.ios.insights",
                localizedTitle: "查看专注统计",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "chart.bar.fill"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: "tech.seedo.ios.settings",
                localizedTitle: "设置",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "gearshape.fill"),
                userInfo: nil
            ),
            UIApplicationShortcutItem(
                type: "tech.seedo.ios.add_record",
                localizedTitle: "手动添加记录",
                localizedSubtitle: nil,
                icon: UIApplicationShortcutIcon(systemImageName: "plus.circle.fill"),
                userInfo: nil
            )
        ]
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        if let shortcutItem = options.shortcutItem {
            if let appState = appState {
                Task { @MainActor in appState.handleQuickAction(shortcutItem.type) }
            } else {
                pendingQuickAction = shortcutItem.type
            }
        }
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }
    
    func windowScene(_ windowScene: UIWindowScene, performActionFor shortcutItem: UIApplicationShortcutItem, completionHandler: @escaping (Bool) -> Void) {
        if let appState = appState {
            Task { @MainActor in
                appState.handleQuickAction(shortcutItem.type)
                completionHandler(true)
            }
        } else {
            pendingQuickAction = shortcutItem.type
            completionHandler(true)
        }
    }
}

@main
struct SeedoApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var delegate
    @StateObject private var appState = AppState()
    
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            WorkSession.self,
            SessionCategory.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView()
                .environmentObject(appState)
                .preferredColorScheme(.dark)
                .onAppear {
                    delegate.appState = appState
                    NotificationService.shared.requestAuthorization()
                    NotificationService.shared.rescheduleIfEnabled()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
