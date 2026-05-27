import Foundation
import AppKit

/// 存储服务 - 管理截图文件的本地存储
class StorageService {
    static let shared = StorageService()

    private let fileManager = FileManager.default

    private init() {}

    // MARK: - 目录管理

    var defaultStoragePath: String {
        NSHomeDirectory() + "/Documents/ScreenTranslate/"
    }

    func ensureDirectoryExists(at path: String) throws {
        if !fileManager.fileExists(atPath: path) {
            try fileManager.createDirectory(
                atPath: path,
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    // MARK: - 文件保存

    func saveImage(_ image: NSImage, to folder: String, fileName: String) throws -> URL {
        try ensureDirectoryExists(at: folder)

        let fileURL = URL(fileURLWithPath: folder).appendingPathComponent(fileName)

        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData),
              let pngData = bitmap.representation(using: .png, properties: [:])
        else {
            throw StorageError.imageConversionFailed
        }

        try pngData.write(to: fileURL)
        return fileURL
    }

    func saveImageData(_ data: Data, to folder: String, fileName: String) throws -> URL {
        try ensureDirectoryExists(at: folder)

        let fileURL = URL(fileURLWithPath: folder).appendingPathComponent(fileName)
        try data.write(to: fileURL)
        return fileURL
    }

    // MARK: - 文件读取

    func loadImage(from path: String) -> NSImage? {
        NSImage(contentsOfFile: path)
    }

    func listFiles(in folder: String, extensions: [String]? = nil) -> [URL] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: URL(fileURLWithPath: folder),
            includingPropertiesForKeys: nil
        ) else { return [] }

        if let extensions = extensions {
            return contents.filter { extensions.contains($0.pathExtension.lowercased()) }
        }
        return contents
    }

    // MARK: - 文件删除

    func deleteFile(at path: String) throws {
        if fileManager.fileExists(atPath: path) {
            try fileManager.removeItem(atPath: path)
        }
    }

    func deleteFiles(at paths: [String]) {
        for path in paths {
            try? deleteFile(at: path)
        }
    }

    // MARK: - 文件移动

    func moveFile(from source: String, to destination: String) throws {
        try ensureDirectoryExists(at: (destination as NSString).deletingLastPathComponent)
        try fileManager.moveItem(atPath: source, toPath: destination)
    }

    // MARK: - 获取存储大小

    func folderSize(at path: String) -> Int64 {
        guard let enumerator = fileManager.enumerator(
            at: URL(fileURLWithPath: path),
            includingPropertiesForKeys: [.fileSizeKey]
        ) else { return 0 }

        var totalSize: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let attrs = try? fileManager.attributesOfItem(atPath: fileURL.path),
               let size = attrs[.size] as? Int64 {
                totalSize += size
            }
        }
        return totalSize
    }

    func formattedSize(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

enum StorageError: LocalizedError {
    case imageConversionFailed
    case fileNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .imageConversionFailed: return "图片转换失败"
        case .fileNotFound: return "文件未找到"
        case .permissionDenied: return "权限不足"
        }
    }
}
