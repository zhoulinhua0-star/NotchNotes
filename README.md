<p align="center">
  <img src="./docs/assets/app-icon.png" width="96" alt="NotchNotes 应用图标">
</p>

<h1 align="center">NotchNotes</h1>

<p align="center">
  <strong>把 Mac 屏幕顶部变成随手可用的文件暂存架。</strong><br>
  暂存文件、跨应用拖放；Mission Control 中安静退场，系统睡眠时自动结束 Keep Awake。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/macOS-14%2B-000000?style=flat-square&logo=apple&logoColor=white" alt="支持 macOS 14 或更高版本">
  <img src="https://img.shields.io/badge/Swift-6-F05138?style=flat-square&logo=swift&logoColor=white" alt="使用 Swift 6">
  <img src="https://img.shields.io/badge/Universal-Apple%20Silicon%20%7C%20Intel-6E6E73?style=flat-square" alt="支持 Apple Silicon 和 Intel">
</p>

<p align="center">
  <a href="#功能概览">功能概览</a>
  ·
  <a href="#获取-notchnotes"><strong>下载安装</strong></a>
  ·
  <a href="https://github.com/oil-oil/NotchNotes">上游项目</a>
</p>

## 功能概览

| 文件暂存 | 不干扰 Mission Control | 唤醒有边界 |
| --- | --- | --- |
| 只保存路径引用，原文件始终留在原位 | 管理窗口和 Space 时自动隐藏 Shelf、暂停 Hover | 防止空闲睡眠；合盖或选择“睡眠”后自动关闭 |

### File Shelf

- 把文件或文件夹拖到屏幕顶部，或点击 `Add Files`、按 <kbd>⌘</kbd> + <kbd>O</kbd> 添加。
- 在 Shelf 中单选、多选、框选和拖出项目；双击打开，右键可在 Finder 中显示。
- Shelf 只保存路径引用，不复制、移动或删除原文件；清空 Shelf 也不会删除磁盘内容。
- 暂存记录保存在本机，最多保留 100 项。

### Click / Hover — 在需要时出现

从 Shelf 右上角的齿轮或菜单栏图标中选择 `Open Shelf With`：

- **Hover**：把鼠标移到屏幕顶部中央即可展开，适合有实体刘海的 Mac。
- **Click**：单击屏幕顶部中央展开，适合没有实体刘海的 Mac 或偏好明确点击的用户。

首次运行时，NotchNotes 会根据屏幕类型选择默认方式；之后的选择保存在本机。普通桌面、不同 Space 和全屏应用中的 Hover 行为保持一致。

> [!TIP]
> 三指上滑、按 <kbd>F3</kbd> 或用其他方式进入 Mission Control 时，Shelf 会自动隐藏并暂停 Hover。在顶部关闭或切换 Space 不会触发下拉；退出后经过短暂冷却，需把鼠标移出顶部区域再重新移入。整个过程不需要辅助功能权限，也不监听或截获触控板手势。

### Keep Awake — 睡眠即停止

点击 Shelf 右上角的咖啡杯，或从菜单栏启用 `Keep Mac Awake`。NotchNotes 会在后台运行：

```bash
/usr/bin/caffeinate -di -w <NotchNotes PID>
```

| 操作 | Keep Awake 状态 |
| --- | --- |
| 点击咖啡杯开启 | 防止显示器休眠和 Mac 因空闲进入睡眠 |
| 再次点击或退出 NotchNotes | 立即关闭 |
| 合盖或从 Apple 菜单选择“睡眠” | 在系统睡眠前自动关闭 |
| 重新开盖或唤醒 | 保持关闭，不自动恢复 |

> [!NOTE]
> Keep Awake 不需要管理员权限，也不修改系统睡眠设置。自动关闭以 Mac 真正进入系统睡眠为准：如果连接电源和外接显示器后使用 macOS 闭盖显示模式，Mac 可能继续运行，此时请手动关闭 Keep Awake，并保持设备通风。

## 获取 NotchNotes

### 从 Releases 安装

1. 打开 [Releases](https://github.com/zhoulinhua0-star/NotchNotes/releases)，下载最新 Release 中的 `NotchNotes.zip`。
2. 解压后把 `NotchNotes.app` 拖入“应用程序”。
3. 首次启动时右键点击应用并选择“打开”。
4. 如果 macOS 仍然拦截，请前往“系统设置 → 隐私与安全性”，点击“仍要打开”。

> [!IMPORTANT]
> 如果 Releases 页面还没有 `NotchNotes.zip`，说明这个 fork 尚未完成首次发布。请先按下方步骤本地构建，或由仓库维护者在 Actions 中运行“发布 macOS 应用”工作流。

公开构建使用临时签名，尚未经过 Apple 公证，因此首次启动可能出现安全提示。正式免提示分发需要 Developer ID Application 证书和 Apple 公证。

### 本地构建

需要 macOS 14 或更高版本，以及支持 Swift 6 的 Xcode 或 Command Line Tools。

```bash
git clone https://github.com/zhoulinhua0-star/NotchNotes.git
cd NotchNotes
swift test
./Scripts/package-app.sh
open dist.noindex
```

构建完成后，`dist.noindex` 包含：

- `NotchNotes.app`：可直接测试或拖入“应用程序”。
- `NotchNotes.zip`：Apple Silicon + Intel 通用应用压缩包。
- `NotchNotes.zip.sha256`：SHA-256 校验文件。

如需使用 Developer ID 签名并提交 Apple 公证：

```bash
SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
NOTARY_PROFILE="notary-profile" \
./Scripts/package-app.sh
```

## 日常使用与更新

NotchNotes 是菜单栏应用，运行后通常不会显示 Dock 图标。可以从 Spotlight、Finder 的“应用程序”或 Terminal 启动：

```bash
open -a NotchNotes
```

若希望登录后自动运行，请前往“系统设置 → 通用 → 登录项与扩展 → 登录时打开”，点击 `+` 并选择 `NotchNotes.app`。

应用目前不包含自动更新器。安装新版本前先退出 NotchNotes，再把新版拖入“应用程序”并选择“替换”；正常替换不会清除 Shelf 内容或 Click / Hover 设置。

## 与上游项目的区别

这个 fork 基于 [oil-oil/NotchNotes](https://github.com/oil-oil/NotchNotes)，目前聚焦于三项能力：

- 纯文件暂存与跨应用拖放。
- 可切换的 Click / Hover 顶部触发方式，并在 Mission Control 中自动暂停 Hover。
- 基于 `/usr/bin/caffeinate` 的基础防休眠，并在系统睡眠前自动关闭。

上游的 Markdown 笔记界面目前不参与这个 fork 的构建。旧版本保存在本机的笔记和内嵌图片不会被主动删除，但当前版本不会加载或显示它们。

## 自动发布

启用 GitHub Actions 后，推送到 `main` 或手动运行 [`release.yml`](https://github.com/zhoulinhua0-star/NotchNotes/actions/workflows/release.yml) 会先执行测试，再构建通用应用并创建或更新 `latest` Release。推送 `v*` 标签会另外生成对应的版本快照；测试或构建失败时，现有 Release 不会被覆盖。

## 技术实现

- **Swift + AppKit**：菜单栏应用、浮层窗口、屏幕定位、拖放与顶部指针触发；使用系统窗口可见性隔离 Mission Control。
- **SwiftUI**：File Shelf、选择状态、设置菜单和咖啡杯控制。
- **UserDefaults**：保存 Shelf 路径引用和触发模式。
- **`/usr/bin/caffeinate` + `NSWorkspace`**：实现无需管理员权限的基础唤醒，并在系统睡眠通知到达时主动停止。
