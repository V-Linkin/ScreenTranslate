import SwiftUI
import AppKit

// MARK: - Notification.Name

extension Notification.Name {
    static let screenshotCaptured = Notification.Name("screenshotCaptured")
    static let screenshotDeleted = Notification.Name("screenshotDeleted")
    static let settingsChanged = Notification.Name("settingsChanged")
}

// MARK: - NSImage 扩展

extension NSImage {
    func resized(to maxSize: NSSize) -> NSImage {
        let widthRatio = maxSize.width / size.width
        let heightRatio = maxSize.height / size.height
        let ratio = min(widthRatio, heightRatio, 1.0)

        let newSize = NSSize(
            width: size.width * ratio,
            height: size.height * ratio
        )

        let newImage = NSImage(size: newSize)
        newImage.lockFocus()
        draw(
            in: NSRect(origin: .zero, size: newSize),
            from: NSRect(origin: .zero, size: size),
            operation: .copy,
            fraction: 1.0
        )
        newImage.unlockFocus()
        return newImage
    }

    func crop(to rect: CGRect) -> NSImage? {
        guard let cgImage = cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }
        guard let cropped = cgImage.cropping(to: rect) else { return nil }
        return NSImage(cgImage: cropped, size: rect.size)
    }

    func addToClipboard() {
        NSPasteboard.general.clearContents()
        if let tiffData = tiffRepresentation {
            NSPasteboard.general.setData(tiffData, forType: .tiff)
        }
    }
}

// MARK: - Date 扩展

extension Date {
    var formattedString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: self)
    }

    var shortDateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd HH:mm"
        return formatter.string(from: self)
    }

    var fileSafeString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd_HHmmss"
        return formatter.string(from: self)
    }
}

// MARK: - View 扩展

extension View {
    func hideKeyboard() {
        NSApp.keyWindow?.makeFirstResponder(nil)
    }

    func roundedCard() -> some View {
        self
            .padding()
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Color 扩展

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - UserDefaults 扩展

extension UserDefaults {
    func decode<T: Decodable>(_ key: String) -> T? {
        guard let data = data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }

    func encode<T: Encodable>(_ key: String, value: T) {
        if let data = try? JSONEncoder().encode(value) {
            set(data, forKey: key)
        }
    }
}

// MARK: - String 扩展

extension String {
    var isNotEmpty: Bool { !isEmpty }
}
