import SwiftUI

/// 翻译结果展示组件
struct TranslationResultView: View {
    let originalText: String?
    let translatedText: String?
    let isTranslating: Bool
    var onCopy: (() -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // 原文区域
            if let original = originalText, !original.isEmpty {
                resultBlock(
                    title: "识别文字",
                    icon: "text.viewfinder",
                    text: original,
                    color: .primary
                )
            }

            // 分隔线
            if originalText != nil && translatedText != nil {
                Divider()
            }

            // 翻译结果区域
            if isTranslating {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("正在翻译...")
                        .foregroundColor(.secondary)
                }
                .padding(.vertical, 8)
            } else if let translated = translatedText, !translated.isEmpty {
                resultBlock(
                    title: "翻译结果",
                    icon: "globe",
                    text: translated,
                    color: .accentColor
                )
            }
        }
    }

    @ViewBuilder
    private func resultBlock(title: String, icon: String, text: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundColor(color)
                Text(title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(color)
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                    onCopy?()
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.caption)
                }
                .buttonStyle(.plain)
                .help("复制")
            }

            ScrollView(.vertical, showsIndicators: false) {
                Text(text)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .background(Color(nsColor: .textBackgroundColor).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

/// 翻译历史视图
struct TranslationHistoryView: View {
    @ObservedObject var translationVM: TranslationViewModel

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("翻译历史")
                    .font(.headline)
                Spacer()
                Text("\(translationVM.translationHistory.count) 条记录")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Button("清空历史") {
                    translationVM.clearHistory()
                }
                .foregroundColor(.red)
            }
            .padding()

            Divider()

            if translationVM.translationHistory.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "clock")
                        .font(.system(size: 36))
                        .foregroundColor(.secondary)
                    Text("暂无翻译记录")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    Text("翻译的内容会自动保存到这里")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    ForEach(translationVM.translationHistory) { item in
                        historyRow(item: item)
                            .contextMenu {
                                Button("复制原文") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.originalText, forType: .string)
                                }
                                Button("复制译文") {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(item.translatedText, forType: .string)
                                }
                                Divider()
                                Button("删除", role: .destructive) {
                                    translationVM.deleteHistoryItem(item.id)
                                }
                            }
                    }
                }
            }
        }
    }

    private func historyRow(item: TranslationViewModel.TranslationHistoryItem) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(item.timestamp.formattedString)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(item.engine)
                    .font(.caption2)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(Capsule())
            }

            Text(item.originalText)
                .font(.subheadline)
                .lineLimit(2)

            Text(item.translatedText)
                .font(.subheadline)
                .foregroundColor(.accentColor)
                .lineLimit(2)
        }
        .padding(.vertical, 4)
    }
}
