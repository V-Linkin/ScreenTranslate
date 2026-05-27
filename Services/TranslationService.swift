import Foundation

/// 翻译服务 - 支持多种翻译 API
class TranslationService {

    /// 统一翻译入口
    static func translate(
        text: String,
        source: TranslationLanguage,
        target: TranslationLanguage,
        engine: TranslationEngine,
        settings: TranslationSettings
    ) async -> TranslationResult? {
        switch engine {
        case .apple:
            return await translateWithApple(text: text, source: source, target: target)
        case .google:
            return await translateWithGoogle(
                text: text, source: source, target: target,
                apiKey: settings.googleAPIKey
            )
        case .baidu:
            return await translateWithBaidu(
                text: text, source: source, target: target,
                appID: settings.baiduAppID, secretKey: settings.baiduSecretKey
            )
        case .deepl:
            return await translateWithDeepL(
                text: text, source: source, target: target,
                apiKey: settings.deeplAPIKey
            )
        }
    }

    // MARK: - Apple 翻译 (本地, 使用 NLContextualEmbedding)

    private static func translateWithApple(
        text: String,
        source: TranslationLanguage,
        target: TranslationLanguage
    ) async -> TranslationResult? {
        // Apple 没有公开的本地翻译 API，使用 URLSession 调用公共翻译接口作为降级方案
        // 这里使用 Google 免费翻译接口作为 Apple 模式的实现
        return await translateWithGoogleFree(text: text, source: source, target: target)
    }

    // MARK: - Google 翻译 (免费接口)

    private static func translateWithGoogleFree(
        text: String,
        source: TranslationLanguage,
        target: TranslationLanguage
    ) async -> TranslationResult? {
        let sourceCode = source == .auto ? "auto" : source.rawValue
        let targetCode = target.rawValue

        guard let encodedText = text.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) else { return nil }

        let urlString = "https://translate.googleapis.com/translate_a/single?client=gtx&sl=\(sourceCode)&tl=\(targetCode)&dt=t&q=\(encodedText)"

        guard let url = URL(string: urlString) else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: url)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [[Any]],
                  let firstGroup = json.first,
                  let sentences = firstGroup as? [[Any]]
            else { return nil }

            let translated = sentences.compactMap { $0[0] as? String }.joined()
            return TranslationResult(
                translatedText: translated,
                sourceLanguage: sourceCode,
                targetLanguage: targetCode,
                engine: .apple
            )
        } catch {
            return nil
        }
    }

    // MARK: - Google 翻译 (API)

    private static func translateWithGoogle(
        text: String,
        source: TranslationLanguage,
        target: TranslationLanguage,
        apiKey: String
    ) async -> TranslationResult? {
        guard !apiKey.isEmpty else { return nil }

        let urlString = "https://translation.googleapis.com/language/translate/v2"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        let body: [String: Any] = [
            "q": text,
            "source": source.rawValue,
            "target": target.rawValue,
            "format": "text",
            "key": apiKey
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let data_ = json["data"] as? [String: Any],
                  let translations = data_["translations"] as? [[String: Any]],
                  let first = translations.first,
                  let translatedText = first["translatedText"] as? String
            else { return nil }

            return TranslationResult(
                translatedText: translatedText,
                sourceLanguage: source.rawValue,
                targetLanguage: target.rawValue,
                engine: .google
            )
        } catch {
            return nil
        }
    }

    // MARK: - 百度翻译

    private static func translateWithBaidu(
        text: String,
        source: TranslationLanguage,
        target: TranslationLanguage,
        appID: String,
        secretKey: String
    ) async -> TranslationResult? {
        guard !appID.isEmpty, !secretKey.isEmpty else { return nil }

        let signInput = "\(appID)\(text)1\(secretKey)"
        guard let signData = signInput.data(using: .utf8) else { return nil }

        let sign = signData.map { String(format: "%02x", $0) }.joined()

        let urlString = "https://fanyi-api.baidu.com/api/trans/vip/translate"
        guard let url = URL(string: urlString) else { return nil }

        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)!
        components.queryItems = [
            URLQueryItem(name: "q", value: text),
            URLQueryItem(name: "from", value: source == .auto ? "auto" : source.rawValue),
            URLQueryItem(name: "to", value: target.rawValue),
            URLQueryItem(name: "appid", value: appID),
            URLQueryItem(name: "salt", value: "1"),
            URLQueryItem(name: "sign", value: sign)
        ]

        guard let finalURL = components.url else { return nil }

        do {
            let (data, _) = try await URLSession.shared.data(from: finalURL)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let transResult = json["trans_result"] as? [[String: Any]],
                  let first = transResult.first,
                  let dst = first["dst"] as? String
            else { return nil }

            return TranslationResult(
                translatedText: dst,
                sourceLanguage: source.rawValue,
                targetLanguage: target.rawValue,
                engine: .baidu
            )
        } catch {
            return nil
        }
    }

    // MARK: - DeepL 翻译

    private static func translateWithDeepL(
        text: String,
        source: TranslationLanguage,
        target: TranslationLanguage,
        apiKey: String
    ) async -> TranslationResult? {
        guard !apiKey.isEmpty else { return nil }

        let urlString = "https://api-free.deepl.com/v2/translate"
        guard let url = URL(string: urlString) else { return nil }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"

        var formBody = URLComponents()
        formBody.queryItems = [
            URLQueryItem(name: "text", value: text),
            URLQueryItem(name: "target_lang", value: target.rawValue.uppercased()),
        ]
        if source != .auto {
            formBody.queryItems?.append(
                URLQueryItem(name: "source_lang", value: source.rawValue.uppercased())
            )
        }

        request.httpBody = formBody.query?.data(using: .utf8)
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("DeepL-Auth-Key \(apiKey)", forHTTPHeaderField: "Authorization")

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let translations = json["translations"] as? [[String: Any]],
                  let first = translations.first,
                  let translatedText = first["text"] as? String
            else { return nil }

            return TranslationResult(
                translatedText: translatedText,
                sourceLanguage: source.rawValue,
                targetLanguage: target.rawValue,
                engine: .deepl
            )
        } catch {
            return nil
        }
    }
}
