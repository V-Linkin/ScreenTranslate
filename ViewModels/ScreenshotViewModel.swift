import Foundation
import AppKit
import Combine

/// 截图 ViewModel
class ScreenshotViewModel: ObservableObject {
    @Published var selectedScreenshot: ScreenshotItem?
    @Published var isCapturing = false
    @Published var captureMode: CaptureMode = .area
    @Published var showingShareSheet = false

    private var cancellables = Set<AnyCancellable>()

    enum CaptureMode {
        case fullScreen, area, window
    }

    init() {
        NotificationCenter.default.publisher(for: .screenshotCaptured)
            .compactMap { $0.object as? ScreenshotItem }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] screenshot in
                self?.selectedScreenshot = screenshot
            }
            .store(in: &cancellables)
    }

    // MARK: - 截图操作

    @MainActor
    func captureFullScreen() {
        isCapturing = true
        ScreenshotService.shared.captureFullScreen { [weak self] image in
            DispatchQueue.main.async {
                self?.isCapturing = false
                guard let image = image else { return }
                self?.processCapturedImage(image)
            }
        }
    }

    @MainActor
    func captureArea() {
        isCapturing = true
        ScreenshotService.shared.captureArea { [weak self] image in
            DispatchQueue.main.async {
                self?.isCapturing = false
                guard let image = image else { return }
                self?.processCapturedImage(image)
            }
        }
    }

    @MainActor
    func captureWindow() {
        isCapturing = true
        ScreenshotService.shared.captureWindow { [weak self] image in
            DispatchQueue.main.async {
                self?.isCapturing = false
                guard let image = image else { return }
                self?.processCapturedImage(image)
            }
        }
    }

    // MARK: - 处理截图

    private func processCapturedImage(_ image: NSImage) {
        // 复制到剪贴板
        image.addToClipboard()

        let screenshot = ScreenshotItem(image: image)
        NotificationCenter.default.post(
            name: .screenshotCaptured,
            object: screenshot
        )
    }

    // MARK: - 导出

    func exportScreenshot(_ screenshot: ScreenshotItem, format: ScreenshotSettings.ImageFormat) {
        guard let image = screenshot.image else { return }

        let panel = NSSavePanel()
        panel.allowedContentTypes = format == .png ? [.png] : [.jpeg]
        panel.nameFieldStringValue = screenshot.fileName ?? "screenshot_\(screenshot.timestamp.fileSafeString)"
        panel.canCreateDirectories = true

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            guard let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData) else { return }

            let data: Data?
            switch format {
            case .png:
                data = bitmap.representation(using: .png, properties: [:])
            case .jpg:
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            }

            if let data = data {
                try? data.write(to: url)
            }
        }
    }

    func shareScreenshot(_ screenshot: ScreenshotItem) {
        guard let image = screenshot.image else { return }

        let picker = NSSharingServicePicker(items: [image])
        if let window = NSApp.keyWindow {
            let rect = NSRect(x: window.frame.midX, y: window.frame.midY, width: 1, height: 1)
            picker.show(relativeTo: rect, of: window.contentView!, preferredEdge: .minY)
        }
    }
}
