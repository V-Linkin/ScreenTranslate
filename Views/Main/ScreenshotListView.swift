import SwiftUI

/// 截图列表视图
struct ScreenshotListView: View {
    let screenshots: [ScreenshotItem]
    @Binding var selectedID: UUID?

    @EnvironmentObject var appState: AppState
    @State private var viewMode: ViewMode = .list

    enum ViewMode {
        case list, grid
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            HStack {
                Text("\(screenshots.count) 张截图")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                // 视图模式切换
                Picker("", selection: $viewMode) {
                    Image(systemName: "list.bullet").tag(ViewMode.list)
                    Image(systemName: "square.grid.2x2").tag(ViewMode.grid)
                }
                .pickerStyle(.segmented)
                .frame(width: 100)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)

            Divider()

            // 截图列表
            if viewMode == .list {
                listView
            } else {
                gridView
            }
        }
    }

    // MARK: - 列表视图

    private var listView: some View {
        List(selection: $selectedID) {
            ForEach(screenshots) { screenshot in
                ScreenshotRow(screenshot: screenshot)
                    .tag(screenshot.id)
                    .contextMenu {
                        contextMenuItems(for: screenshot)
                    }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    appState.deleteScreenshot(screenshots[index].id)
                }
            }
        }
        .listStyle(.inset(alternatesRowBackgrounds: true))
    }

    // MARK: - 网格视图

    private var gridView: some View {
        ScrollView {
            LazyVGrid(columns: [
                GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 12)
            ], spacing: 12) {
                ForEach(screenshots) { screenshot in
                    ScreenshotGridItem(screenshot: screenshot, isSelected: selectedID == screenshot.id)
                        .onTapGesture {
                            selectedID = screenshot.id
                        }
                        .contextMenu {
                            contextMenuItems(for: screenshot)
                        }
                }
            }
            .padding()
        }
    }

    // MARK: - 右键菜单

    @ViewBuilder
    private func contextMenuItems(for screenshot: ScreenshotItem) -> some View {
        Button {
            if let image = screenshot.image {
                image.addToClipboard()
            }
        } label: {
            Label("复制到剪贴板", systemImage: "doc.on.doc")
        }

        Divider()

        Button("编辑", systemImage: "pencil") {
            appState.editingScreenshotID = screenshot.id
            appState.isShowingEditor = true
        }

        Button("在 Finder 中显示", systemImage: "folder") {
            if let fileName = screenshot.fileName {
                let path = appState.screenshotSettings.savePath + fileName
                NSWorkspace.shared.selectFile(path, inFileViewerRootedAtPath: "")
            }
        }

        Divider()

        Button("删除", systemImage: "trash", role: .destructive) {
            appState.deleteScreenshot(screenshot.id)
        }
    }
}

// MARK: - 列表行视图

struct ScreenshotRow: View {
    let screenshot: ScreenshotItem

    var body: some View {
        HStack(spacing: 12) {
            // 缩略图
            if let image = screenshot.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 50)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 80, height: 50)
                    .overlay {
                        Image(systemName: "photo")
                            .foregroundColor(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(screenshot.timestamp.formattedString)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let text = screenshot.recognizedText {
                    Text(String(text.prefix(60)))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                if let translation = screenshot.translation {
                    Text(String(translation.prefix(60)))
                        .font(.caption)
                        .foregroundColor(.blue)
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.vertical, 4)
    }
}

// MARK: - 网格项视图

struct ScreenshotGridItem: View {
    let screenshot: ScreenshotItem
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 6) {
            if let image = screenshot.image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 120)
                    .overlay {
                        Image(systemName: "photo")
                            .font(.largeTitle)
                            .foregroundColor(.secondary)
                    }
            }

            Text(screenshot.timestamp.shortDateString)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(isSelected ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}
