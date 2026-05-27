import Foundation
import AppKit

/// 截图数据模型
struct ScreenshotItem: Identifiable, Codable {
    let id: UUID
    var imageData: Data?
    var timestamp: Date
    var recognizedText: String?
    var translation: String?
    var sourceLanguage: String?
    var targetLanguage: String?
    var fileName: String?

    var image: NSImage? {
        guard let data = imageData else { return nil }
        return NSImage(data: data)
    }

    init(
        id: UUID = UUID(),
        image: NSImage? = nil,
        imageData: Data? = nil,
        timestamp: Date = Date(),
        recognizedText: String? = nil,
        translation: String? = nil,
        sourceLanguage: String? = nil,
        targetLanguage: String? = nil,
        fileName: String? = nil
    ) {
        self.id = id
        self.imageData = imageData ?? image?.tiffRepresentation
        self.timestamp = timestamp
        self.recognizedText = recognizedText
        self.translation = translation
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.fileName = fileName
    }

    enum CodingKeys: String, CodingKey {
        case id, imageData, timestamp, recognizedText, translation
        case sourceLanguage, targetLanguage, fileName
    }
}
