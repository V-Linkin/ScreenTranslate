# ScreenTranslate

macOS 原生截图翻译应用 — 集截图、OCR 识别、翻译、图片管理、桌面置顶于一体的效率工具。

## 技术栈

- **语言**：Swift 5.9
- **UI**：SwiftUI
- **架构**：MVVM
- **最低系统**：macOS 13.0 (Ventura)
- **依赖**：纯 Apple 原生框架，无第三方依赖

## 核心功能

### 1. 截图功能
- **全屏截图**：截取整个屏幕
- **区域截图**：用户自由框选区域（`screencapture -i`）
- **窗口截图**：截取指定窗口（`screencapture -w`）
- **快捷键**：支持自定义全局快捷键（Carbon API 注册）
  - 默认：区域 `Cmd+Shift+T`、全屏 `Cmd+Shift+3`、窗口 `Cmd+Shift+4`

### 2. OCR + 翻译
- **OCR 识别**：使用 Vision Framework (`VNRecognizeTextRequest`)
- **翻译引擎**：支持 4 种
  - Apple 翻译（免费，使用 Google 免费接口）
  - Google Translate（需 API Key）
  - 百度翻译（需 App ID + Secret Key）
  - DeepL 翻译（需 API Key）
- **截图后操作窗口**：截图完成后弹出浮动窗口，用户点击「识别并翻译」按钮触发 OCR + 翻译
- **自动翻译**：OCR 完成后自动翻译（可在设置中开关）

### 3. 置顶显示
- 截图 + OCR 文字 + 翻译结果一起置顶显示
- 支持拖动、调节透明度
- 双击复制译文
- 右键菜单：复制译文/原文/图片、关闭

### 4. 图片管理
- 截图列表（列表/网格视图）
- 搜索功能（按内容搜索）
- 右键菜单：复制、编辑、在 Finder 中显示、删除

### 5. 设置
- **常规**：开机自启动、自动翻译、复制到剪贴板、存储路径
- **快捷键**：自定义全局快捷键，支持启用/禁用
- **翻译**：选择翻译引擎、配置 API Key、选择源语言/目标语言
- **外观**：深色/浅色/跟随系统主题
- **权限**：辅助功能、屏幕录制权限状态查看

### 6. 系统集成
- 菜单栏常驻图标
- 剪贴板集成（截图后自动复制）
- 截图操作窗口（截图后弹出，提供 OCR+翻译 按钮）

## 项目结构

```
ScreenTranslate/
├── App/
│   ├── ScreenTranslateApp.swift    # App 入口
│   ├── AppDelegate.swift           # 菜单栏、窗口管理、截图处理
│   └── Info.plist
├── Models/
│   ├── Tag.swift                   # 设置模型 + AppState
│   ├── Screenshot.swift            # 截图数据模型
│   └── Translation.swift           # 翻译引擎/语言枚举
├── ViewModels/
│   ├── ScreenshotViewModel.swift   # 截图 ViewModel
│   ├── TranslationViewModel.swift  # 翻译 ViewModel
│   └── SettingsViewModel.swift     # 设置 ViewModel
├── Views/
│   ├── Main/
│   │   ├── ContentView.swift       # 主界面（侧边栏 + 详情）
│   │   ├── ScreenshotListView.swift
│   │   └── ScreenshotDetailView.swift
│   ├── Editor/
│   │   ├── EditorView.swift
│   │   └── ToolbarView.swift
│   ├── Settings/
│   │   └── SettingsView.swift      # 设置界面（含所有子页面）
│   ├── Floating/
│   │   └── FloatingWindowView.swift # 置顶窗口 + 截图操作窗口
│   └── Components/
│       ├── ScreenshotThumbnail.swift
│       └── TranslationResultView.swift
├── Services/
│   ├── ScreenshotService.swift     # 截图服务（screencapture）
│   ├── OCRService.swift            # OCR 服务（Vision Framework）
│   ├── TranslationService.swift    # 翻译服务（多引擎）
│   ├── StorageService.swift        # 存储服务
│   └── HotkeyManager.swift         # 全局快捷键（Carbon API）
├── Utilities/
│   ├── KeychainHelper.swift        # Keychain 存储
│   ├── PermissionHelper.swift      # 权限检查
│   └── Extensions.swift            # 扩展
├── Resources/
│   └── Assets.xcassets/            # 资源（含 App Icon）
├── project.yml                     # XcodeGen 配置
└── ScreenTranslate.xcodeproj
```

## 构建

```bash
# 需要安装 xcodegen
brew install xcodegen

# 生成 Xcode 项目
cd ScreenTranslate
xcodegen generate

# 用 Xcode 打开
open -a Xcode ScreenTranslate.xcodeproj
# Cmd+B 编译，Cmd+R 运行
```

编译后 app 会自动复制到 `/Applications/ScreenTranslate.app`（通过 post-build script）。

## 已知问题

### 🔴 严重问题

1. **区域截图（`screencapture -i`）在 macOS 26 上不工作**
   - 从 app 子进程调用 `screencapture -i` 时，松开鼠标后无反应
   - 可能原因：子进程没有继承屏幕录制权限，或 macOS 26 对 screencapture 有新限制
   - 全屏截图和窗口截图正常
   - **建议方案**：改用 ScreenCaptureKit 框架，或实现应用内裁剪（先全屏截图，再让用户框选区域）

2. **OCR 识别不工作**
   - `VNRecognizeTextRequest` 可能无法识别文字
   - 可能原因：CGImage 转换问题、Vision Framework 在 macOS 26 上的兼容性问题、或图片格式不支持
   - 已添加详细日志（`[OCR]` 前缀），可通过控制台.app 查看
   - **建议排查**：检查控制台日志中 `[OCR]` 开头的输出，确认 CGImage 是否成功获取

### 🟡 中等问题

3. **屏幕录制权限弹窗反复出现**
   - 从 Xcode 运行（DerivedData 路径）时，macOS 每次可能视为新 app
   - 已配置 post-build script 自动复制到 `/Applications/`
   - 仍需手动在 系统设置 → 隐私与安全性 → 屏幕录制 中添加 `/Applications/ScreenTranslate.app`
   - **必须从 `/Applications/` 或启动台打开**，不能从 Xcode Run

4. **设置窗口排版在 macOS 26 上异常**
   - SwiftUI 的 `Settings` 场景在 macOS 26 上标签栏显示在顶部而非底部
   - 已改用原生 `NSWindow` + 自定义底部标签栏
   - 但标签栏点击区域和样式可能仍需优化

### 🟢 轻微问题

5. **Xcode "Update to recommended settings" 警告**
   - 已在 project.yml 中添加所有推荐设置，重新生成项目后应消失

6. **截图编辑功能未实现**
   - EditorView.swift 和 ToolbarView.swift 已创建但功能未完善
   - 标注、马赛克、裁剪等功能待开发

7. **翻译历史功能不完整**
   - TranslationHistoryView 存在但与侧边栏的集成可能有问题

## 下次继续时的建议

1. **优先解决区域截图**：考虑用 ScreenCaptureKit 替代 screencapture 子进程
2. **优先解决 OCR**：检查 Vision Framework 在 macOS 26 上的行为，可能需要调整 `VNRecognizeTextRequest` 配置
3. **查看日志**：运行 app 后打开控制台.app，搜索 `ScreenTranslate`，查看 `[Screenshot]` 和 `[OCR]` 日志
4. **测试环境**：macOS 26.4.1, Xcode 15+, Swift 5.9

## 权限要求

- **辅助功能权限**：截取屏幕内容
- **屏幕录制权限**：OCR 识别（Vision Framework 需要）
- **文件访问权限**：保存截图到本地

## License

MIT
