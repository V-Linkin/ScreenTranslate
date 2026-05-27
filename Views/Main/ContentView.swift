import SwiftUI

/// 主内容视图
struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var screenshotVM = ScreenshotViewModel()
    @StateObject private var translationVM = TranslationViewModel()

    @State private var selectedSidebar: String? = "all"

    var body: some View {
        NavigationSplitView {
            sidebarView
        } detail: {
            detailView
        }
        .frame(minWidth: 900, minHeight: 600)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                captureButtons
                Spacer()
                searchField
                settingsButton
            }
        }
    }

    // MARK: - 侧边栏

    private var sidebarView: some View {
        List(selection: $selectedSidebar) {
            Section("截图") {
                Label("全部截图", systemImage: "photo.on.rectangle")
                    .tag("all")
                Label("翻译历史", systemImage: "clock.arrow.circlepath")
                    .tag("history")
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("ScreenTranslate")
        .frame(minWidth: 180)
    }

    // MARK: - 详情视图

    private var detailView: some View {
        Group {
            switch selectedSidebar {
            case "history":
                TranslationHistoryView(translationVM: translationVM)
            default:
                if appState.selectedScreenshotID != nil,
                   appState.screenshots.contains(where: { $0.id == appState.selectedScreenshotID }) {
                    ScreenshotDetailView()
                } else {
                    emptyStateView
                }
            }
        }
    }

    // MARK: - 空状态

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 64))
                .foregroundColor(.secondary)

            Text("暂无截图")
                .font(.title2)
                .foregroundColor(.secondary)

            Text("点击工具栏按钮或使用快捷键开始截图")
                .font(.body)
                .foregroundColor(.secondary)

            HStack(spacing: 20) {
                captureButton(title: "全屏截图", icon: "rectangle.inset.filled", action: {
                    screenshotVM.captureFullScreen()
                })
                captureButton(title: "区域截图", icon: "rectangle.dashed", action: {
                    screenshotVM.captureArea()
                })
                captureButton(title: "窗口截图", icon: "macwindow", action: {
                    screenshotVM.captureWindow()
                })
            }
            .padding(.top, 10)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - 工具栏

    private var captureButtons: some View {
        HStack(spacing: 8) {
            Button { screenshotVM.captureFullScreen() } label: {
                Image(systemName: "rectangle.inset.filled").help("全屏截图")
            }
            Button { screenshotVM.captureArea() } label: {
                Image(systemName: "rectangle.dashed").help("区域截图")
            }
            Button { screenshotVM.captureWindow() } label: {
                Image(systemName: "macwindow").help("窗口截图")
            }
        }
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundColor(.secondary)
            TextField("搜索...", text: $appState.searchText)
                .textFieldStyle(.plain)
                .frame(width: 180)
            if !appState.searchText.isEmpty {
                Button { appState.searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(6)
        .background(Color(nsColor: .controlBackgroundColor))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var settingsButton: some View {
        Button {
            DispatchQueue.main.async {
                AppDelegate.shared?.openSettings()
            }
        } label: {
            Image(systemName: "gear")
        }
    }

    private func captureButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack {
                Image(systemName: icon).font(.system(size: 28))
                Text(title).font(.caption)
            }
            .frame(width: 100, height: 80)
            .background(Color(nsColor: .controlBackgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
