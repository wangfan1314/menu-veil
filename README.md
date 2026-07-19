<div align="center">
  <img src="Assets/MenuVeil.png" width="128" alt="MenuVeil 图标">
  <h1>MenuVeil</h1>
  <p><strong>看见、隐藏和整理每一个菜单栏图标，包括已经被 MacBook 刘海遮住的图标。</strong></p>
  <p><strong>简体中文</strong> · <a href="README_EN.md">English</a></p>
  <p><a href="https://github.com/wangfan1314/menu-veil/releases">下载</a> · <a href="https://github.com/wangfan1314/menu-veil/issues">问题反馈</a></p>
</div>

MenuVeil 是一款原生 macOS 菜单栏管理工具。与依赖用户先按住 `⌘` 拖动分隔符的工具不同，它会列出当前会话中的菜单栏项目，包括因刘海或空间不足而移出屏幕的图标，让你直接管理显示状态和排列顺序。

## 核心功能

- **完整发现**：列出当前会话中的菜单栏项目，不局限于屏幕上仍然可见的部分。
- **显示与隐藏**：通过两个独立标签页管理图标，不直接关闭系统“菜单栏”开关。
- **拖拽排序**：拖动列表左侧把手，同步调整真实菜单栏中的图标顺序。
- **快速取用**：点击菜单栏双箭头，在弹窗中查看并恢复隐藏图标；点击空白处自动收起。
- **系统图标支持**：可管理 Wi‑Fi、蓝牙、电池、Siri、聚焦等可移动的系统项目。
- **记住布局**：重新启动后直接复用上次结果；新出现且尚未配置的图标默认显示。
- **安静驻留**：关闭设置窗口后不占用 Dock，只保留菜单栏入口。
- **本地运行**：无账户、无云服务，不上传菜单栏信息。

## 界面预览

<table>
  <tr>
    <td width="50%" align="center"><img src="images/3.png" alt="显示中的菜单栏图标"><br><strong>显示</strong>：隐藏或拖动排列当前项目</td>
    <td width="50%" align="center"><img src="images/4.png" alt="已隐藏的菜单栏图标"><br><strong>隐藏</strong>：恢复或重新排列隐藏项目</td>
  </tr>
  <tr>
    <td width="50%" align="center"><img src="images/1.png" alt="MenuVeil 菜单栏入口"><br>收起后仅保留简洁的菜单栏入口</td>
    <td width="50%" align="center"><img src="images/2.png" alt="隐藏图标弹窗"><br>无需打开设置窗口即可快速恢复图标</td>
  </tr>
</table>

## 系统要求

- macOS 14 Sonoma 或更高版本。
- 当前预编译 DMG 支持 Apple Silicon（M1 或更新机型）。
- 需要辅助功能权限，用于识别和移动其他应用的菜单栏项目。

## 安装

1. 从 [GitHub Releases](https://github.com/wangfan1314/menu-veil/releases) 下载 `MenuVeil-<版本号>.dmg`。
2. 打开 DMG，将 MenuVeil 拖入“应用程序”文件夹。
3. 首次打开如果被 macOS 阻止，请进入“系统设置 → 隐私与安全性”，找到 MenuVeil 并点击“仍要打开”。
4. 按应用内提示，在“系统设置 → 隐私与安全性 → 辅助功能”中启用 MenuVeil，然后重新打开应用。

当前发布包使用 ad-hoc 签名，因为项目暂未使用 Apple Developer ID。首次启动需要用户手动确认，这是 macOS 对未公证应用的正常保护。

## 使用方法

### 隐藏与恢复

在“显示”标签页点击“隐藏”。需要恢复时，可以切换到“隐藏”标签页，也可以点击菜单栏双箭头后选择“显示”。

### 调整顺序

在任一标签页中拖动图标左侧的三横线。MenuVeil 会同步调整实际菜单栏或隐藏分区中的顺序。

### 菜单栏弹窗

点击 MenuVeil 双箭头查看隐藏图标。弹窗底部提供“设置”和“退出程序”；点击弹窗外任意位置会自动关闭。

MenuVeil 会保存显示状态和顺序。再次启动时直接复用上次布局，不再逐个播放整理动画。

## 系统项目与限制

- Wi‑Fi、蓝牙、电池、Siri、聚焦等可移动的系统项目可以隐藏和排序。
- 时钟、控制中心主入口以及录屏、麦克风等隐私使用指示由 macOS 固定，MenuVeil 会将其置灰。
- 菜单栏行为属于 macOS 系统实现，系统大版本更新后可能需要进行兼容性调整。
- 如果某个图标无法移动，请在 Issue 中附上 macOS 版本、应用名称和复现步骤。

## 从源码构建

需要 Xcode 16 或其他兼容 Swift 6 的开发环境。

```bash
git clone https://github.com/wangfan1314/menu-veil.git
cd menu-veil
swift test
chmod +x scripts/build-app.sh scripts/build-dmg.sh
scripts/build-app.sh
open "dist/MenuVeil.app"
```

也可以在 Xcode 中打开 `Package.swift`，选择 `BarEverything` scheme 后运行。`BarEverything` 是当前内部构建目标名称，最终应用名称仍为 MenuVeil。

## 生成安装包

无 Developer ID 时执行：

```bash
scripts/build-dmg.sh
```

默认产物为 `dist/MenuVeil-0.1.0.dmg`。可以覆盖版本号：

```bash
MENUVEIL_VERSION=0.2.0 scripts/build-dmg.sh
```

取得 Developer ID 和公证凭据后，可以生成正式签名与公证版本：

```bash
MENUVEIL_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
MENUVEIL_NOTARY_PROFILE="MenuVeilNotary" \
scripts/build-dmg.sh
```

## 隐私

MenuVeil 使用 macOS 辅助功能与窗口信息接口识别、移动菜单栏项目。显示配置仅保存在本机 `UserDefaults` 中；应用不上传菜单栏信息，也不包含网络请求。

## 参与贡献

欢迎提交 [Issue](https://github.com/wangfan1314/menu-veil/issues) 和 Pull Request。报告问题时，请附上 macOS 版本、MenuVeil 版本、受影响图标所属应用和清晰的复现步骤。
