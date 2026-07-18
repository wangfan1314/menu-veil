<div align="center">
  <img src="Assets/MenuVeil.png" width="128" alt="MenuVeil 图标">
  <h1>MenuVeil</h1>
  <p>管理被 MacBook 刘海和有限空间遮住的菜单栏图标。</p>
  <p><strong>简体中文</strong> · <a href="README_EN.md">English</a></p>
</div>

MenuVeil 是一款原生 macOS 菜单栏工具。它能够列出当前会话中的菜单栏项目，包括已经因刘海或空间不足而移出屏幕的项目，并把不常用的图标收进一个可随时展开的隐藏区。

## 功能

- 发现当前会话中的全部菜单栏项目，而不仅是屏幕上仍然可见的部分。
- 使用“显示”和“隐藏”两个标签页管理图标。
- 从 MenuVeil 的菜单栏弹窗中查看并恢复隐藏图标。
- 自动保存显示/隐藏配置，重新启动后直接复用上次的布局。
- 新出现且尚未配置的图标默认显示。
- 关闭设置窗口后仅驻留菜单栏，不占用 Dock 位置。
- 全程在本机运行，不需要网络服务。

## 界面预览

<table>
  <tr>
    <td width="50%" align="center"><img src="images/3.png" alt="显示中的菜单栏图标"><br><strong>显示</strong>：查看当前可见项目并选择隐藏</td>
    <td width="50%" align="center"><img src="images/4.png" alt="已隐藏的菜单栏图标"><br><strong>隐藏</strong>：查看隐藏项目并恢复显示</td>
  </tr>
  <tr>
    <td width="50%" align="center"><img src="images/1.png" alt="MenuVeil 菜单栏入口"><br>收起后仅保留简洁的菜单栏入口</td>
    <td width="50%" align="center"><img src="images/2.png" alt="隐藏图标弹窗"><br>无需打开设置窗口即可快速恢复图标</td>
  </tr>
</table>

## 系统要求

- macOS 14 Sonoma 或更高版本。
- 辅助功能权限，用于移动菜单栏项目。

## 安装

1. 从 Releases 下载 `MenuVeil-<版本号>.dmg`。
2. 打开 DMG，将 MenuVeil 拖入“应用程序”文件夹。
3. 首次打开时，如果 macOS 阻止运行，请进入“系统设置 → 隐私与安全性”，找到 MenuVeil 并点击“仍要打开”。
4. 按应用内提示，在“系统设置 → 隐私与安全性 → 辅助功能”中启用 MenuVeil，然后重新打开应用。

当前发布包使用 ad-hoc 签名，因为项目暂未使用 Apple Developer ID。它不会绕过 macOS 的安全检查，首次运行需要由用户手动确认。

## 使用

1. 打开 MenuVeil，在“显示”标签页中点击“隐藏”。
2. 点击菜单栏中的双箭头图标，可以查看所有已隐藏项目。
3. 在弹窗中点击“显示”，可将对应项目恢复到菜单栏。
4. 弹窗底部提供“设置”和“退出”入口。

MenuVeil 会记住布局。以后启动时会直接恢复上次结果；新安装或新出现的应用图标默认保留显示。

> macOS 管理的部分系统项目可能不允许移动。MenuVeil 会将能够识别出的此类项目置灰，避免无效操作。

## 从源码构建

需要 Xcode 16 或兼容 Swift 6 的开发环境。

```bash
git clone <你的仓库地址>
cd menu-veil
swift test
chmod +x scripts/build-app.sh scripts/build-dmg.sh
scripts/build-app.sh
open "dist/MenuVeil.app"
```

也可以在 Xcode 中打开 `Package.swift`，选择 `BarEverything` scheme 后运行。`BarEverything` 是当前内部构建目标名称，最终应用名称仍为 MenuVeil。

## 生成 DMG

无 Developer ID 时，执行：

```bash
scripts/build-dmg.sh
```

产物位于 `dist/MenuVeil-0.1.0.dmg`。可通过环境变量覆盖版本号：

```bash
MENUVEIL_VERSION=0.2.0 scripts/build-dmg.sh
```

取得 Apple Developer Program 的证书和公证凭据后，可生成正式签名和公证版本：

```bash
MENUVEIL_SIGN_IDENTITY="Developer ID Application: Your Name (TEAMID)" \
MENUVEIL_NOTARY_PROFILE="MenuVeilNotary" \
scripts/build-dmg.sh
```

## 隐私

MenuVeil 使用 macOS 辅助功能与窗口信息接口识别和移动菜单栏项目。配置仅保存在本机的 `UserDefaults` 中；应用不上传菜单栏信息，也不包含网络请求。

## 参与贡献

欢迎提交 Issue 和 Pull Request。报告问题时，请附上 macOS 版本、MenuVeil 版本、受影响图标所属应用，以及能够复现问题的步骤。
