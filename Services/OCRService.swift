import Foundation
import Vision
import AppKit

/// OCR 服务
class OCRService {

    static func recognizeText(from image: NSImage, completion: @escaping (String?) -> Void) {
        // 确保在后台线程执行
        DispatchQueue.global(qos: .userInitiated).async {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                NSLog("[OCR] ❌ 无法获取 CGImage")
                DispatchQueue.main.async { completion(nil) }
                return
            }

            NSLog("[OCR] 图片: \(cgImage.width)x\(cgImage.height), bpc=\(cgImage.bitsPerComponent), bpp=\(cgImage.bitsPerPixel)")

            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    NSLog("[OCR] ❌ 出错: \(error)")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    NSLog("[OCR] ❌ 无结果，results type: \(type(of: request.results))")
                    DispatchQueue.main.async { completion(nil) }
                    return
                }

                NSLog("[OCR] 观察到 \(observations.count) 个文字区域")

                let texts = observations.compactMap { obs -> String? in
                    let candidates = obs.topCandidates(1)
                    return candidates.first?.string
                }

                let result = texts.joined(separator: "\n")
                NSLog("[OCR] ✅ 识别完成: \(result.count) 字")
                DispatchQueue.main.async { completion(result.isEmpty ? nil : result) }
            }

            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en", "ja", "ko"]
            request.usesLanguageCorrection = true

            do {
                let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
                NSLog("[OCR] 开始 perform...")
                try handler.perform([request])
                NSLog("[OCR] perform 完成")
            } catch {
                NSLog("[OCR] ❌ perform 失败: \(error)")
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
}
