import SwiftUI

/// 截图缩略图组件
struct ScreenshotThumbnail: View {
    let image: NSImage?
    let size: CGSize
    var showBorder: Bool = true

    var body: some View {
        Group {
            if let image = image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                placeholderView
            }
        }
        .frame(width: size.width, height: size.height)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(showBorder ? Color.secondary.opacity(0.3) : Color.clear, lineWidth: 1)
        )
    }

    private var placeholderView: some View {
        ZStack {
            Color.gray.opacity(0.2)
            VStack(spacing: 4) {
                Image(systemName: "photo")
                    .font(.title3)
                    .foregroundColor(.secondary)
            }
        }
    }
}
