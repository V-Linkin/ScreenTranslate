import SwiftUI
import AppKit

// MARK: - 截图操作窗口（截图后弹出）

/// 截图后的操作窗口 - 保留选中区域，提供翻译按钮
struct ScreenshotActionView: View {
    let image: NSImage
    @State private var recognizedText: String?
    @State private var translatedText: String?
    @State private var isProcessing = false
    @State private var processingStep: String = ""

    var body: some View {
        VStack(spacing: 0) {
            // 截图预览 - 最大化显示选中区域
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 550, maxHeight: 400)
                .background(Color.black)

            Divider()

            // 操作区域
            VStack(spacing: 12) {
                if isProcessing {
                    // 处理中
                    HStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text(processingStep)
                            .font(.callout)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 12)

                } else if let translated = translatedText, !translated.isEmpty {
                    // 翻译结果显示
                    ScrollView(.vertical, showsIndicators: false) {
                        VStack(alignment: .leading, spacing: 8) {
                            if let original = recognizedText, !original.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "text.viewfinder")
                                        .font(.caption)
                                        .foregroundColor(.blue)
                                    Text("识别文字")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.blue)
                                }
                                Text(original)
                                    .font(.system(.caption, design: .monospaced))
                                    .foregroundColor(.secondary)
                                    .lineLimit(4)
                            }

                            if !translated.isEmpty {
                                Divider()
                                HStack(spacing: 4) {
                                    Image(systemName: "globe")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                    Text("翻译结果")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                        .foregroundColor(.green)
                                }
                                Text(translated)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(maxHeight: 150)

                    // 操作按钮
                    HStack(spacing: 10) {
                        Button("复制译文") {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(translated, forType: .string)
                        }
                        .buttonStyle(.bordered)

                        if let original = recognizedText, !original.isEmpty {
                            Button("复制原文") {
                                NSPasteboard.general.clearContents()
                                NSPasteboard.general.setString(original, forType: .string)
                            }
                            .buttonStyle(.bordered)
                        }

                        Spacer()

                        Button("关闭") {
                            ScreenshotActionService.shared.close()
                        }
                        .buttonStyle(.bordered)
                    }

                } else {
                    // 初始状态 - 大翻译按钮
                    Button(action: performOCRAndTranslate) {
                        HStack(spacing: 8) {
                            Image(systemName: "character.textbox")
                                .font(.title3)
                            Text("识别并翻译")
                                .font(.headline)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)

                    HStack {
                        Spacer()
                        Button("关闭") {
                            ScreenshotActionService.shared.close()
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    }
                }
            }
            .padding(16)
            .background(Color(nsColor: .windowBackgroundColor))
        }
        .frame(width: 560)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.3), radius: 10)
    }

    private func performOCRAndTranslate() {
        isProcessing = true
        processingStep = "正在识别文字..."

        // 在后台线程执行 OCR
        DispatchQueue.global(qos: .userInitiated).async {
            OCRService.recognizeText(from: self.image) { text in
                // completion 已在主线程（OCRService 内部 dispatch）
                self.recognizedText = text

                guard let text = text, !text.isEmpty else {
                    self.isProcessing = false
                    self.processingStep = ""
                    return
                }

                let screenshotSettings = AppState.shared?.screenshotSettings ?? .default
                guard screenshotSettings.autoTranslate else {
                    self.isProcessing = false
                    self.processingStep = ""
                    self.translatedText = "（自动翻译已关闭）"
                    return
                }

                self.processingStep = "正在翻译..."

                let translationSettings = AppState.shared?.translationSettings ?? .default
                Task { @MainActor in
                    let result = await TranslationService.translate(
                        text: text,
                        source: translationSettings.sourceLanguage,
                        target: translationSettings.targetLanguage,
                        engine: translationSettings.engine,
                        settings: translationSettings
                    )
                    self.isProcessing = false
                    self.processingStep = ""
                    self.translatedText = result?.translatedText ?? "翻译失败"
                }
            }
        }
    }
}

/// 截图操作窗口服务
class ScreenshotActionService {
    static let shared = ScreenshotActionService()

    private var actionWindow: NSWindow?

    private init() {}

    func show(image: NSImage) {
        close()

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 480),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            window.setFrameOrigin(NSPoint(
                x: screenRect.midX - 280,
                y: screenRect.midY - 240
            ))
        }

        let hostingView = NSHostingView(
            rootView: ScreenshotActionView(image: image)
        )
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        actionWindow = window
    }

    func close() {
        actionWindow?.orderOut(nil)
        actionWindow = nil
    }
}

// MARK: - 置顶浮动窗口

/// 浮动窗口视图 - 置顶显示截图 + OCR + 翻译
struct FloatingWindowView: View {
    let image: NSImage
    var recognizedText: String?
    var translatedText: String?
    @Binding var opacity: Double
    @State private var isDragging = false
    @State private var dragOffset: CGSize = .zero

    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Image(systemName: "photo")
                    .font(.caption)
                    .foregroundColor(.white)
                Text("置顶截图")
                    .font(.caption)
                    .foregroundColor(.white)

                Spacer()

                Button {
                    closeFloatingWindow()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.white.opacity(0.8))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.6))

            // 截图内容
            Image(nsImage: image)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(maxWidth: 500, maxHeight: 300)
                .background(Color.black)

            // OCR + 翻译结果区域
            if recognizedText != nil || translatedText != nil {
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 8) {
                        if let text = recognizedText, !text.isEmpty {
                            HStack(spacing: 4) {
                                Image(systemName: "text.viewfinder")
                                    .font(.caption2)
                                    .foregroundColor(.blue)
                                Text("识别文字")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.blue)
                            }
                            Text(text)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.primary)
                                .textSelection(.enabled)
                                .lineLimit(6)
                        }

                        if let translation = translatedText, !translation.isEmpty {
                            Divider()
                            HStack(spacing: 4) {
                                Image(systemName: "globe")
                                    .font(.caption2)
                                    .foregroundColor(.green)
                                Text("翻译结果")
                                    .font(.caption2)
                                    .fontWeight(.medium)
                                    .foregroundColor(.green)
                            }
                            Text(translation)
                                .font(.system(.caption, design: .monospaced))
                                .foregroundColor(.accentColor)
                                .textSelection(.enabled)
                                .lineLimit(6)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
                }
                .frame(maxHeight: 150)
                .background(Color(nsColor: .textBackgroundColor).opacity(0.9))
            }
        }
        .frame(width: 500)
        .opacity(opacity)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(0.3), radius: 10)
        .gesture(
            DragGesture()
                .onChanged { value in
                    isDragging = true
                    dragOffset = value.translation
                }
                .onEnded { value in
                    isDragging = false
                }
        )
        .onTapGesture(count: 2) {
            // 双击复制译文（如果有），否则复制图片
            if let translation = translatedText, !translation.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(translation, forType: .string)
            } else {
                image.addToClipboard()
            }
        }
        .contextMenu {
            if let translation = translatedText, !translation.isEmpty {
                Button("复制译文") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(translation, forType: .string)
                }
            }
            if let text = recognizedText, !text.isEmpty {
                Button("复制原文") {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                }
            }
            Button("复制图片") {
                image.addToClipboard()
            }
            Divider()
            Button("关闭", role: .destructive) {
                closeFloatingWindow()
            }
        }
    }

    private func closeFloatingWindow() {
        FloatingWindowService.shared.closeFloatingWindow()
    }
}

/// 浮动窗口服务 - 管理浮动窗口的创建和销毁
class FloatingWindowService {
    static let shared = FloatingWindowService()

    private var floatingWindow: NSWindow?

    private init() {}

    func showFloatingWindow(image: NSImage, recognizedText: String? = nil, translatedText: String? = nil, opacity: Double = 0.9) {
        closeFloatingWindow()

        let hasText = (recognizedText != nil && !(recognizedText ?? "").isEmpty) ||
                      (translatedText != nil && !(translatedText ?? "").isEmpty)
        let windowHeight: CGFloat = hasText ? 520 : 400

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 500, height: windowHeight),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )

        window.level = .floating
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = true
        window.isMovableByWindowBackground = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]

        if let screen = NSScreen.main {
            let screenRect = screen.visibleFrame
            window.setFrameOrigin(NSPoint(
                x: screenRect.midX - 250,
                y: screenRect.midY - windowHeight / 2
            ))
        }

        let hostingView = NSHostingView(
            rootView: FloatingWindowView(
                image: image,
                recognizedText: recognizedText,
                translatedText: translatedText,
                opacity: Binding(
                    get: { opacity },
                    set: { _ in }
                )
            )
        )
        window.contentView = hostingView

        window.makeKeyAndOrderFront(nil)
        floatingWindow = window
    }

    func closeFloatingWindow() {
        floatingWindow?.orderOut(nil)
        floatingWindow = nil
    }

    func updateOpacity(_ opacity: Double) {
        floatingWindow?.alphaValue = opacity
    }
}
