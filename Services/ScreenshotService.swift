import Cocoa
import ScreenCaptureKit

/// 截图服务
class ScreenshotService {
    static let shared = ScreenshotService()
    private init() {}

    // MARK: - 全屏截图

    func captureFullScreen(completion: @escaping (NSImage?) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            guard let image = CGDisplayCreateImage(CGMainDisplayID()) else {
                NSLog("[Screenshot] ❌ 全屏截图失败")
                DispatchQueue.main.async { completion(nil) }
                return
            }
            let nsImage = NSImage(cgImage: image, size: NSScreen.main?.frame.size ?? .zero)
            NSLog("[Screenshot] ✅ 全屏截图成功")
            DispatchQueue.main.async { completion(nsImage) }
        }
    }

    // MARK: - 区域截图

    func captureArea(completion: @escaping (NSImage?) -> Void) {
        NSLog("[Screenshot] 开始区域截图...")

        let tempPath = NSTemporaryDirectory() + "st_area_\(UUID().uuidString).png"
        NSLog("[Screenshot] 临时路径: \(tempPath)")

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-i", tempPath]

        // 捕获标准输出和错误
        let outPipe = Pipe()
        let errPipe = Pipe()
        task.standardOutput = outPipe
        task.standardError = errPipe

        task.terminationHandler = { process in
            let exitCode = process.terminationStatus
            NSLog("[Screenshot] screencapture 退出码: \(exitCode)")

            // 读取错误输出
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            if let errStr = String(data: errData, encoding: .utf8), !errStr.isEmpty {
                NSLog("[Screenshot] stderr: \(errStr)")
            }

            DispatchQueue.main.async {
                let fileExists = FileManager.default.fileExists(atPath: tempPath)
                NSLog("[Screenshot] 文件存在: \(fileExists)")

                if fileExists {
                    if let image = NSImage(contentsOfFile: tempPath) {
                        NSLog("[Screenshot] ✅ 区域截图成功，尺寸: \(image.size)")
                        completion(image)
                    } else {
                        NSLog("[Screenshot] ❌ 无法加载图片")
                        completion(nil)
                    }
                    try? FileManager.default.removeItem(atPath: tempPath)
                } else {
                    NSLog("[Screenshot] ❌ 截图文件未生成（用户可能按了 Esc 取消）")
                    completion(nil)
                }
            }
        }

        do {
            try task.run()
            NSLog("[Screenshot] screencapture 进程已启动，等待用户选择区域...")
        } catch {
            NSLog("[Screenshot] ❌ 启动失败: \(error)")
            DispatchQueue.main.async { completion(nil) }
        }
    }

    // MARK: - 窗口截图

    func captureWindow(completion: @escaping (NSImage?) -> Void) {
        let tempPath = NSTemporaryDirectory() + "st_window_\(UUID().uuidString).png"

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        task.arguments = ["-w", tempPath]

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                if let image = NSImage(contentsOfFile: tempPath) {
                    completion(image)
                    try? FileManager.default.removeItem(atPath: tempPath)
                } else {
                    completion(nil)
                }
            }
        }

        do { try task.run() } catch { DispatchQueue.main.async { completion(nil) } }
    }

    // MARK: - 保存截图

    func saveScreenshot(_ image: NSImage, settings: ScreenshotSettings) -> URL? {
        let folderPath = settings.savePath
        if !FileManager.default.fileExists(atPath: folderPath) {
            try? FileManager.default.createDirectory(atPath: folderPath, withIntermediateDirectories: true)
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        let fileName = "\(settings.fileNamePrefix)_\(formatter.string(from: Date())).\(settings.defaultFormat.fileExtension)"
        let fileURL = URL(fileURLWithPath: folderPath).appendingPathComponent(fileName)
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else { return nil }
        let data: Data?
        switch settings.defaultFormat {
        case .png: data = bitmap.representation(using: .png, properties: [:])
        case .jpg: data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        }
        guard let outputData = data else { return nil }
        try? outputData.write(to: fileURL)
        return fileURL
    }
}
