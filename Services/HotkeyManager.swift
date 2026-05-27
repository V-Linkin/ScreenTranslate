import Cocoa
import Carbon.HIToolbox

/// 全局快捷键管理器
/// 使用 Carbon API 注册全局快捷键，确保在任何应用前台时都能响应
class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotkeyRefs: [String: EventHotKeyRef] = [:]
    fileprivate var hotkeyActions: [UInt32: () -> Void] = [:]
    private var hotkeyIDCounter: UInt32 = 1
    private var eventHandlerInstalled = false

    private init() {}

    // MARK: - 公开接口

    /// 注册所有已保存的快捷键
    func registerAllShortcuts() {
        unregisterAll()

        guard let saved = UserDefaults.standard.array(forKey: "shortcuts") as? [[String: Any]] else {
            registerDefaults()
            return
        }

        for item in saved {
            guard let action = item["action"] as? String,
                  let key = item["key"] as? String,
                  let isEnabled = item["isEnabled"] as? Bool,
                  isEnabled else { continue }

            registerShortcut(keyCombo: key, action: action)
        }
    }

    /// 注册默认快捷键
    func registerDefaults() {
        registerShortcut(keyCombo: "Cmd+Shift+T", action: "captureArea")
        registerShortcut(keyCombo: "Cmd+Shift+3", action: "captureFullScreen")
        registerShortcut(keyCombo: "Cmd+Shift+4", action: "captureWindow")
    }

    /// 注销所有快捷键
    func unregisterAll() {
        for (_, ref) in hotkeyRefs {
            UnregisterEventHotKey(ref)
        }
        hotkeyRefs.removeAll()
        hotkeyActions.removeAll()
        hotkeyIDCounter = 1
    }

    /// 注册单个快捷键
    func registerShortcut(keyCombo: String, action: String) {
        guard let (modifiers, keyCode) = parseKeyCombo(keyCombo) else { return }

        let currentID = hotkeyIDCounter
        hotkeyIDCounter += 1

        var hotkeyID = EventHotKeyID()
        hotkeyID.signature = OSType(0x5354_524E) // 'STRN'
        hotkeyID.id = currentID

        var ref: EventHotKeyRef?
        let status = RegisterEventHotKey(
            keyCode,
            modifiers,
            hotkeyID,
            GetEventDispatcherTarget(),
            0,
            &ref
        )

        guard status == noErr, let ref = ref else { return }

        hotkeyRefs[action] = ref
        hotkeyActions[currentID] = { [weak self] in
            self?.handleHotkeyAction(action)
        }

        // 安装事件处理器（只安装一次）
        if !eventHandlerInstalled {
            var eventType = EventTypeSpec(
                eventClass: OSType(kEventClassKeyboard),
                eventKind: UInt32(kEventHotKeyPressed)
            )
            InstallEventHandler(
                GetEventDispatcherTarget(),
                hotkeyCallback,
                1,
                &eventType,
                Unmanaged.passUnretained(self).toOpaque(),
                nil
            )
            eventHandlerInstalled = true
        }
    }

    // MARK: - 快捷键字符串解析

    private func parseKeyCombo(_ combo: String) -> (UInt32, UInt32)? {
        var modifiers: UInt32 = 0
        var keyString = combo

        let modifierMap: [(String, UInt32)] = [
            ("Cmd+", UInt32(cmdKey)),
            ("Ctrl+", UInt32(controlKey)),
            ("Option+", UInt32(optionKey)),
            ("Shift+", UInt32(shiftKey)),
        ]

        for (prefix, flag) in modifierMap {
            if keyString.hasPrefix(prefix) {
                modifiers |= flag
                keyString = String(keyString.dropFirst(prefix.count))
            }
        }

        guard let keyCode = mapKeyStringToKeyCode(keyString) else { return nil }
        return (modifiers, keyCode)
    }

    private func mapKeyStringToKeyCode(_ key: String) -> UInt32? {
        let keyMap: [String: UInt32] = [
            "A": UInt32(kVK_ANSI_A), "B": UInt32(kVK_ANSI_B), "C": UInt32(kVK_ANSI_C),
            "D": UInt32(kVK_ANSI_D), "E": UInt32(kVK_ANSI_E), "F": UInt32(kVK_ANSI_F),
            "G": UInt32(kVK_ANSI_G), "H": UInt32(kVK_ANSI_H), "I": UInt32(kVK_ANSI_I),
            "J": UInt32(kVK_ANSI_J), "K": UInt32(kVK_ANSI_K), "L": UInt32(kVK_ANSI_L),
            "M": UInt32(kVK_ANSI_M), "N": UInt32(kVK_ANSI_N), "O": UInt32(kVK_ANSI_O),
            "P": UInt32(kVK_ANSI_P), "Q": UInt32(kVK_ANSI_Q), "R": UInt32(kVK_ANSI_R),
            "S": UInt32(kVK_ANSI_S), "T": UInt32(kVK_ANSI_T), "U": UInt32(kVK_ANSI_U),
            "V": UInt32(kVK_ANSI_V), "W": UInt32(kVK_ANSI_W), "X": UInt32(kVK_ANSI_X),
            "Y": UInt32(kVK_ANSI_Y), "Z": UInt32(kVK_ANSI_Z),
            "0": UInt32(kVK_ANSI_0), "1": UInt32(kVK_ANSI_1), "2": UInt32(kVK_ANSI_2),
            "3": UInt32(kVK_ANSI_3), "4": UInt32(kVK_ANSI_4), "5": UInt32(kVK_ANSI_5),
            "6": UInt32(kVK_ANSI_6), "7": UInt32(kVK_ANSI_7), "8": UInt32(kVK_ANSI_8),
            "9": UInt32(kVK_ANSI_9),
            "Space": UInt32(kVK_Space), "Return": UInt32(kVK_Return),
            "Delete": UInt32(kVK_Delete), "Escape": UInt32(kVK_Escape),
            "Tab": UInt32(kVK_Tab),
            "←": UInt32(kVK_LeftArrow), "→": UInt32(kVK_RightArrow),
            "↓": UInt32(kVK_DownArrow), "↑": UInt32(kVK_UpArrow),
        ]
        return keyMap[key]
    }

    // MARK: - 动作处理

    fileprivate func handleHotkeyAction(_ action: String) {
        DispatchQueue.main.async {
            switch action {
            case "captureArea":
                ScreenshotService.shared.captureArea { image in
                    guard let image = image else { return }
                    AppDelegate.shared?.handleScreenshot(image)
                }
            case "captureFullScreen":
                ScreenshotService.shared.captureFullScreen { image in
                    guard let image = image else { return }
                    AppDelegate.shared?.handleScreenshot(image)
                }
            case "captureWindow":
                ScreenshotService.shared.captureWindow { image in
                    guard let image = image else { return }
                    AppDelegate.shared?.handleScreenshot(image)
                }
            default:
                break
            }
        }
    }
}

// MARK: - Carbon 事件回调

private func hotkeyCallback(
    nextHandler: EventHandlerCallRef?,
    event: EventRef?,
    userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let event = event, let userData = userData else { return OSStatus(eventNotHandledErr) }

    var hotkeyID = EventHotKeyID()
    GetEventParameter(
        event,
        EventParamName(kEventParamDirectObject),
        EventParamType(typeEventHotKeyID),
        nil,
        MemoryLayout<EventHotKeyID>.size,
        nil,
        &hotkeyID
    )

    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    if let action = manager.hotkeyActions[hotkeyID.id] {
        action()
    }

    return noErr
}
