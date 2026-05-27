import Cocoa
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?
    var statusItem: NSStatusItem!
    private var _settingsWindow: NSWindow?
    private let lock = NSLock()

    /// 线程安全的 settingsWindow 访问
    private var settingsWindow: NSWindow? {
        lock.lock()
        defer { lock.unlock() }
        return _settingsWindow
    }

    private func setSettingsWindow(_ window: NSWindow?) {
        lock.lock()
        defer { lock.unlock() }
        _settingsWindow = window
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        setupStatusBar()
        HotkeyManager.shared.registerAllShortcuts()
        applySavedAppearance()
    }

    private func applySavedAppearance() {
        let mode = UserDefaults.standard.string(forKey: "appearanceMode") ?? "system"
        switch mode {
        case "light":
            NSApp.appearance = NSAppearance(named: .aqua)
        case "dark":
            NSApp.appearance = NSAppearance(named: .darkAqua)
        default:
            NSApp.appearance = nil
        }
    }

    // MARK: - Status Bar

    private func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "text.viewfinder", accessibilityDescription: "ScreenTranslate")
        }

        let menu = NSMenu()
        menu.addItem(NSMenuItem(title: "全屏截图", action: #selector(captureFullScreen), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "区域截图", action: #selector(captureArea), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "窗口截图", action: #selector(captureWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "打开主窗口", action: #selector(openMainWindow), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "设置...", action: #selector(openSettingsFromMenu), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "退出", action: #selector(quitApp), keyEquivalent: "q"))
        statusItem.menu = menu
    }

    // MARK: - Screenshot

    @objc private func captureFullScreen() {
        ScreenshotService.shared.captureFullScreen { [weak self] image in
            guard let image = image else { return }
            self?.handleScreenshot(image)
        }
    }

    @objc private func captureArea() {
        ScreenshotService.shared.captureArea { [weak self] image in
            guard let image = image else { return }
            self?.handleScreenshot(image)
        }
    }

    @objc private func captureWindow() {
        ScreenshotService.shared.captureWindow { [weak self] image in
            guard let image = image else { return }
            self?.handleScreenshot(image)
        }
    }

    // MARK: - Windows

    @objc private func openMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let window = NSApp.windows.first(where: { $0.isKeyWindow && $0 !== self.settingsWindow }) {
            window.makeKeyAndOrderFront(nil)
        }
    }

    @objc private func openSettingsFromMenu() {
        openSettings()
    }

    func openSettings() {
        // 确保在主线程执行所有 UI 操作
        guard Thread.isMainThread else {
            DispatchQueue.main.async { [weak self] in
                self?.openSettings()
            }
            return
        }

        if let window = settingsWindow, window.isVisible {
            window.makeKeyAndOrderFront(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        let appState = AppState.shared ?? AppState()

        let settingsVM = SettingsViewModel()
        settingsVM.setAppState(appState)

        let hostingView = NSHostingView(
            rootView: SettingsContainerView(settingsVM: settingsVM)
                .environmentObject(appState)
        )

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 440),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "ScreenTranslate 设置"
        window.contentView = hostingView
        window.center()
        window.makeKeyAndOrderFront(nil)
        setSettingsWindow(window)
    }

    @objc private func quitApp() {
        NSApplication.shared.terminate(nil)
    }

    // MARK: - Screenshot Handling

    func handleScreenshot(_ image: NSImage) {
        NSPasteboard.general.clearContents()
        if let tiffData = image.tiffRepresentation {
            NSPasteboard.general.setData(tiffData, forType: .tiff)
        }

        let screenshot = ScreenshotItem(id: UUID(), image: image, timestamp: Date())
        NotificationCenter.default.post(name: .screenshotCaptured, object: screenshot)

        DispatchQueue.main.async {
            ScreenshotActionService.shared.show(image: image)
        }
    }
}
