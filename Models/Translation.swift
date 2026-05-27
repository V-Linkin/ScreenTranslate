import Foundation

/// 翻译引擎
enum TranslationEngine: String, CaseIterable, Codable, Identifiable {
    case google = "google"
    case baidu = "baidu"
    case deepl = "deepl"
    case apple = "apple"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .google: return "Google 翻译"
        case .baidu: return "百度翻译"
        case .deepl: return "DeepL 翻译"
        case .apple: return "Apple 翻译"
        }
    }

    var icon: String {
        switch self {
        case .google: return "globe"
        case .baidu: return "character.bubble"
        case .deepl: return "text.bubble"
        case .apple: return "apple.logo"
        }
    }
}

/// 翻译语言
enum TranslationLanguage: String, CaseIterable, Codable, Identifiable {
    case auto = "auto"
    case chinese = "zh"
    case english = "en"
    case japanese = "ja"
    case korean = "ko"
    case french = "fr"
    case german = "de"
    case spanish = "es"
    case portuguese = "pt"
    case russian = "ru"
    case italian = "it"
    case arabic = "ar"
    case thai = "th"
    case vietnamese = "vi"
    case indonesian = "id"
    case turkish = "tr"
    case dutch = "nl"
    case polish = "pl"
    case hindi = "hi"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .auto: return "自动检测"
        case .chinese: return "中文"
        case .english: return "英语"
        case .japanese: return "日语"
        case .korean: return "韩语"
        case .french: return "法语"
        case .german: return "德语"
        case .spanish: return "西班牙语"
        case .portuguese: return "葡萄牙语"
        case .russian: return "俄语"
        case .italian: return "意大利语"
        case .arabic: return "阿拉伯语"
        case .thai: return "泰语"
        case .vietnamese: return "越南语"
        case .indonesian: return "印尼语"
        case .turkish: return "土耳其语"
        case .dutch: return "荷兰语"
        case .polish: return "波兰语"
        case .hindi: return "印地语"
        }
    }
}

/// 翻译请求
struct TranslationRequest {
    let text: String
    let sourceLanguage: TranslationLanguage
    let targetLanguage: TranslationLanguage
    let engine: TranslationEngine
}

/// 翻译结果
struct TranslationResult {
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let engine: TranslationEngine
}

/// 翻译错误
enum TranslationError: LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case quotaExceeded
    case unsupportedLanguage
    case decodingError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey: return "API Key 无效"
        case .networkError(let error): return "网络错误: \(error.localizedDescription)"
        case .quotaExceeded: return "翻译配额已用完"
        case .unsupportedLanguage: return "不支持的语言"
        case .decodingError: return "响应解码失败"
        case .unknown(let msg): return msg
        }
    }
}
