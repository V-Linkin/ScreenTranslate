import Foundation
import Combine

/// 翻译 ViewModel
class TranslationViewModel: ObservableObject {
    @Published var inputText: String = ""
    @Published var translatedText: String = ""
    @Published var isTranslating = false
    @Published var sourceLanguage: TranslationLanguage = .auto
    @Published var targetLanguage: TranslationLanguage = .english
    @Published var selectedEngine: TranslationEngine = .apple
    @Published var errorMessage: String?
    @Published var translationHistory: [TranslationHistoryItem] = []

    private var cancellables = Set<AnyCancellable>()

    struct TranslationHistoryItem: Identifiable, Codable {
        let id: UUID
        let originalText: String
        let translatedText: String
        let sourceLanguage: String
        let targetLanguage: String
        let engine: String
        let timestamp: Date

        init(originalText: String, translatedText: String, sourceLanguage: String,
             targetLanguage: String, engine: String) {
            self.id = UUID()
            self.originalText = originalText
            self.translatedText = translatedText
            self.sourceLanguage = sourceLanguage
            self.targetLanguage = targetLanguage
            self.engine = engine
            self.timestamp = Date()
        }
    }

    init() {
        loadHistory()
    }

    // MARK: - 翻译

    @MainActor
    func translate(text: String, settings: TranslationSettings) async {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }

        isTranslating = true
        errorMessage = nil

        let result = await TranslationService.translate(
            text: text,
            source: sourceLanguage,
            target: targetLanguage,
            engine: selectedEngine,
            settings: settings
        )

        isTranslating = false
        if let result = result {
            translatedText = result.translatedText
            addToHistory(
                originalText: text,
                translatedText: result.translatedText,
                sourceLanguage: result.sourceLanguage,
                targetLanguage: result.targetLanguage,
                engine: result.engine.rawValue
            )
        } else {
            errorMessage = "翻译失败，请检查网络连接或 API Key 设置"
        }
    }

    @MainActor
    func translateScreenshot(_ screenshot: ScreenshotItem, settings: TranslationSettings) async {
        inputText = screenshot.recognizedText ?? ""
        await translate(text: screenshot.recognizedText ?? "", settings: settings)
    }

    // MARK: - 历史记录

    @MainActor
    private func addToHistory(originalText: String, translatedText: String,
                              sourceLanguage: String, targetLanguage: String, engine: String) {
        let item = TranslationHistoryItem(
            originalText: originalText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            engine: engine
        )
        translationHistory.insert(item, at: 0)
        saveHistory()
    }

    func clearHistory() {
        translationHistory.removeAll()
        saveHistory()
    }

    func deleteHistoryItem(_ id: UUID) {
        translationHistory.removeAll { $0.id == id }
        saveHistory()
    }

    // MARK: - 语言交换

    func swapLanguages() {
        if sourceLanguage != .auto {
            let temp = sourceLanguage
            sourceLanguage = targetLanguage
            targetLanguage = temp
        }
    }

    // MARK: - 持久化

    private func saveHistory() {
        if let data = try? JSONEncoder().encode(translationHistory) {
            UserDefaults.standard.set(data, forKey: "translationHistory")
        }
    }

    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: "translationHistory"),
              let loaded = try? JSONDecoder().decode([TranslationHistoryItem].self, from: data)
        else { return }
        translationHistory = loaded
    }
}
