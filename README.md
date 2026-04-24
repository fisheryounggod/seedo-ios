# SeedoIOS

SeedoIOS 是一款专为 iOS 打造的极简主义时间追踪与专注工具。它是 Seedo 生态系统的一部分，旨在帮助独立开发者和终身学习者精准复盘时间，找回深度专注力。

![Version](https://img.shields.io/badge/version-1.0.0-green.svg)
![Platform](https://img.shields.io/badge/platform-iOS%2017.0+-blue.svg)
![Swift](https://img.shields.io/badge/Swift-5.10-orange.svg)

## 核心设计理念

*   **极致简约**：摒弃繁琐，专注于“开始计时”与“记录成果”的核心流程。
*   **原生质感**：采用 SwiftUI 原生开发，结合现代磨砂玻璃质感（Glassmorphism）与优雅的动效。
*   **无缝同步**：通过日历同步功能，将专注记录转化为直观的时间地图。

## 功能特性

### 1. 灵动的专注计时
*   **双模式切换**：支持经典的 25 分钟番茄钟（倒计时）与灵活的正计时模式。
*   **状态持久化**：计时状态在软件重启、系统内存回收后依然能够精准恢复，计时不中断。
*   **沉浸式体验**：内置模拟机械时钟的 Ticking 音效，增强专注仪式感。

### 2. 现代 iOS 集成
*   **主屏幕快捷操作 (Quick Actions)**：
    *   一键开启 25 分钟专注。
    *   快速进入专注统计查看洞察。
    *   直达设置页面。
    *   **手动补录**：支持直接从桌面启动手动添加记录的表单。
*   **实时活动 (Live Activities)**：在锁屏界面实时显示当前计时进度，无需解锁即可掌握节奏。
*   **智能提醒**：集成通知系统，确保在计时结束时精准提醒。

### 3. 数据分析与洞察
*   **多维度统计**：通过精美的图表直观展示每日、每周的专注时长分布。
*   **专注流视图**：清晰展示每一条历史记录，支持侧滑快速编辑。
*   **手动补录**：支持对遗漏的专注场景进行补录，确保数据完整性。

### 4. 深度系统协同
*   **日历同步**：自动将专注 session 推送至 iOS 系统日历，在日历应用中直观复盘全天安排。
*   **智能路由**：通过 AppDelegate 优化，确保无论 App 是在后台还是彻底关闭，快捷操作都能秒级响应并精准定位功能界面。

## 技术栈

*   **UI 框架**：SwiftUI (利用最新的 .contentTransition 等原生动效)
*   **数据持久化**：SwiftData (新一代 Apple 官方持久化方案)
*   **响应式逻辑**：Combine
*   **系统底层**：ActivityKit (Live Activities), UIApplicationShortcutItems (Quick Actions)

## 安装与运行

1.  克隆仓库：`git clone https://github.com/fisheryounggod/seedo-ios.git`
2.  使用 Xcode 15.3 或更高版本打开 `SeedoIOS.xcodeproj`。
3.  确保已安装 [xcodegen](https://github.com/yonaskolb/XcodeGen)（可选，用于从 `project.yml` 生成项目文件）。
4.  选择您的开发团队（Team）并运行。

---

Developed by [Antigravity](https://github.com/antigravity) & [fisheryounggod](https://github.com/fisheryounggod)
