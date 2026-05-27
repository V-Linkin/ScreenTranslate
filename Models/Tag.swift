import Foundation

/// 截图设置
struct ScreenshotSettings: Codable {
    var savePath: String
    var defaultFormat: ImageFormat
    var autoTranslate: Bool
    var fileNamePrefix: String
    var openEditorAfterCapture: Bool
    var copyToClipboard: Bool

    enum ImageFormat: String, CaseIterable, Codable {
        case png = "PNG"
        case jpg = "JPG"

        var fileExtension: String { rawValue.lowercased() }
    }

    static let `default` = ScreenshotSettings(
        savePath: NSHomeDirectory() + "/Documents/ScreenTranslate/",
        defaultFormat: .png,
        autoTranslate: true,
        fileNamePrefix: "截图",
        openEditorAfterCapture: false,
        copyToClipboard: true
    )
}

/// 翻译设置
struct TranslationSettings: Codable {
    var engine: TranslationEngine
    var sourceLanguage: TranslationLanguage
    var targetLanguage: TranslationLanguage
    var baiduAppID: String
    var baiduSecretKey: String
    var deeplAPIKey: String
    var googleAPIKey: String

    static let `default` = TranslationSettings(
        engine: .apple,
        sourceLanguage: .auto,
        targetLanguage: .english,
        baiduAppID: "",
        baiduSecretKey: "",
        deeplAPIKey: "",
        googleAPIKey: ""
    )
}

/// 应用状态
class AppState: ObservableObject {
    static var shared: AppState?

    @Published var screenshots: [ScreenshotItem] = []
    @Published var screenshotSettings: ScreenshotSettings
    @Published var translationSettings: TranslationSettings
    @Published var selectedScreenshotID: UUID?
    @Published var searchText: String = ""
    @Published var isShowingEditor: Bool = false
    @Published var editingScreenshotID: UUID?

    init() {
        self.screenshotSettings = UserDefaults.standard.decode("screenshotSettings") ?? .default
        self.translationSettings = UserDefaults.standard.decode("translationSettings") ?? .default
        AppState.shared = self

        loadScreenshots()

        NotificationCenter.default.addObserver(
            forName: .screenshotCaptured,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let screenshot = notification.object as? ScreenshotItem {
                Task { @MainActor in
                    self?.addScreenshot(screenshot)
                }
            }
        }
    }

    var filteredScreenshots: [ScreenshotItem] {
        var result = screenshots

        if !searchText.isEmpty {
            result = result.filter { screenshot in
                (screenshot.recognizedText?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (screenshot.translation?.localizedCaseInsensitiveContains(searchText) ?? false) ||
                (screenshot.fileName?.localizedCaseInsensitiveContains(searchText) ?? false)
            }
        }

        return result.sorted { $0.timestamp > $1.timestamp }
    }

    @MainActor
    func addScreenshot(_ screenshot: ScreenshotItem) {
        screenshots.insert(screenshot, at: 0)
        selectedScreenshotID = screenshot.id
        saveScreenshots()
    }

    @MainActor
    func deleteScreenshot(_ id: UUID) {
        screenshots.removeAll { $0.id == id }
        if selectedScreenshotID == id {
            selectedScreenshotID = screenshots.first?.id
        }
        saveScreenshots()
    }

    @MainActor
    func updateScreenshotTranslation(id: UUID, text: String, source: String, target: String) {
        if let index = screenshots.firstIndex(where: { $0.id == id }) {
            screenshots[index].translation = text
            screenshots[index].sourceLanguage = source
            screenshots[index].targetLanguage = target
            saveScreenshots()
        }
    }

    // MARK: - Private

    @MainActor
    private func performOCR(for screenshot: ScreenshotItem) {
        guard let image = screenshot.image else { return }
        OCRService.recognizeText(from: image) { [weak self] text in
            guard let text = text else { return }
            DispatchQueue.main.async {
                guard let self = self else { return }
                if let index = self.screenshots.firstIndex(where: { $0.id == screenshot.id }) {
                    self.screenshots[index].recognizedText = text
                    self.saveScreenshots()

                    if self.screenshotSettings.autoTranslate {
                        Task { @MainActor in
                            await self.performTranslation(for: self.screenshots[index])
                        }
                    }
                }
            }
        }
    }

    @MainActor
    private func performTranslation(for screenshot: ScreenshotItem) async {
        guard let text = screenshot.recognizedText, !text.isEmpty else { return }
        let result = await TranslationService.translate(
            text: text,
            source: translationSettings.sourceLanguage,
            target: translationSettings.targetLanguage,
            engine: translationSettings.engine,
            settings: translationSettings
        )

        if let result = result {
            await MainActor.run {
                self.updateScreenshotTranslation(
                    id: screenshot.id,
                    text: result.translatedText,
                    source: result.sourceLanguage,
                    target: result.targetLanguage
                )
            }
        }
    }

    // MARK: - Persistence

    private func saveScreenshots() {
        let data = try? JSONEncoder().encode(screenshots)
        UserDefaults.standard.set(data, forKey: "screenshots")
    }

    private func loadScreenshots() {
        guard let data = UserDefaults.standard.data(forKey: "screenshots"),
              let loaded = try? JSONDecoder().decode([ScreenshotItem].self, from: data) else { return }
        screenshots = loaded
    }

    func saveSettings() {
        if let data = try? JSONEncoder().encode(screenshotSettings) {
            UserDefaults.standard.set(data, forKey: "screenshotSettings")
        }
        if let data = try? JSONEncoder().encode(translationSettings) {
            UserDefaults.standard.set(data, forKey: "translationSettings")
        }
    }
}
