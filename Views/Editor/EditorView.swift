import SwiftUI

/// 截图编辑器视图
struct EditorView: View {
    @EnvironmentObject var appState: AppState
    @State private var screenshot: ScreenshotItem?
    @State private var annotations: [Annotation] = []
    @State private var selectedTool: AnnotationTool = .arrow
    @State private var strokeColor: Color = .red
    @State private var strokeWidth: CGFloat = 2.0
    @State private var undoStack: [Annotation] = []
    @State private var redoStack: [Annotation] = []
    @State private var isMosaicMode = false
    @State private var mosaicRadius: CGFloat = 10

    @Environment(\.dismiss) private var dismiss

    enum AnnotationTool: String, CaseIterable {
        case arrow = "箭头"
        case text = "文字"
        case rectangle = "矩形"
        case circle = "圆形"
        case highlight = "高亮"
        case mosaic = "马赛克"
        case crop = "裁剪"
    }

    struct Annotation: Identifiable {
        let id = UUID()
        var type: AnnotationTool
        var startPoint: CGPoint
        var endPoint: CGPoint
        var color: Color
        var lineWidth: CGFloat
        var text: String?
    }

    var body: some View {
        VStack(spacing: 0) {
            // 顶部工具栏
            editorToolbar

            Divider()

            HStack(spacing: 0) {
                // 左侧工具栏
                toolPanel
                    .frame(width: 80)

                Divider()

                // 中间编辑区域
                editorCanvas

                Divider()

                // 右侧属性面板
                propertyPanel
                    .frame(width: 180)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .onAppear {
            loadScreenshot()
        }
    }

    // MARK: - 顶部工具栏

    private var editorToolbar: some View {
        HStack(spacing: 16) {
            Button {
                undo()
            } label: {
                Image(systemName: "arrow.uturn.backward")
            }
            .disabled(undoStack.isEmpty)
            .help("撤销")

            Button {
                redo()
            } label: {
                Image(systemName: "arrow.uturn.forward")
            }
            .disabled(redoStack.isEmpty)
            .help("重做")

            Divider()

            Button {
                saveToDisk()
            } label: {
                Label("保存", systemImage: "square.and.arrow.down")
            }

            Button {
                if let image = captureEditedImage() {
                    image.addToClipboard()
                }
            } label: {
                Label("复制", systemImage: "doc.on.doc")
            }

            Button {
                if let image = captureEditedImage() {
                    let picker = NSSharingServicePicker(items: [image])
                    if let window = NSApp.keyWindow {
                        let rect = NSRect(x: 0, y: 0, width: 1, height: 1)
                        picker.show(relativeTo: rect, of: window.contentView!, preferredEdge: .minY)
                    }
                }
            } label: {
                Label("分享", systemImage: "square.and.arrow.up")
            }

            Spacer()

            Button("完成") {
                dismiss()
            }
            .keyboardShortcut(.escape)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - 左侧工具面板

    private var toolPanel: some View {
        VStack(spacing: 8) {
            ForEach(AnnotationTool.allCases, id: \.self) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: iconForTool(tool))
                            .font(.title3)
                        Text(tool.rawValue)
                            .font(.caption2)
                    }
                    .frame(width: 68, height: 50)
                    .background(selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.vertical, 8)
    }

    // MARK: - 编辑画布

    private var editorCanvas: some View {
        GeometryReader { geometry in
            ZStack {
                Color(nsColor: .windowBackgroundColor)

                if let image = screenshot?.image {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }

                // 绘制标注
                ForEach(annotations) { annotation in
                    annotationView(annotation)
                }
            }
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        handleDragChange(value, in: geometry)
                    }
                    .onEnded { value in
                        handleDragEnd(value, in: geometry)
                    }
            )
        }
    }

    // MARK: - 右侧属性面板

    private var propertyPanel: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("属性")
                .font(.headline)
                .padding(.bottom, 4)

            VStack(alignment: .leading, spacing: 8) {
                Text("颜色")
                    .font(.subheadline)
                ColorPicker("", selection: $strokeColor)
                    .labelsHidden()
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("线宽: \(Int(strokeWidth))")
                    .font(.subheadline)
                Slider(value: $strokeWidth, in: 1...10, step: 1)
            }

            if selectedTool == .mosaic {
                VStack(alignment: .leading, spacing: 8) {
                    Text("马赛克大小: \(Int(mosaicRadius))")
                        .font(.subheadline)
                    Slider(value: $mosaicRadius, in: 5...30, step: 5)
                }
            }

            Divider()

            // 标注列表
            Text("标注列表")
                .font(.subheadline)

            List {
                ForEach(annotations) { annotation in
                    HStack {
                        Image(systemName: iconForTool(annotation.type))
                            .foregroundColor(.accentColor)
                        Text(annotation.type.rawValue)
                            .font(.caption)
                        Spacer()
                        Button {
                            removeAnnotation(annotation)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }

            Spacer()
        }
        .padding()
    }

    // MARK: - 标注视图

    @ViewBuilder
    private func annotationView(_ annotation: Annotation) -> some View {
        let rect = CGRect(
            x: min(annotation.startPoint.x, annotation.endPoint.x),
            y: min(annotation.startPoint.y, annotation.endPoint.y),
            width: abs(annotation.endPoint.x - annotation.startPoint.x),
            height: abs(annotation.endPoint.y - annotation.startPoint.y)
        )

        switch annotation.type {
        case .rectangle:
            Rectangle()
                .stroke(annotation.color, lineWidth: annotation.lineWidth)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

        case .circle:
            Ellipse()
                .stroke(annotation.color, lineWidth: annotation.lineWidth)
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

        case .highlight:
            Rectangle()
                .fill(annotation.color.opacity(0.3))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)

        case .arrow:
            Path { path in
                path.move(to: annotation.startPoint)
                path.addLine(to: annotation.endPoint)
            }
            .stroke(annotation.color, lineWidth: annotation.lineWidth)

        case .text:
            if let text = annotation.text, !text.isEmpty {
                Text(text)
                    .font(.system(size: annotation.lineWidth * 6))
                    .foregroundColor(annotation.color)
                    .position(x: annotation.startPoint.x, y: annotation.startPoint.y)
            }

        case .mosaic:
            Rectangle()
                .fill(Color.gray.opacity(0.5))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
                .overlay {
                    ForEach(0..<Int(rect.width / mosaicRadius), id: \.self) { i in
                        ForEach(0..<Int(rect.height / mosaicRadius), id: \.self) { j in
                            Rectangle()
                                .fill(Color.gray.opacity(Double.random(in: 0.2...0.8)))
                                .frame(width: mosaicRadius - 1, height: mosaicRadius - 1)
                                .position(
                                    x: rect.minX + CGFloat(i) * mosaicRadius + mosaicRadius / 2,
                                    y: rect.minY + CGFloat(j) * mosaicRadius + mosaicRadius / 2
                                )
                        }
                    }
                }

        case .crop:
            Rectangle()
                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6, 3]))
                .frame(width: rect.width, height: rect.height)
                .position(x: rect.midX, y: rect.midY)
        }
    }

    // MARK: - 操作方法

    @State private var dragStart: CGPoint?

    private func handleDragChange(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        // 处理拖拽中...
    }

    private func handleDragEnd(_ value: DragGesture.Value, in geometry: GeometryProxy) {
        let start = dragStart ?? value.startLocation
        let end = value.location

        guard start != end else { return }

        if selectedTool == .text {
            let annotation = Annotation(
                type: selectedTool,
                startPoint: start,
                endPoint: end,
                color: strokeColor,
                lineWidth: strokeWidth,
                text: "文本"
            )
            addAnnotation(annotation)
        } else {
            let annotation = Annotation(
                type: selectedTool,
                startPoint: start,
                endPoint: end,
                color: strokeColor,
                lineWidth: strokeWidth
            )
            addAnnotation(annotation)
        }
    }

    private func addAnnotation(_ annotation: Annotation) {
        undoStack.append(contentsOf: annotations)
        redoStack.removeAll()
        annotations.append(annotation)
    }

    private func removeAnnotation(_ annotation: Annotation) {
        annotations.removeAll { $0.id == annotation.id }
    }

    private func undo() {
        guard !undoStack.isEmpty else { return }
        redoStack.append(contentsOf: annotations)
        annotations = undoStack
        undoStack.removeAll()
    }

    private func redo() {
        guard !redoStack.isEmpty else { return }
        undoStack.append(contentsOf: annotations)
        annotations = redoStack
        redoStack.removeAll()
    }

    private func iconForTool(_ tool: AnnotationTool) -> String {
        switch tool {
        case .arrow: return "arrow.up.right"
        case .text: return "textformat"
        case .rectangle: return "rectangle"
        case .circle: return "circle"
        case .highlight: return "highlighter"
        case .mosaic: return "checkerboard"
        case .crop: return "crop"
        }
    }

    private func loadScreenshot() {
        if let id = appState.editingScreenshotID {
            screenshot = appState.screenshots.first { $0.id == id }
        }
    }

    private func captureEditedImage() -> NSImage? {
        guard let image = screenshot?.image else { return nil }
        return image
    }

    private func saveToDisk() {
        guard let image = captureEditedImage() else { return }
        let _ = try? StorageService.shared.saveImage(
            image,
            to: appState.screenshotSettings.savePath,
            fileName: "edited_\(Date().fileSafeString).png"
        )
    }
}
