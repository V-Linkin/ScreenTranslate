import Cocoa
import UserNotifications
import AVFoundation

/// 权限管理助手
class PermissionHelper {

    // MARK: - 辅助功能权限

    static var isAccessibilityEnabled: Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibilityPermission() {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true
        ]
        AXIsProcessTrustedWithOptions(options as CFDictionary)
    }

    // MARK: - 屏幕录制权限

    static var isScreenRecordingEnabled: Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenRecordingPermission() {
        CGRequestScreenCaptureAccess()
    }

    // MARK: - 文件访问权限

    static func requestFileAccess(to path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        return FileManager.default.isReadableFile(atPath: path) ||
               url.startAccessingSecurityScopedResource()
    }

    // MARK: - 通知权限

    static func requestNotificationPermission() {
        let center = UNUserNotificationCenter.current()
        center.requestAuthorization(options: [.alert, .sound]) { granted, error in
            if let error = error {
                print("通知权限请求失败: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - 权限检查

    static func checkAllPermissions() -> [PermissionStatus] {
        [
            PermissionStatus(
                name: "辅助功能",
                isEnabled: isAccessibilityEnabled,
                description: "用于截取屏幕内容"
            ),
            PermissionStatus(
                name: "屏幕录制",
                isEnabled: isScreenRecordingEnabled,
                description: "用于 OCR 文字识别"
            ),
        ]
    }

    static func openSystemPreferences() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy") {
            NSWorkspace.shared.open(url)
        }
    }

    static func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }
}

struct PermissionStatus {
    let name: String
    let isEnabled: Bool
    let description: String
}
