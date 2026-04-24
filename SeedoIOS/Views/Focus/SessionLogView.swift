import SwiftUI
import SwiftData

struct SessionLogView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var appState: AppState
    
    @State private var title: String = ""
    @State private var summary: String = ""
    @State private var selectedCategory: SessionCategory?
    
    @Query(sort: \SessionCategory.name) private var categories: [SessionCategory]
    
    var body: some View {
        NavigationStack {
            Form {
                Section("专注详情") {
                    TextField("你在做什么？", text: $title)
                    TextField("记录一些细节...", text: $summary, axis: .vertical)
                        .lineLimit(3...6)
                }
                
                Section("类别") {
                    Picker("选择类别", selection: $selectedCategory) {
                        Text("无类别").tag(nil as SessionCategory?)
                        ForEach(categories) { category in
                            HStack {
                                Circle().fill(category.color).frame(width: 8, height: 8)
                                Text(category.name)
                            }.tag(category as SessionCategory?)
                        }
                    }
                }
                
                Section {
                    Button(action: saveSession) {
                        Text("保存并完成")
                            .frame(maxWidth: .infinity)
                            .fontWeight(.bold)
                    }
                    .disabled(title.isEmpty)
                }
            }
            .navigationTitle("记录专注")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
            }
            .onAppear {
                if categories.isEmpty {
                    seedCategories()
                }
            }
        }
    }
    
    private func saveSession() {
        let session = WorkSession(
            title: title,
            summary: summary,
            startTimestamp: Date().addingTimeInterval(-Double(appState.elapsedSeconds)),
            endTimestamp: Date(),
            category: selectedCategory,
            isManual: false
        )
        modelContext.insert(session)
        CalendarService.shared.sync(session: session)
        appState.resetTimer()
        dismiss()
    }
    
    private func seedCategories() {
        for cat in SessionCategory.defaults {
            modelContext.insert(cat)
        }
    }
}
