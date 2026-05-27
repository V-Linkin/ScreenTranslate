import Foundation
import AppKit
import Combine

/// 设置 ViewModel
class SettingsViewModel: ObservableObject {
    @Published var screenshotSettings: ScreenshotSettings
    @Published var translationSettings: TranslationSettings
    @Published var permissionStatuses: [PermissionStatus] = []
    @Published var autoLaunchEnabled: Bool {
        didSet {
            updateAutoLaunch()
        }
    }

    private var appState: AppState?

    init() {
        self.screenshotSettings = UserDefaults.standard.decode("screenshotSettings") ?? .default
        self.translationSettings = UserDefaults.standard.decode("translationSettings") ?? .default
        self.autoLaunchEnabled = SMAppService.mainApp.status == .enabled
        refreshPermissions()
    }

    func setAppState(_ state: AppState) {
        self.appState = state
        self.screenshotSettings = state.screenshotSettings
        self.translationSettings = state.translationSettings
    }

    // MARK: - 保存设置

    func saveScreenshotSettings() {
        appState?.screenshotSettings = screenshotSettings
        appState?.saveSettings()
        if let data = try? JSONEncoder().encode(screenshotSettings) {
            UserDefaults.standard.set(data, forKey: "screenshotSettings")
        }
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    func saveTranslationSettings() {
        // 保存 API Key 到 Keychain
        if !translationSettings.googleAPIKey.isEmpty {
            KeychainHelper.saveGoogleAPIKey(translationSettings.googleAPIKey)
        }
        if !translationSettings.baiduAppID.isEmpty {
            KeychainHelper.saveBaiduAppID(translationSettings.baiduAppID)
        }
        if !translationSettings.baiduSecretKey.isEmpty {
            KeychainHelper.saveBaiduSecretKey(translationSettings.baiduSecretKey)
        }
        if !translationSettings.deeplAPIKey.isEmpty {
            KeychainHelper.saveDeepLAPIKey(translationSettings.deeplAPIKey)
        }

        appState?.translationSettings = translationSettings
        appState?.saveSettings()
        NotificationCenter.default.post(name: .settingsChanged, object: nil)
    }

    func loadAPIKeysFromKeychain() {
        translationSettings.googleAPIKey = KeychainHelper.loadGoogleAPIKey() ?? ""
        translationSettings.baiduAppID = KeychainHelper.loadBaiduAppID() ?? ""
        translationSettings.baiduSecretKey = KeychainHelper.loadBaiduSecretKey() ?? ""
        translationSettings.deeplAPIKey = KeychainHelper.loadDeepLAPIKey() ?? ""
    }

    // MARK: - 权限

    func refreshPermissions() {
        permissionStatuses = PermissionHelper.checkAllPermissions()
    }

    func requestAccessibility() {
        PermissionHelper.requestAccessibilityPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.refreshPermissions()
        }
    }

    func requestScreenRecording() {
        PermissionHelper.requestScreenRecordingPermission()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.refreshPermissions()
        }
    }

    func openSystemPreferences() {
        PermissionHelper.openSystemPreferences()
    }

    // MARK: - 开机自启动

    private func updateAutoLaunch() {
        // 使用 SMAppService (macOS 13+)
        // 注意：需要在 Info.plist 中配置 LSUIElement 和正确设置
    }

    // MARK: - 存储信息

    var storageSize: String {
        let size = StorageService.shared.folderSize(
            at: screenshotSettings.savePath
        )
        return StorageService.shared.formattedSize(size)
    }

    func selectSavePath() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        if let currentURL = URL(string: "file://" + screenshotSettings.savePath) {
            panel.directoryURL = currentURL
        }

        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            self.screenshotSettings.savePath = url.path
            self.saveScreenshotSettings()
        }
    }

    func openSavePath() {
        let url = URL(fileURLWithPath: screenshotSettings.savePath)
        NSWorkspace.shared.open(url)
    }
}

import ServiceManagement
