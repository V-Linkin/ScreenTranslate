import SwiftUI

/// 编辑器工具栏视图
struct EditorToolbarView: View {
    @Binding var selectedTool: EditorView.AnnotationTool
    @Binding var strokeColor: Color
    @Binding var strokeWidth: CGFloat

    var body: some View {
        HStack(spacing: 12) {
            ForEach(EditorView.AnnotationTool.allCases, id: \.self) { tool in
                Button {
                    selectedTool = tool
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: iconForTool(tool))
                            .font(.body)
                        Text(tool.rawValue)
                            .font(.caption2)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(selectedTool == tool ? Color.accentColor.opacity(0.2) : Color.clear)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                }
                .buttonStyle(.plain)
            }

            Divider()
                .frame(height: 20)

            ColorPicker("", selection: $strokeColor)
                .labelsHidden()

            Slider(value: $strokeWidth, in: 1...10, step: 1)
                .frame(width: 100)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    private func iconForTool(_ tool: EditorView.AnnotationTool) -> String {
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
}
