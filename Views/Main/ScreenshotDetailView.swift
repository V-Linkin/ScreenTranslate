import SwiftUI

/// 截图详情视图 - 预览 + 翻译结果
struct ScreenshotDetailView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var translationVM = TranslationViewModel()

    @State private var showingFloatingWindow = false
    @State private var floatingOpacity: Double = 0.9

    var body: some View {
        if let screenshot = currentScreenshot {
            VStack(spacing: 0) {
                // 工具栏
                detailToolbar(screenshot: screenshot)

                Divider()

                HStack(spacing: 0) {
                    // 左侧：截图预览
                    VStack {
                        screenshotPreview(screenshot: screenshot)
                    }
                    .frame(maxWidth: .infinity)

                    Divider()

                    // 右侧：识别和翻译结果
                    VStack(alignment: .leading, spacing: 16) {
                        resultSection(
                            title: "识别文字",
                            icon: "text.viewfinder",
                            content: screenshot.recognizedText,
                            placeholder: "正在进行 OCR 识别..."
                        )

                        Divider()

                        resultSection(
                            title: "翻译结果",
                            icon: "globe",
                            content: screenshot.translation,
                            placeholder: translationVM.isTranslating ? "正在翻译..." : "等待 OCR 完成..."
                        )

                        Spacer()
                    }
                    .frame(width: 350)
                    .padding()
                }
            }
            .navigationTitle("截图详情")
        } else {
            VStack(spacing: 16) {
                Image(systemName: "photo")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("选择一张截图查看详情")
                    .font(.title2)
                    .foregroundColor(.secondary)
                Text("从左侧列表中选择截图，或截取新的屏幕内容")
                    .font(.body)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - 工具栏

    private func detailToolbar(screenshot: ScreenshotItem) -> some View {
        HStack(spacing: 12) {
            Button {
                if let image = screenshot.image {
                    image.addToClipboard()
                }
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            Button {
                showingFloatingWindow = true
                if let image = screenshot.image {
                    FloatingWindowService.shared.showFloatingWindow(
                        image: image,
                        recognizedText: screenshot.recognizedText,
                        translatedText: screenshot.translation,
                        opacity: floatingOpacity
                    )
                }
            } label: {
                Label("置顶显示", systemImage: "pin.fill")
            }

            Button {
                appState.isShowingEditor = true
                appState.editingScreenshotID = screenshot.id
            } label: {
                Label("编辑", systemImage: "pencil")
            }

            Divider()

            Button {
                Task {
                    await translationVM.translateScreenshot(screenshot, settings: appState.translationSettings)
                }
            } label: {
                Label("翻译", systemImage: "globe")
            }

            Spacer()

            // 透明度滑块
            HStack {
                Image(systemName: "circle.lefthalf.filled")
                    .font(.caption)
                Slider(value: $floatingOpacity, in: 0.2...1.0)
                    .frame(width: 80)
            }

            Divider()

            Button {
                appState.deleteScreenshot(screenshot.id)
            } label: {
                Label("删除", systemImage: "trash")
            }
            .foregroundColor(.red)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 截图预览

    private func screenshotPreview(screenshot: ScreenshotItem) -> some View {
        Group {
            if let image = screenshot.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding()
            } else {
                VStack {
                    Image(systemName: "photo")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary)
                    Text("无法加载截图")
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - 结果区域

    private func resultSection(title: String, icon: String, content: String?, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.accentColor)
                Text(title)
                    .font(.headline)
            }

            if let content = content, !content.isEmpty {
                Text(content)
                    .font(.body)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Text(placeholder)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .italic()
            }
        }
    }

    // MARK: - 辅助

    private var currentScreenshot: ScreenshotItem? {
        appState.screenshots.first { $0.id == appState.selectedScreenshotID }
    }
}
