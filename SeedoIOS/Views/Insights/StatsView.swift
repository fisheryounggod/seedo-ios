import SwiftUI
import SwiftData
import Charts

struct StatsView: View {
    @Query(sort: \WorkSession.startTimestamp, order: .reverse) private var sessions: [WorkSession]
    @Query(sort: \DailySummary.date, order: .reverse) private var summaries: [DailySummary]
    @Query(sort: \SessionCategory.name) private var categories: [SessionCategory]
    @Environment(\.modelContext) private var modelContext
    
    // Visualization State
    @State private var selectedChartType: ChartType = .bar
    @State private var selectedTimeRange: TimeRange = .week
    
    // History Display State
    @State private var isAscending = false
    @State private var collapsedSections: Set<String> = []
    
    @State private var editingSession: WorkSession?
    @State private var selectedSummary: DailySummary?
    @State private var showingAddSheet = false
    @State private var showingExportSheet = false
    @State private var showingImportSheet = false
    
    @State private var showingImportAlert = false
    @State private var importResult: (sessions: Int, categories: Int, summaries: Int, skipped: Int)?
    
    // AI State
    @State private var isGeneratingAI = false
    @State private var aiErrorMessage: String?
    @State private var showingAIError = false
    
    // Support for both JSON and CSV export
    @State private var exportDocument: JSONDocument?
    @State private var csvExportDocument: CSVDocument?
    @State private var showingCSVExport = false
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Plan Board
                    PlanBoardView()
                        .padding(.top)
                    
                    // Quick Stats Bar
                    quickStatsBar
                    
                    // Visualization Section
                    visualizationSection
                    
                    // History List
                    historyListSection
                }
                .padding()
            }
            .navigationTitle("洞察")
            .background(
                LinearGradient(colors: [Color(white: 0.05), .black], startPoint: .top, endPoint: .bottom)
                    .ignoresSafeArea()
            )
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    HStack {
                        Button(action: cleanupDuplicates) {
                            Image(systemName: "wand.and.stars")
                        }
                        Button(action: { showingImportSheet = true }) {
                            Image(systemName: "square.and.arrow.down")
                        }
                        Menu {
                            Button("导出 JSON (Mac 兼容)", action: prepareJSONExport)
                            Button("导出 CSV (表格软件)", action: prepareCSVExport)
                        } label: {
                            Image(systemName: "square.and.arrow.up")
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(item: $editingSession) { session in
                SessionEditorView(session: session)
            }
            .sheet(item: $selectedSummary) { summary in
                SummaryDetailView(summary: summary)
            }
            .sheet(isPresented: $showingAddSheet) {
                SessionEditorView()
            }
            .fileExporter(isPresented: $showingExportSheet, document: exportDocument, contentType: .json, defaultFilename: "SeedoBackup_\(Date().formatted(.dateTime.year().month().day().hour().minute()))") { _ in }
            .fileExporter(isPresented: $showingCSVExport, document: csvExportDocument, contentType: .commaSeparatedText, defaultFilename: "SeedoExport_\(Date().formatted(.dateTime.year().month().day()))") { _ in }
            .fileImporter(isPresented: $showingImportSheet, allowedContentTypes: [.json, .commaSeparatedText]) { result in
                handleImport(result: result)
            }
            .alert("导入完成", isPresented: $showingImportAlert, presenting: importResult) { _ in
                Button("确定") { }
            } message: { result in
                if result.sessions > 0 || result.categories > 0 || result.summaries > 0 {
                    Text("成功导入 \(result.sessions) 条记录，\(result.categories) 个分类，\(result.summaries) 条复盘分析。\n跳过了 \(result.skipped) 条重复项。")
                } else {
                    Text("成功清理了 \(result.skipped) 条完全重复的记录。")
                }
            }
            .alert("AI 分析失败", isPresented: $showingAIError) {
                Button("确定") { }
            } message: {
                Text(aiErrorMessage ?? "未知错误")
            }
        }
    }
    
    // MARK: - Extracted View Sections
    
    private var visualizationSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Picker("时间范围", selection: $selectedTimeRange) {
                    ForEach(TimeRange.allCases, id: \.self) { range in
                        Text(range.rawValue).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                
                Spacer()
                
                Menu {
                    ForEach(ChartType.allCases, id: \.self) { type in
                        Button(action: { withAnimation(.spring(response: 0.4)) { selectedChartType = type } }) {
                            Label(type.rawValue, systemImage: type.icon)
                        }
                    }
                } label: {
                    Image(systemName: selectedChartType.icon)
                        .font(.title3)
                        .foregroundStyle(.green)
                        .padding(8)
                        .background(Color.green.opacity(0.15))
                        .clipShape(Circle())
                        .shadow(color: .green.opacity(0.3), radius: 6)
                }
            }
            
            // Dynamic Chart View
            VStack {
                switch selectedChartType {
                case .bar:
                    BarChartView(data: chartData())
                case .pie:
                    PieChartView(data: pieData())
                case .heatmap:
                    HeatmapView(sessions: sessions, range: selectedTimeRange)
                }
            }
            .id("\(selectedChartType.rawValue)-\(selectedTimeRange.rawValue)")
            .transition(.opacity.combined(with: .scale(scale: 0.95)))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedChartType)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: selectedTimeRange)
            
            HStack {
                Button(action: exportChartAsImage) {
                    Label("保存分享图", systemImage: "square.and.arrow.up")
                        .font(.caption)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Capsule())
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: generateAIReview) {
                    if isGeneratingAI {
                        ProgressView().controlSize(.small)
                    } else {
                        Label("AI 深度分析", systemImage: "sparkles")
                            .font(.caption)
                            .fontWeight(.bold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                LinearGradient(colors: [.purple.opacity(0.3), .blue.opacity(0.2)], startPoint: .leading, endPoint: .trailing)
                            )
                            .clipShape(Capsule())
                            .foregroundStyle(.purple)
                    }
                }
                .disabled(isGeneratingAI)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private var historyListSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundStyle(.green)
                    Text("专注记录")
                        .font(.headline)
                }
                Spacer()
                HStack(spacing: 12) {
                    Button(action: { withAnimation(.spring(response: 0.3)) { isAscending.toggle() } }) {
                        Image(systemName: isAscending ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                            .foregroundStyle(.green.opacity(0.7))
                    }
                    Button(action: { withAnimation(.spring(response: 0.3)) { toggleAllSections() } }) {
                        Image(systemName: collapsedSections.isEmpty ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.circle")
                            .foregroundStyle(.green.opacity(0.7))
                    }
                }
            }
            
            if sessions.isEmpty && summaries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "leaf")
                        .font(.largeTitle)
                        .foregroundStyle(.green.opacity(0.3))
                    Text("暂无记录，开始你的第一次专注吧！")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 30)
            } else {
                let grouped = groupedHistory()
                ForEach(grouped, id: \.date) { group in
                    VStack(alignment: .leading, spacing: 8) {
                        Button(action: { withAnimation(.spring(response: 0.3)) { toggleSection(group.date) } }) {
                            HStack {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.green)
                                    .frame(width: 3, height: 14)
                                Text(group.date)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.green)
                                Text("\(group.items.count)")
                                    .font(.caption2)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.green)
                                Spacer()
                                Image(systemName: collapsedSections.contains(group.date) ? "chevron.right" : "chevron.down")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 4)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        
                        if !collapsedSections.contains(group.date) {
                            ForEach(group.items) { item in
                                switch item {
                                case .session(let session):
                                    SessionRow(session: session)
                                        .contentShape(Rectangle())
                                        .onTapGesture { editingSession = session }
                                        .swipeActions {
                                            Button(role: .destructive) { modelContext.delete(session) } label: { Label("删除", systemImage: "trash") }
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                case .summary(let summary):
                                    SummaryRow(summary: summary)
                                        .onTapGesture { selectedSummary = summary }
                                        .swipeActions {
                                            Button(role: .destructive) { modelContext.delete(summary) } label: { Label("删除", systemImage: "trash") }
                                        }
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private func prepareJSONExport() {
        if let data = DataService.shared.exportToJSON(sessions: sessions, categories: categories) {
            exportDocument = JSONDocument(data: data)
            showingExportSheet = true
        }
    }
    
    private func prepareCSVExport() {
        let csvText = DataService.shared.exportToCSV(sessions: sessions)
        csvExportDocument = CSVDocument(text: csvText)
        showingCSVExport = true
    }
    
    private func handleImport(result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        
        guard url.startAccessingSecurityScopedResource() else { return }
        defer { url.stopAccessingSecurityScopedResource() }
        
        do {
            let data = try Data(contentsOf: url)
            if url.pathExtension.lowercased() == "json" {
                let (newSessions, newCategories, newSummaries, skipped) = DataService.shared.parseJSON(
                    data: data, 
                    existingSessions: sessions, 
                    categories: categories
                )
                
                for cat in newCategories { modelContext.insert(cat) }
                for session in newSessions { modelContext.insert(session) }
                for summary in newSummaries { modelContext.insert(summary) }
                
                try? modelContext.save()
                importResult = (newSessions.count, newCategories.count, newSummaries.count, skipped)
                showingImportAlert = true
            } else {
                let content = String(data: data, encoding: .utf8) ?? ""
                let newSessions = DataService.shared.parseCSV(content: content, existingSessions: sessions, categories: categories)
                for session in newSessions { modelContext.insert(session) }
                try? modelContext.save()
                importResult = (newSessions.count, 0, 0, 0)
                showingImportAlert = true
            }
        } catch {
            print("Import error: \(error)")
        }
    }
    
    // MARK: - AI Action
    private func generateAIReview() {
        isGeneratingAI = true
        
        let builder = SummaryContextBuilder(modelContext: modelContext)
        do {
            let context = try builder.build(for: Date())
            AIService.shared.generateSummary(context: context, periodLabel: "今日") { result in
                DispatchQueue.main.async {
                    isGeneratingAI = false
                    switch result {
                    case .success(let summary):
                        modelContext.insert(summary)
                        try? modelContext.save()
                        selectedSummary = summary
                    case .failure(let error):
                        aiErrorMessage = error.localizedDescription
                        showingAIError = true
                    }
                }
            }
        } catch {
            isGeneratingAI = false
            aiErrorMessage = error.localizedDescription
            showingAIError = true
        }
    }
    
    private func cleanupDuplicates() {
        let duplicates = DataService.shared.findDuplicates(in: sessions)
        guard !duplicates.isEmpty else { return }
        
        for session in duplicates {
            modelContext.delete(session)
        }
        
        try? modelContext.save()
        
        // Show success feedback
        let count = duplicates.count
        importResult = (0, 0, 0, count) // Use skipped column for cleaned count
        showingImportAlert = true
    }
    
    // MARK: - Quick Stats Bar
    private var quickStatsBar: some View {
        let rangeDays = lastNDays(selectedTimeRange.days)
        let calendar = Calendar.current
        let rangeSessions = sessions.filter { s in
            rangeDays.contains(where: { calendar.isDate(s.startTimestamp, inSameDayAs: $0) })
        }
        let totalMins = Int(rangeSessions.reduce(0) { $0 + $1.duration } / 60)
        let sessionCount = rangeSessions.count
        let activeDays = Set(rangeSessions.map { calendar.startOfDay(for: $0.startTimestamp) }).count
        
        return HStack(spacing: 0) {
            statPill(icon: "flame.fill", value: "\(totalMins)", unit: "min", color: .orange)
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            statPill(icon: "checkmark.circle.fill", value: "\(sessionCount)", unit: "次", color: .green)
            Divider().frame(height: 30).background(Color.white.opacity(0.1))
            statPill(icon: "calendar.badge.clock", value: "\(activeDays)", unit: "天", color: .blue)
        }
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.ultraThinMaterial.opacity(0.3))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.06), lineWidth: 1)
                )
        )
    }
    
    private func statPill(icon: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 0) {
                Text(value)
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .contentTransition(.numericText())
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
    }
    
    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let date: Date
        let category: String
        let minutes: Double
    }
}

// MARK: - Components
struct PlanBoardView: View {
    @State private var showingEditor = false
    // Use a unique ID to force refresh when coming back from editor
    @State private var refreshID = UUID()
    
    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                PlanItemView(title: "今日目标", content: PlanService.shared.getPlan(scope: .daily), color: .blue)
                PlanItemView(title: "月计划", content: PlanService.shared.getPlan(scope: .monthly), color: .purple)
                PlanItemView(title: "年目标", content: PlanService.shared.getPlan(scope: .yearly), color: .orange)
            }
            .id(refreshID)
        }
        .onTapGesture { showingEditor = true }
        .sheet(isPresented: $showingEditor, onDismiss: {
            refreshID = UUID()
        }) {
            PlanEditorSheet()
        }
    }
}

struct PlanItemView: View {
    let title: String
    let content: String
    let color: Color
    
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Circle()
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(title)
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundStyle(color)
            }
            Text(content.isEmpty ? "未设定" : content)
                .font(.subheadline)
                .lineLimit(2)
                .foregroundStyle(content.isEmpty ? .secondary : .primary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(color.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.2), lineWidth: 1)
        )
        .cornerRadius(12)
    }
}

struct PlanEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var dailyPlan = PlanService.shared.getPlan(scope: .daily)
    @State private var monthlyPlan = PlanService.shared.getPlan(scope: .monthly)
    @State private var yearlyPlan = PlanService.shared.getPlan(scope: .yearly)
    
    var body: some View {
        NavigationStack {
            Form {
                Section("今日目标") {
                    TextField("你想完成什么？", text: $dailyPlan)
                }
                Section("本月计划") {
                    TextField("主要的各种里程碑", text: $monthlyPlan)
                }
                Section("年度愿景") {
                    TextField("长期的大目标", text: $yearlyPlan)
                }
            }
            .navigationTitle("编辑计划")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        PlanService.shared.savePlan(content: dailyPlan, scope: .daily)
                        PlanService.shared.savePlan(content: monthlyPlan, scope: .monthly)
                        PlanService.shared.savePlan(content: yearlyPlan, scope: .yearly)
                        dismiss()
                    }
                }
            }
        }
    }
}

struct SummaryRow: View {
    let summary: DailySummary
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .foregroundStyle(.purple)
                        .symbolEffect(.pulse)
                    Text("AI 复盘报告")
                        .font(.subheadline)
                        .fontWeight(.bold)
                }
                Text(summary.keywords)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 2) {
                    ForEach(0..<5) { i in
                        Image(systemName: i < summary.score ? "star.fill" : "star")
                            .font(.system(size: 8))
                            .foregroundStyle(i < summary.score ? .orange : .gray.opacity(0.3))
                    }
                }
                Text("\(summary.score)/5")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
        .background(
            LinearGradient(colors: [.purple.opacity(0.12), .blue.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.purple.opacity(0.15), lineWidth: 1)
        )
        .cornerRadius(14)
    }
}

enum ChartType: String, CaseIterable {
    case bar = "趋势图"
    case pie = "饼图"
    case heatmap = "活跃图"
    
    var icon: String {
        switch self {
        case .bar: return "chart.xyaxis.line"
        case .pie: return "chart.pie.fill"
        case .heatmap: return "calendar"
        }
    }
}

enum TimeRange: String, CaseIterable {
    case day = "日"
    case week = "周"
    case month = "月"
    case year = "年"
    
    var days: Int {
        switch self {
        case .day: return 1
        case .week: return 7
        case .month: return 30
        case .year: return 365
        }
    }
}

// MARK: - Specialized Chart Views
struct BarChartView: View {
    let data: [StatsView.ChartDataPoint]
    
    var body: some View {
        Chart {
            ForEach(data) { point in
                LineMark(
                    x: .value("时间", point.date, unit: .day),
                    y: .value("分钟", point.minutes)
                )
                .foregroundStyle(by: .value("分类", point.category))
                .interpolationMethod(.catmullRom)
                
                AreaMark(
                    x: .value("时间", point.date, unit: .day),
                    y: .value("分钟", point.minutes)
                )
                .foregroundStyle(by: .value("分类", point.category))
                .interpolationMethod(.catmullRom)
                .opacity(0.1)
            }
        }
        .frame(height: 220)
        .chartYAxis {
            AxisMarks { value in
                if let mins = value.as(Double.self) {
                    AxisValueLabel("\(Int(mins)) min")
                }
            }
        }
    }
}

struct PieChartView: View {
    let data: [StatsView.PieDataPoint]
    
    var body: some View {
        Chart(data) { point in
            SectorMark(
                angle: .value("时长", point.minutes),
                innerRadius: .ratio(0.618),
                angularInset: 1.5
            )
            .cornerRadius(5)
            .foregroundStyle(by: .value("分类", point.category))
        }
        .frame(height: 220)
        .chartLegend(position: .bottom, spacing: 16)
    }
}

struct HeatmapView: View {
    let sessions: [WorkSession]
    let range: TimeRange
    
    var body: some View {
        let days = getDays()
        let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: range == .year ? 20 : 7)
        
        LazyVGrid(columns: columns, spacing: 4) {
            ForEach(days, id: \.self) { day in
                let intensity = getIntensity(for: day)
                RoundedRectangle(cornerRadius: 2)
                    .fill(intensity > 0 ? Color.green.opacity(intensity) : Color.white.opacity(0.1))
                    .aspectRatio(1, contentMode: .fit)
                    .overlay(
                        Text("\(Calendar.current.component(.day, from: day))")
                            .font(.system(size: 6))
                            .foregroundStyle(.secondary.opacity(0.5))
                    )
            }
        }
        .padding(8)
        .frame(height: 220)
    }
    
    private func getDays() -> [Date] {
        let calendar = Calendar.current
        let end = calendar.startOfDay(for: Date())
        let start = calendar.date(byAdding: .day, value: -(range.days - 1), to: end)!
        
        var days: [Date] = []
        var current = start
        while current <= end {
            days.append(current)
            current = calendar.date(byAdding: .day, value: 1, to: current)!
        }
        return days
    }
    
    private func getIntensity(for day: Date) -> Double {
        let calendar = Calendar.current
        let total = sessions.filter { calendar.isDate($0.startTimestamp, inSameDayAs: day) }
            .reduce(0) { $0 + $1.duration }
        
        if total == 0 { return 0 }
        // 120 mins = 1.0 intensity
        return min(total / (120 * 60), 1.0)
    }
}

extension StatsView {
    struct PieDataPoint: Identifiable {
        let id = UUID()
        let category: String
        let minutes: Double
    }
    
    private func pieData() -> [PieDataPoint] {
        let days = lastNDays(selectedTimeRange.days)
        let calendar = Calendar.current
        var dict: [String: Double] = [:]
        
        for session in sessions {
            if days.contains(where: { calendar.isDate(session.startTimestamp, inSameDayAs: $0) }) {
                let catName = session.category?.name ?? "其他"
                dict[catName, default: 0] += session.duration / 60.0
            }
        }
        
        return dict.map { PieDataPoint(category: $0.key, minutes: $0.value) }
            .sorted { $0.minutes > $1.minutes }
    }
    
    private func lastNDays(_ n: Int) -> [Date] {
        let calendar = Calendar.current
        return (0..<n).reversed().map {
            calendar.startOfDay(for: calendar.date(byAdding: .day, value: -$0, to: Date())!)
        }
    }
    
    private func chartData() -> [ChartDataPoint] {
        var points: [ChartDataPoint] = []
        let days = lastNDays(selectedTimeRange.days)
        let calendar = Calendar.current
        let allCatNames = categories.map { $0.name } + ["其他"]
        
        for day in days {
            for name in allCatNames {
                let mins: Double
                if name == "其他" {
                    mins = sessions.filter {
                        calendar.isDate($0.startTimestamp, inSameDayAs: day) && $0.category == nil
                    }.reduce(0) { $0 + $1.duration } / 60.0
                } else {
                    mins = sessions.filter {
                        calendar.isDate($0.startTimestamp, inSameDayAs: day) && $0.category?.name == name
                    }.reduce(0) { $0 + $1.duration } / 60.0
                }
                points.append(ChartDataPoint(date: day, category: name, minutes: mins))
            }
        }
        return points
    }
    
    private func exportChartAsImage() {
        // 获取最新生成的AI报告（不严格限制当前日期，防止跨天时区导致获取不到）
        let recentSummary = summaries.max(by: { $0.createdAt < $1.createdAt })
        
        let chartView = VStack(spacing: 20) {
            Text("Seedo 专注成就")
                .font(.title)
                .fontWeight(.bold)
            Text("\(selectedTimeRange.rawValue)统计 - \(selectedChartType.rawValue)")
                .font(.headline)
                .foregroundStyle(.secondary)
            
            switch selectedChartType {
            case .bar: BarChartView(data: chartData())
            case .pie: PieChartView(data: pieData())
            case .heatmap: HeatmapView(sessions: sessions, range: selectedTimeRange)
            }
            
            HStack {
                VStack(alignment: .leading) {
                    Text("总专注时长")
                        .font(.caption)
                    Text("\(Int(pieData().reduce(0) { $0 + $1.minutes })) min")
                        .font(.title2)
                        .fontWeight(.bold)
                }
                Spacer()
                Image(systemName: "seedling.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.green)
            }
            
            if let summary = recentSummary {
                Divider().background(Color.white.opacity(0.2))
                
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text("AI 复盘报告")
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Spacer()
                        HStack(spacing: 2) {
                            ForEach(0..<5) { i in
                                Image(systemName: i < summary.score ? "star.fill" : "star")
                                    .font(.system(size: 10))
                                    .foregroundStyle(i < summary.score ? .orange : .gray.opacity(0.3))
                            }
                        }
                    }
                    
                    if let markdown = try? AttributedString(markdown: summary.content, options: .init(interpretedSyntax: .full)) {
                        Text(markdown)
                            .font(.caption)
                            .lineSpacing(4)
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(summary.content)
                            .font(.caption)
                            .lineSpacing(4)
                            .foregroundStyle(.white.opacity(0.9))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding()
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color.purple.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(Color.purple.opacity(0.2), lineWidth: 1)
                        )
                )
            }
        }
        .padding(30)
        .background(Color.black)
        .foregroundStyle(.white)
        .frame(width: 400)
        
        let renderer = ImageRenderer(content: chartView)
        renderer.scale = UIScreen.main.scale
        
        if let image = renderer.uiImage {
            let activityVC = UIActivityViewController(activityItems: [image], applicationActivities: nil)
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                rootVC.present(activityVC, animated: true)
            }
        }
    }
}

enum HistoryItem: Identifiable {
    case session(WorkSession)
    case summary(DailySummary)
    
    var id: String {
        switch self {
        case .session(let s): return "s-\(s.id)"
        case .summary(let sum): return "sum-\(sum.date)"
        }
    }
    
    var date: Date {
        switch self {
        case .session(let s): return s.startTimestamp
        case .summary(let sum): return sum.createdAt
        }
    }
}

struct SessionRow: View {
    let session: WorkSession
    
    var body: some View {
        HStack(spacing: 12) {
            // Category accent bar
            RoundedRectangle(cornerRadius: 3)
                .fill(session.category?.color ?? .gray)
                .frame(width: 4, height: 36)
                .shadow(color: (session.category?.color ?? .gray).opacity(0.5), radius: 4)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(session.displayTitle)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                if !session.summary.isEmpty && session.summary != session.title {
                    Text(session.summary)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(session.duration))
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.green)
                
                Text(session.startTimestamp.formatted(.dateTime.hour().minute()))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.04))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.06), lineWidth: 0.5)
        )
        .cornerRadius(14)
    }
    
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let mins = Int(seconds) / 60
        return "\(mins) min"
    }
}

extension StatsView {
    struct HistoryGroup {
        let date: String
        let items: [HistoryItem]
    }
    
    private func groupedHistory() -> [HistoryGroup] {
        let items = combineHistory()
        let sortedItems = isAscending ? items.sorted { $0.date < $1.date } : items.sorted { $0.date > $1.date }
        
        let groups = Dictionary(grouping: sortedItems) { item in
            item.date.formatted(.dateTime.year().month().day())
        }
        
        let sortedDates = groups.keys.sorted { d1, d2 in
            if isAscending { return d1 < d2 }
            return d1 > d2
        }
        
        return sortedDates.map { date in
            HistoryGroup(date: date, items: groups[date] ?? [])
        }
    }
    
    private func combineHistory() -> [HistoryItem] {
        let rangeDays = lastNDays(selectedTimeRange.days)
        let calendar = Calendar.current
        
        let filteredSessions = sessions.filter { s in
            rangeDays.contains(where: { calendar.isDate(s.startTimestamp, inSameDayAs: $0) })
        }
        
        let filteredSummaries = summaries.filter { s in
            rangeDays.contains(where: { calendar.isDate(s.createdAt, inSameDayAs: $0) })
        }
        
        var items: [HistoryItem] = filteredSessions.map { .session($0) }
        items += filteredSummaries.map { .summary($0) }
        return items
    }
    
    private func toggleSection(_ date: String) {
        if collapsedSections.contains(date) {
            collapsedSections.remove(date)
        } else {
            collapsedSections.insert(date)
        }
    }
    
    private func toggleAllSections() {
        if collapsedSections.isEmpty {
            let groups = groupedHistory()
            collapsedSections = Set(groups.map { $0.date })
        } else {
            collapsedSections.removeAll()
        }
    }
}
