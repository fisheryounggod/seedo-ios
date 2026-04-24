import SwiftUI

struct SummaryDetailView: View {
    let summary: DailySummary
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Header Card
                    HStack {
                        VStack(alignment: .leading) {
                            Text(summary.date)
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("效能复盘报告")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            HStack(spacing: 4) {
                                ForEach(0..<5) { index in
                                    Image(systemName: index < summary.score ? "star.fill" : "star")
                                        .foregroundStyle(index < summary.score ? .orange : .gray)
                                }
                            }
                            Text("效能评分")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.white.opacity(0.05))
                    .cornerRadius(12)
                    
                    if !summary.keywords.isEmpty {
                        Text(summary.keywords)
                            .font(.callout)
                            .fontWeight(.medium)
                            .foregroundStyle(.purple)
                            .padding(.horizontal)
                    }
                    
                    Divider()
                    
                    // Content with Markdown support
                    Group {
                        if let markdown = try? AttributedString(markdown: summary.content, options: .init(interpretedSyntax: .full)) {
                            Text(markdown)
                        } else {
                            Text(summary.content)
                        }
                    }
                    .font(.body)
                    .lineSpacing(6)
                    .padding(.horizontal)
                    .textSelection(.enabled)
                }
                .padding()
            }
            .navigationTitle("AI 复盘")
            .navigationBarTitleDisplayMode(.inline)
            .background(Color.black)
            .foregroundStyle(.white)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                }
                ToolbarItem(placement: .topBarLeading) {
                    ShareLink(item: summary.content, subject: Text("Seedo AI 复盘 - \(summary.date)")) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
