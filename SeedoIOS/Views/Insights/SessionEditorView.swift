import SwiftUI
import SwiftData

struct SessionEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    
    // The session being edited (if any)
    var session: WorkSession?
    
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var startTimestamp: Date = Date().addingTimeInterval(-1500)
    @State private var endTimestamp: Date = Date()
    @State private var selectedCategory: SessionCategory?
    
    @Query(sort: \SessionCategory.name) private var categories: [SessionCategory]
    
    var isNew: Bool { session == nil }
    
    var body: some View {
        NavigationStack {
            Form {
                Section("详情") {
                    TextField("任务标题", text: $title)
                    TextField("备注", text: $summary, axis: .vertical)
                        .lineLimit(3...5)
                }
                
                Section("时间") {
                    DatePicker("开始时间", selection: $startTimestamp)
                    DatePicker("结束时间", selection: $endTimestamp)
                }
                
                Section("类别") {
                    Picker("分类", selection: $selectedCategory) {
                        Text("无分类").tag(nil as SessionCategory?)
                        ForEach(categories) { category in
                            HStack {
                                Circle().fill(category.color).frame(width: 8, height: 8)
                                Text(category.name)
                            }.tag(category as SessionCategory?)
                        }
                    }
                }
                
                if !isNew {
                    Section {
                        Button(role: .destructive, action: deleteSession) {
                            Text("删除记录")
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(isNew ? "添加记录" : "编辑记录")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.isEmpty || endTimestamp <= startTimestamp)
                }
            }
            .onAppear(perform: setup)
        }
    }
    
    private func setup() {
        if let session = session {
            title = session.title
            summary = session.summary
            startTimestamp = session.startTimestamp
            endTimestamp = session.endTimestamp
            selectedCategory = session.category
        }
    }
    
    private func save() {
        if let session = session {
            // Update existing
            session.title = title
            session.summary = summary
            session.startTimestamp = startTimestamp
            session.endTimestamp = endTimestamp
            session.category = selectedCategory
            CalendarService.shared.sync(session: session)
        } else {
            // Create new
            let newSession = WorkSession(
                title: title,
                summary: summary,
                startTimestamp: startTimestamp,
                endTimestamp: endTimestamp,
                category: selectedCategory,
                isManual: true
            )
            modelContext.insert(newSession)
            CalendarService.shared.sync(session: newSession)
        }
        
        dismiss()
    }
    
    private func deleteSession() {
        if let session = session {
            CalendarService.shared.delete(session: session)
            modelContext.delete(session)
        }
        dismiss()
    }
}
