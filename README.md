<p align="center">
  <img src="./docs/assets/app-icon.png" width="112" alt="NotchNotes 应用图标">
</p>

<h1 align="center">NotchNotes</h1>

<p align="center">
  一个住在 Mac 屏幕顶部的轻量文件暂存架。<br>
  在 Finder 窗口、其他应用和网页之间搬运文件，并用一枚咖啡杯替代手动运行 <code>caffeinate -di</code>。
</p>

<p align="center">
  <a href="https://github.com/zhoulinhua0-star/NotchNotes/releases/latest/download/NotchNotes.zip"><strong>下载最新版</strong></a>
  ·
  <a href="#本地构建">本地构建</a>
  ·
  <a href="https://github.com/oil-oil/NotchNotes">上游项目</a>
</p>

<p align="center">
  <a href="https://github.com/zhoulinhua0-star/NotchNotes/actions/workflows/release.yml"><img src="https://github.com/zhoulinhua0-star/NotchNotes/actions/workflows/release.yml/badge.svg" alt="构建状态"></a>
  <img src="https://img.shields.io/badge/macOS-14%2B-000000?logo=apple&logoColor=white" alt="支持 macOS 14 或更高版本">
  <img src="https://img.shields.io/badge/Swift-6-F05138?logo=swift&logoColor=white" alt="使用 Swift 6">
  <img src="https://img.shields.io/badge/架构-Apple%20Silicon%20%2B%20Intel-6E6E73" alt="支持 Apple Silicon 和 Intel">
</p>

## 这个 fork 做了什么

这个版本将 [oil-oil/NotchNotes](https://github.com/oil-oil/NotchNotes) 聚焦为三个功能：

- **File Shelf**：临时收纳文件和文件夹，再拖到 Finder、其他应用或网页上传区。
- **Click / Hover**：按自己的 Mac 选择点击或悬停打开顶部 Shelf。
- **Keep Awake**：一键保持显示器与 Mac 唤醒，不再需要单独打开 Terminal。

Markdown 笔记界面目前不参与构建。旧版本保存在本机的笔记和内嵌图片不会被主动删除，但这个 fork 不会加载或显示它们。

## File Shelf

- 直接把文件或文件夹拖进屏幕顶部，也可以点击 `Add Files` 或按 <kbd>⌘</kbd> + <kbd>O</kbd>。
- Shelf 只保存路径引用，不复制、移动或删除原文件；清空 Shelf 也不会删除磁盘内容。
- 同一个文件可以在不同次操作中重复加入，每一项都能独立选择、拖出或移除。
- 单击选择；按住 <kbd>⌘</kbd> 或 <kbd>Shift</kbd> 可追加选择，也支持在空白处拖框多选。
- 单击空白区域即可取消选择；选中后可按 <kbd>Delete</kbd> 移除。
- 鼠标悬停在文件卡片上会直接显示右上角 `×`，即使 NotchNotes 当前不在前台。
- 双击打开文件；右键可打开、在 Finder 中显示或从 Shelf 移除。
- 暂存记录保存在本机，最多保留 100 项。

## Click / Hover

从 Shelf 右上角的齿轮，或菜单栏的 NotchNotes 图标中选择 `Open Shelf With`：

- **Hover**：将鼠标移到屏幕顶部中央即可展开。触发区经过加宽，并使用更顺滑的 60 Hz 指针检测和延迟收起。
- **Click**：单击屏幕顶部中央展开，适合没有实体刘海的 Mac 或偏好明确点击的用户。

首次运行时，有实体刘海的 Mac 默认使用 Hover；没有实体刘海的 Mac 默认使用 Click。之后的选择会保存在本机。

## Keep Awake

点击 Shelf 右上角的咖啡杯，或从菜单栏启用 `Keep Mac Awake`。应用会启动：

```bash
/usr/bin/caffeinate -di -w <NotchNotes PID>
```

它与手动执行 `caffeinate -di` 的基础效果一致：防止显示器休眠，并防止空闲导致的系统休眠。关闭该开关或退出 NotchNotes 后，唤醒保持会结束。

这个模式不需要管理员权限，也不修改系统睡眠设置；它**不支持合盖保持运行**，也不能覆盖 macOS 或硬件强制执行的睡眠行为。

## 下载、安装与日常启动

1. [下载最新版 `NotchNotes.zip`](https://github.com/zhoulinhua0-star/NotchNotes/releases/latest/download/NotchNotes.zip)。
2. 解压后将 `NotchNotes.app` 拖入“应用程序”。
3. 首次启动时右键点击应用并选择“打开”。
4. 如果 macOS 仍然拦截，请前往“系统设置 → 隐私与安全性”，点击“仍要打开”。

公开构建使用临时签名，尚未经过 Apple 公证，因此首次启动可能出现安全提示。正式免提示分发需要 Developer ID Application 证书和 Apple 公证。

安装到“应用程序”后，不再需要通过构建目录启动。日常可以在 Spotlight 或 Finder 的“应用程序”中打开；Terminal 用户也可以使用：

```bash
open -a NotchNotes
```

NotchNotes 是菜单栏应用，运行后通常不会显示 Dock 图标。若希望登录 Mac 后自动运行，请前往“系统设置 → 通用 → 登录项与扩展 → 登录时打开”，点击 `+` 并选择 `NotchNotes.app`。

目前应用不包含自动更新器。安装新版本前先退出 NotchNotes，再将新版拖入“应用程序”并选择“替换”；正常替换不会清除 Shelf 内容或 Click / Hover 设置。

## 本地构建

需要 macOS 14 或更高版本，以及支持 Swift 6 的 Xcode / Command Line Tools。

```bash
git clone git@github.com:zhoulinhua0-star/NotchNotes.git
cd NotchNotes
swift test
./Scripts/package-app.sh
open dist.noindex
```

最后一条命令会在 Finder 中打开构建结果。将 `NotchNotes.app` 拖入“应用程序”即可长期使用；如果只是临时测试，也可以直接运行：

```bash
open dist.noindex/NotchNotes.app
```

打包脚本会生成：

- `dist.noindex/NotchNotes.app`：Apple Silicon + Intel 通用应用。
- `dist.noindex/NotchNotes.zip`：可分发压缩包。
- `dist.noindex/NotchNotes.zip.sha256`：SHA-256 校验文件。

如需使用 Developer ID 签名并提交 Apple 公证：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notary-profile" \
./Scripts/package-app.sh
```

## 自动发布

每次推送 `main`，GitHub Actions 都会先运行测试，再构建通用应用，并更新 `latest` Release。推送 `v*` 标签时会另外生成对应的版本快照；如果测试或构建失败，现有 Release 不会被覆盖。

## 技术实现

- **Swift + AppKit**：无 Dock 图标的菜单栏应用、浮层窗口、屏幕定位、拖放与顶部指针触发。
- **SwiftUI**：File Shelf、选择状态、设置菜单和咖啡杯控制。
- **UserDefaults**：保存 Shelf 引用和触发模式。
- **`/usr/bin/caffeinate`**：实现无需管理员权限的基础唤醒。

## 上游项目

这个 fork 源自 [oil-oil/NotchNotes](https://github.com/oil-oil/NotchNotes)。原项目关于“把临时内容放进 MacBook 刘海”的设计是本项目的基础；这里的改动主要围绕纯文件暂存工作流、可定制触发方式和基础防休眠体验。
