import SwiftUI
import SwiftData

struct SettingsView: View {
    @AppStorage("is_icloud_sync_enabled") private var isICloudEnabled = true
    
    // AI Settings
    @AppStorage("ai_base_url") private var aiBaseUrl = "https://api.siliconflow.cn/v1"
    @AppStorage("ai_model") private var aiModel = "deepseek-ai/DeepSeek-V3"
    @State private var apiKey: String = ""
    
    // Sound Settings
    @AppStorage("isTickingEnabled") private var isTickingEnabled = true
    @AppStorage("isCompletionSoundEnabled") private var isCompletionSoundEnabled = true
    
    // Calendar Settings
    @AppStorage("calendar_sync_enabled") private var isCalendarSyncEnabled = false
    
    // Reminder Settings
    @AppStorage("isReminderEnabled") private var isReminderEnabled = false
    @AppStorage("isUsageReminderEnabled") private var isUsageReminderEnabled = false
    @AppStorage("usageReminderInterval") private var usageReminderInterval = 60
    
    @State private var reminderTimes: [Date] = []
    @State private var debounceTask: Task<Void, Never>?
    
    @Query(sort: \WorkSession.startTimestamp, order: .reverse) private var sessions: [WorkSession]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("声音反馈") {
                    Toggle("专注时嘀嗒声 (Dida)", isOn: $isTickingEnabled)
                    
                    if isTickingEnabled {
                        HStack {
                            Text("自定义 Dida")
                            Spacer()
                            if let name = UserDefaults.standard.string(forKey: "custom_tick") {
                                Text(name).font(.caption).foregroundStyle(.secondary)
                                Button(role: .destructive) { SoundService.shared.removeCustomSound(for: .tick) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            } else {
                                Button("上传音频") { pickingTick = true }
                            }
                        }
                    }
                    
                    Toggle("结束时提示音 (Ding)", isOn: $isCompletionSoundEnabled)
                    
                    if isCompletionSoundEnabled {
                        HStack {
                            Text("自定义 Ding")
                            Spacer()
                            if let name = UserDefaults.standard.string(forKey: "custom_complete") {
                                Text(name).font(.caption).foregroundStyle(.secondary)
                                Button(role: .destructive) { SoundService.shared.removeCustomSound(for: .complete) } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                            } else {
                                Button("上传音频") { pickingDing = true }
                            }
                        }
                    }
                }
                
                Section("AI 复盘设定") {
                    TextField("API Base URL", text: $aiBaseUrl)
                    TextField("模型名称", text: $aiModel)
                    SecureField("API Key", text: $apiKey)
                        .onChange(of: apiKey) { _, newValue in
                            DispatchQueue.global(qos: .userInitiated).async {
                                KeychainHelper.shared.save(newValue)
                            }
                        }
                    
                    Text("提示：推荐使用 SiliconFlow。API Key 将安全存储在系统 Keychain 中。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                
                Section("日历") {
                    Toggle("同步专注记录到日历", isOn: $isCalendarSyncEnabled)
                        .onChange(of: isCalendarSyncEnabled) { _, newValue in
                            if newValue {
                                CalendarService.shared.requestAccess { granted in
                                    isCalendarSyncEnabled = granted
                                    if !granted {
                                        showingCalendarAlert = true
                                    }
                                }
                            }
                        }
                    
                    if isCalendarSyncEnabled {
                        Button("同步所有历史记录到日历") {
                            let currentSessions = sessions
                            Task {
                                await CalendarService.shared.forceSyncAll(sessions: currentSessions)
                            }
                        }
                        .font(.footnote)
                    }
                }
                
                Section("专注提醒") {
                    Toggle("定时提醒开启专注", isOn: $isReminderEnabled)
                        .onChange(of: isReminderEnabled) { _, newValue in
                            triggerReschedule()
                        }
                    
                    if isReminderEnabled {
                        ForEach(0..<reminderTimes.count, id: \.self) { index in
                            DatePicker("提醒时间 \(index + 1)", selection: $reminderTimes[index], displayedComponents: .hourAndMinute)
                        }
                        .onDelete { indices in
                            reminderTimes.remove(atOffsets: indices)
                        }
                        .onChange(of: reminderTimes) { _, _ in
                            triggerReschedule()
                        }
                        
                        Button(action: {
                            reminderTimes.append(defaultReminderTime())
                            triggerReschedule()
                        }) {
                            Label("添加提醒时间", systemImage: "plus.circle")
                        }
                    }
                    
                    Divider()
                    
                    Toggle("连续使用手机提醒", isOn: $isUsageReminderEnabled)
                        .onChange(of: isUsageReminderEnabled) { _, newValue in
                            triggerReschedule()
                        }
                    
                    if isUsageReminderEnabled {
                        Stepper(value: $usageReminderInterval, in: 15...240, step: 15) {
                            Text("使用超过 \(usageReminderInterval == 0 ? 60 : usageReminderInterval) 分钟")
                        }
                        .onChange(of: usageReminderInterval) {
                            triggerReschedule()
                        }
                    }
                }
                
                Section("同步") {
                    Text("本地模式 (免费账号)")
                        .foregroundStyle(.secondary)
                    Text("升级到付费开发者计划以启用 iCloud 同步。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                
                Section("关于 Seedo") {
                    HStack {
                        Text("版本")
                        Spacer()
                        Text("2.0.2 (iOS)")
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .navigationTitle("设置")
            .fileImporter(isPresented: $pickingTick, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result {
                    _ = SoundService.shared.saveCustomSound(from: url, for: .tick)
                }
            }
            .fileImporter(isPresented: $pickingDing, allowedContentTypes: [.audio]) { result in
                if case .success(let url) = result {
                    _ = SoundService.shared.saveCustomSound(from: url, for: .complete)
                }
            }
            .alert("无法访问日历", isPresented: $showingCalendarAlert) {
                Button("去设置") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                Button("取消", role: .cancel) { }
            } message: {
                Text("请在系统设置中允许 Seedo 访问日历，以便同步专注记录。")
            }
        }
        .onAppear {
            if apiKey.isEmpty {
                apiKey = KeychainHelper.shared.load() ?? ""
            }
            reminderTimes = NotificationService.shared.getStoredReminderTimes()
        }
    }
    
    @State private var showingCalendarAlert = false
    
    @State private var pickingTick = false
    @State private var pickingDing = false
    
    private func triggerReschedule() {
        debounceTask?.cancel()
        debounceTask = Task {
            // Debounce for 0.5s to avoid UI stutter during DatePicker/Stepper interaction
            try? await Task.sleep(nanoseconds: 500_000_000)
            if Task.isCancelled { return }
            
            // Persist
            if let encoded = try? JSONEncoder().encode(reminderTimes) {
                UserDefaults.standard.set(encoded, forKey: "reminderTimes")
            }
            
            // Reschedule
            NotificationService.shared.rescheduleIfEnabled()
            print("[Settings] Notifications rescheduled (debounced)")
        }
    }
    
    private func defaultReminderTime() -> Date {
        var components = DateComponents()
        components.hour = 9
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}
