import SwiftUI

// MARK: - 设置容器（自定义底部标签栏）

/// 设置容器 - 使用底部标签栏，符合 macOS 标准设置样式
struct SettingsContainerView: View {
    @ObservedObject var settingsVM: SettingsViewModel
    @State private var selectedTab = 0

    private let tabs: [(String, String)] = [
        ("常规", "gear"),
        ("快捷键", "command"),
        ("翻译", "globe"),
        ("外观", "paintbrush"),
        ("权限", "lock.shield"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 内容区域
            Group {
                switch selectedTab {
                case 0: GeneralSettingsView(settingsVM: settingsVM)
                case 1: ShortcutSettingsView()
                case 2: TranslationSettingsView(settingsVM: settingsVM)
                case 3: AppearanceSettingsView()
                case 4: PermissionSettingsView(settingsVM: settingsVM)
                default: GeneralSettingsView(settingsVM: settingsVM)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            Divider()

            // 底部标签栏
            HStack(spacing: 0) {
                ForEach(Array(tabs.enumerated()), id: \.offset) { index, tab in
                    Button(action: { selectedTab = index }) {
                        VStack(spacing: 3) {
                            Image(systemName: tab.1)
                                .font(.system(size: 16))
                            Text(tab.0)
                                .font(.system(size: 10))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                        .foregroundColor(selectedTab == index ? .accentColor : .secondary)
                        .background(selectedTab == index ?
                            Color.accentColor.opacity(0.1) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(height: 52)
            .background(Color(nsColor: .controlBackgroundColor))
        }
    }
}

// MARK: - 常规设置

struct GeneralSettingsView: View {
    @ObservedObject var settingsVM: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("基本设置") {
                    VStack(alignment: .leading, spacing: 10) {
                        Toggle("开机自启动", isOn: $settingsVM.autoLaunchEnabled)
                        Toggle("OCR 后自动翻译", isOn: $settingsVM.screenshotSettings.autoTranslate)
                            .onChange(of: settingsVM.screenshotSettings.autoTranslate) { _ in
                                settingsVM.saveScreenshotSettings()
                            }
                        Toggle("截图后复制到剪贴板", isOn: $settingsVM.screenshotSettings.copyToClipboard)
                            .onChange(of: settingsVM.screenshotSettings.copyToClipboard) { _ in
                                settingsVM.saveScreenshotSettings()
                            }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("存储设置") {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("保存位置")
                                .frame(width: 70, alignment: .leading)
                            Text(settingsVM.screenshotSettings.savePath)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                            Spacer()
                            Button("选择...") { settingsVM.selectSavePath() }
                            Button("打开") { settingsVM.openSavePath() }
                        }
                        HStack {
                            Text("默认格式")
                                .frame(width: 70, alignment: .leading)
                            Picker("", selection: $settingsVM.screenshotSettings.defaultFormat) {
                                ForEach(ScreenshotSettings.ImageFormat.allCases, id: \.self) { format in
                                    Text(format.rawValue).tag(format)
                                }
                            }
                            .pickerStyle(.segmented)
                            .frame(width: 120)
                            .onChange(of: settingsVM.screenshotSettings.defaultFormat) { _ in
                                settingsVM.saveScreenshotSettings()
                            }
                            Spacer()
                        }
                        HStack {
                            Text("已用空间")
                                .frame(width: 70, alignment: .leading)
                            Spacer()
                            Text(settingsVM.storageSize)
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                HStack {
                    Spacer()
                    Button("退出 ScreenTranslate") {
                        NSApplication.shared.terminate(nil)
                    }
                    .foregroundColor(.red)
                    Spacer()
                }
            }
            .padding(16)
        }
    }
}

// MARK: - 快捷键设置

struct ShortcutSettingsView: View {
    @State private var shortcuts: [ShortcutItem] = [
        ShortcutItem(name: "区域截图", key: "Cmd+Shift+T", action: "captureArea"),
        ShortcutItem(name: "全屏截图", key: "Cmd+Shift+3", action: "captureFullScreen"),
        ShortcutItem(name: "窗口截图", key: "Cmd+Shift+4", action: "captureWindow"),
    ]
    @State private var recordingIndex: Int?
    @State private var eventMonitor: Any?
    @State private var globalEventMonitor: Any?

    struct ShortcutItem: Identifiable {
        let id = UUID()
        let name: String
        var key: String
        let action: String
        var isEnabled: Bool = true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("全局快捷键") {
                    VStack(spacing: 0) {
                        HStack {
                            Text("功能").frame(width: 80, alignment: .leading)
                            Spacer()
                            Text("快捷键").frame(width: 180, alignment: .center)
                            Spacer()
                            Text("启用").frame(width: 50, alignment: .center)
                            Spacer().frame(width: 70)
                        }
                        .font(.caption).foregroundColor(.secondary)
                        .padding(.horizontal, 12).padding(.vertical, 8)
                        .background(Color(nsColor: .controlBackgroundColor))

                        Divider()

                        ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, shortcut in
                            HStack {
                                Text(shortcut.name)
                                    .frame(width: 80, alignment: .leading)
                                    .foregroundColor(shortcut.isEnabled ? .primary : .secondary)
                                Spacer()

                                if recordingIndex == index {
                                    HStack(spacing: 6) {
                                        Image(systemName: "record.circle").foregroundColor(.red)
                                        Text("请按下快捷键...").font(.system(.body, design: .monospaced)).foregroundColor(.red)
                                    }
                                    .frame(width: 180, alignment: .center)
                                    .padding(.vertical, 6).padding(.horizontal, 10)
                                    .background(Color.red.opacity(0.08))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    Text(shortcut.isEnabled ? shortcut.key : "—")
                                        .font(.system(.body, design: .monospaced))
                                        .foregroundColor(shortcut.isEnabled ? .primary : .secondary)
                                        .frame(width: 180, alignment: .center)
                                        .padding(.vertical, 6).padding(.horizontal, 10)
                                        .background(shortcut.isEnabled ? Color(nsColor: .controlBackgroundColor) : Color(nsColor: .controlBackgroundColor).opacity(0.5))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                Spacer()

                                Toggle("", isOn: Binding(
                                    get: { shortcuts[index].isEnabled },
                                    set: { newValue in shortcuts[index].isEnabled = newValue; saveAndRegister() }
                                ))
                                .toggleStyle(.switch).labelsHidden().frame(width: 50, alignment: .center)

                                Button(recordingIndex == index ? "取消" : "录制") {
                                    if recordingIndex == nil { startRecording(index: index) } else { stopRecording() }
                                }
                                .disabled(!shortcut.isEnabled).frame(width: 60)
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            if index < shortcuts.count - 1 { Divider().padding(.horizontal, 12) }
                        }
                    }
                    .padding(.vertical, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Text("快捷键不能与系统快捷键冲突，修改后自动保存并生效")
                    .font(.caption).foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(16)
        }
        .onAppear { loadShortcuts() }
        .onDisappear { stopRecording() }
    }

    private func startRecording(index: Int) {
        recordingIndex = index
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in self.handleKeyEvent(event, index: index); return nil }
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in self.handleKeyEvent(event, index: index) }
    }

    private func handleKeyEvent(_ event: NSEvent, index: Int) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let key = event.charactersIgnoringModifiers ?? ""
        if modifiers.isEmpty || key.isEmpty { return }
        if [.command, .control, .option, .shift].contains(where: { modifiers == $0 }) { return }

        var keyCombo = ""
        if modifiers.contains(.control) { keyCombo += "Ctrl+" }
        if modifiers.contains(.option) { keyCombo += "Option+" }
        if modifiers.contains(.shift) { keyCombo += "Shift+" }
        if modifiers.contains(.command) { keyCombo += "Cmd+" }
        keyCombo += mapKeyCode(event.keyCode, character: key)

        DispatchQueue.main.async { self.shortcuts[index].key = keyCombo; self.stopRecording(); self.saveAndRegister() }
    }

    private func mapKeyCode(_ keyCode: UInt16, character: String) -> String {
        switch keyCode {
        case 36: return "Return"; case 49: return "Space"; case 51: return "Delete"
        case 53: return "Escape"; case 48: return "Tab"
        case 123: return "←"; case 124: return "→"; case 125: return "↓"; case 126: return "↑"
        default: return character.uppercased()
        }
    }

    private func stopRecording() {
        recordingIndex = nil
        if let m = eventMonitor { NSEvent.removeMonitor(m); eventMonitor = nil }
        if let m = globalEventMonitor { NSEvent.removeMonitor(m); globalEventMonitor = nil }
    }

    private func saveAndRegister() {
        let data: [[String: Any]] = shortcuts.map { ["name": $0.name, "key": $0.key, "action": $0.action, "isEnabled": $0.isEnabled] }
        UserDefaults.standard.set(data, forKey: "shortcuts")
        HotkeyManager.shared.registerAllShortcuts()
    }

    private func loadShortcuts() {
        guard let saved = UserDefaults.standard.array(forKey: "shortcuts") as? [[String: Any]] else { return }
        for (i, item) in saved.enumerated() where i < shortcuts.count {
            if let key = item["key"] as? String { shortcuts[i].key = key }
            if let enabled = item["isEnabled"] as? Bool { shortcuts[i].isEnabled = enabled }
        }
    }
}

// MARK: - 翻译设置

struct TranslationSettingsView: View {
    @ObservedObject var settingsVM: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("翻译引擎") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("默认引擎", selection: $settingsVM.translationSettings.engine) {
                            ForEach(TranslationEngine.allCases) { engine in
                                HStack { Image(systemName: engine.icon); Text(engine.displayName) }.tag(engine)
                            }
                        }
                        .onChange(of: settingsVM.translationSettings.engine) { _ in settingsVM.saveTranslationSettings() }
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("语言设置") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("默认源语言", selection: $settingsVM.translationSettings.sourceLanguage) {
                            ForEach(TranslationLanguage.allCases) { lang in Text(lang.displayName).tag(lang) }
                        }
                        .onChange(of: settingsVM.translationSettings.sourceLanguage) { _ in settingsVM.saveTranslationSettings() }
                        Picker("默认目标语言", selection: $settingsVM.translationSettings.targetLanguage) {
                            ForEach(TranslationLanguage.allCases.filter { $0 != .auto }) { lang in Text(lang.displayName).tag(lang) }
                        }
                        .onChange(of: settingsVM.translationSettings.targetLanguage) { _ in settingsVM.saveTranslationSettings() }
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("API 配置") {
                    engineConfigView.padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }

    @ViewBuilder
    private var engineConfigView: some View {
        switch settingsVM.translationSettings.engine {
        case .apple:
            HStack { Image(systemName: "info.circle").foregroundColor(.blue)
                Text("Apple 翻译使用系统免费接口，无需配置 API Key").font(.callout).foregroundColor(.secondary) }
        case .google:
            VStack(alignment: .leading, spacing: 10) {
                Label("Google Translate API", systemImage: "globe").font(.subheadline).fontWeight(.medium)
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key").font(.caption).foregroundColor(.secondary)
                    SecureField("输入 Google API Key", text: $settingsVM.translationSettings.googleAPIKey).textFieldStyle(.roundedBorder)
                }
            }
        case .baidu:
            VStack(alignment: .leading, spacing: 10) {
                Label("百度翻译 API", systemImage: "character.bubble").font(.subheadline).fontWeight(.medium)
                VStack(alignment: .leading, spacing: 4) {
                    Text("App ID").font(.caption).foregroundColor(.secondary)
                    TextField("输入百度 App ID", text: $settingsVM.translationSettings.baiduAppID).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Secret Key").font(.caption).foregroundColor(.secondary)
                    SecureField("输入百度 Secret Key", text: $settingsVM.translationSettings.baiduSecretKey).textFieldStyle(.roundedBorder)
                }
            }
        case .deepl:
            VStack(alignment: .leading, spacing: 10) {
                Label("DeepL API", systemImage: "text.bubble").font(.subheadline).fontWeight(.medium)
                VStack(alignment: .leading, spacing: 4) {
                    Text("API Key").font(.caption).foregroundColor(.secondary)
                    SecureField("输入 DeepL API Key", text: $settingsVM.translationSettings.deeplAPIKey).textFieldStyle(.roundedBorder)
                }
            }
        }
    }
}

// MARK: - 外观设置

struct AppearanceSettingsView: View {
    @AppStorage("appearanceMode") private var appearanceMode = "system"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("主题") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("外观模式", selection: $appearanceMode) {
                            Text("浅色").tag("light")
                            Text("深色").tag("dark")
                            Text("跟随系统").tag("system")
                        }
                        .pickerStyle(.segmented)
                        .onChange(of: appearanceMode) { _ in applyAppearance() }
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("语言") {
                    VStack(alignment: .leading, spacing: 10) {
                        Picker("界面语言", selection: .constant("zh")) {
                            Text("简体中文").tag("zh")
                            Text("English").tag("en")
                        }
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
        .onAppear { applyAppearance() }
    }

    private func applyAppearance() {
        switch appearanceMode {
        case "light": NSApp.appearance = NSAppearance(named: .aqua)
        case "dark": NSApp.appearance = NSAppearance(named: .darkAqua)
        default: NSApp.appearance = nil
        }
    }
}

// MARK: - 权限设置

struct PermissionSettingsView: View {
    @ObservedObject var settingsVM: SettingsViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                GroupBox("应用权限") {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(settingsVM.permissionStatuses, id: \.name) { status in
                            HStack {
                                VStack(alignment: .leading) {
                                    Text(status.name).fontWeight(.medium)
                                    Text(status.description).font(.caption).foregroundColor(.secondary)
                                }
                                Spacer()
                                if status.isEnabled {
                                    Label("已启用", systemImage: "checkmark.circle.fill").foregroundColor(.green)
                                } else {
                                    Label("未启用", systemImage: "xmark.circle.fill").foregroundColor(.red)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }

                GroupBox("操作") {
                    VStack(alignment: .leading, spacing: 10) {
                        Button("请求辅助功能权限") { settingsVM.requestAccessibility() }
                        Button("请求屏幕录制权限") { settingsVM.requestScreenRecording() }
                        Button("打开系统偏好设置") { settingsVM.openSystemPreferences() }
                        Divider()
                        Button("刷新权限状态") { settingsVM.refreshPermissions() }
                    }
                    .padding(.vertical, 8).frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(16)
        }
    }
}
