# AirCard-iOS 中文版

<p align="center">
  <img src="ios-app/Assets.xcassets/AppIcon.appiconset/AppIcon.png" width="128" height="128" alt="AirCard-iOS 图标" style="border-radius: 28px; box-shadow: 0 8px 24px rgba(0,0,0,0.18);" />
</p>

<p align="center">
  在 iOS 27+ 上直接定制 Apple 钱包卡面、锁屏密码盘主题与 PosterBoard 壁纸。
</p>

<p align="center">
  <img src="https://img.shields.io/badge/平台-iOS%2027+-blue?style=flat-square&logo=apple" alt="平台" />
  <img src="https://img.shields.io/badge/Swift-5.0-orange?style=flat-square&logo=swift" alt="Swift" />
  <img src="https://img.shields.io/badge/Rust-FFI%20核心-red?style=flat-square&logo=rust" alt="Rust" />
  <img src="https://img.shields.io/badge/界面语言-简体中文-brightgreen?style=flat-square" alt="简体中文" />
  <img src="https://img.shields.io/badge/License-MIT-green?style=flat-square" alt="License" />
</p>

## 关于本仓库

本仓库是 [Mak5er/AirCard-iOS](https://github.com/Mak5er/AirCard-iOS) 的**简体中文汉化版**，由 SheldonJoO 维护。

- 已完成 App 内所有界面文案、提示信息、日志输出与代码注释的简体中文翻译；
- 已完成 `README` 的中文化，英文原版保留在 [README_EN.md](README_EN.md)；
- **未改动任何功能逻辑**：漏洞利用流程、文件路径、Bundle ID、配对服务名等均与原版保持一致，仅替换展示用文本；
- 应用显示名仍为 `AirCard-iOS`——它会作为 Bonjour 配对服务名出现在「设置 › 隐私与安全性 › 开发者模式 › 与 AirCard-iOS 配对」中，改名会导致系统配对入口对不上。

> 若你希望跟进上游更新，请以原项目为准；本仓库不修改核心功能，方便对照合并。

## 项目简介

AirCard-iOS 可在**不越狱**的情况下，直接在本机定制 Apple 钱包卡片图案、锁屏密码拨号盘主题以及锁屏壁纸。

App 通过 LocalDevVPN 提供的本地回环隧道（`10.7.0.1` 或 `127.0.0.1`）与系统内部服务通信，文件读写则由 Rust 编写的 `AirliftFFI` 库完成，它对接的是系统的 AirTraffic 服务。

> **兼容性说明**：当前版本要求 **iOS 27.0 及以上（iOS 27+）**。

## 功能特性

### Apple 钱包卡面
- 将自定义卡面写入 Passbook 缓存目录（`cardBackgroundCombined@3x.png`、`@2x.png`，以及 Suica 等交通卡使用的 `cardBackgroundCombined.pdf`）。
- 清除正面图与缩略图缓存，打开「钱包」时立即生效。
- 呼出 Apple Pay 时实时识别卡片标识符。
- 支持为单张卡片应用图案，也可批量刷入所有已识别的卡片。

### 密码盘主题
- 支持触摸拖动与缩放取景的实时拨号盘预览。
- 既支持整张海报铺满十个按键，也支持单个圆形按键的独立裁切。
- 目标为系统拨号盘缓存目录（`TelephonyUI-10`）。
- 提供多语言数字副标题选项，包含乌克兰语与俄语西里尔字母布局。
- 支持以 `.passthm` 文件导入与导出主题。

### PosterBoard 壁纸（.tendies）
- 可直接在「文件」App 中导入并解包 `.tendies` 壁纸压缩包。
- 自动检测 PosterBoard 壁纸容器与当前生效的描述项 UUID。
- 将壁纸配置与素材注入 PosterBoard 存储目录。
- 刷入完成后自动触发 NeoSpring 重启界面，无需重启 iPhone 即可应用壁纸。

### 本机配对
- 通过 Bonjour 在本机广播，让手机与自身配对：设置 › 隐私与安全性 › 开发者模式 › 与 AirCard-iOS 配对。
- 自动读取配对记录并同步到 `aircard_pairing.plist`。
- 一旦配对成功，之后无需电脑或任何外部连接。

## 使用前提

1. **iOS 27+**：漏洞利用与相关路径均面向 iOS 27.0 及以上版本。
2. **LocalDevVPN**：需以回环模式运行（`10.7.0.1` 或 `127.0.0.1`），让本地连接能够访问设备内部服务。
3. **开发者模式配对**：直接在「设置 › 隐私与安全性 › 开发者模式 › 与 AirCard-iOS 配对」中完成配对，或把已有的配对 plist 放入 App 的 Documents 目录。

## 获取安装包（IPA）

App 的**源码在 `ios-app/` 目录**，要装到手机上需要编译成 `.ipa`。你有两种方式拿到安装包：

### 方式一：直接下载现成 IPA（推荐）

前往 **Releases** 页面下载编译好的安装包（免签名）：

👉 **https://github.com/SheldonJoO/AirCard-iOS-CN/releases**

每次打 `v*` 标签时，GitHub Actions 会自动构建并附上 IPA；也可以在仓库的
「Actions → 构建 IPA」页面点 **Run workflow** 手动触发一次构建。

### 方式二：自己编译

见下方「从源码构建」一节，执行 `./build-ipa.sh` 即可，产物在 `build/AirCard-iOS.ipa`。
若本机编译时遇到 `No simulator runtime version ... available` 报错，说明缺少与 Xcode
SDK 版本匹配的 iOS 模拟器运行时，用 `xcodebuild -downloadPlatform iOS` 装一个即可。

## 安装方式

> 注意：Releases 里的 IPA **未签名**，需要你自行签名后安装。

使用你习惯的侧载方式安装 `AirCard-iOS.ipa`：

- SideStore 或 AltStore
- TrollStore
- LiveContainer
- Xcode 或 iOS App Signer

## 从源码构建

### 环境要求
- macOS 14.0 或更高版本，Xcode 16 或更高版本
- XcodeGen（`brew install xcodegen`）
- Rust 工具链（仅在需要重新编译 `rust-core` 时才用到）

### 构建 IPA
```bash
git clone https://github.com/SheldonJoO/AirCard-iOS-CN.git
cd AirCard-iOS-CN
./build-ipa.sh
```

打包完成后，产物位于 `build/AirCard-iOS.ipa`。

### 重新编译 Rust 框架
若要编译 `rust-core` 中的改动：
```bash
./build-ios.sh
```

## 目录结构

```
AirCard-iOS/
├── ios-app/                   # SwiftUI 应用（已全面中文化）
│   ├── AirCardApp.swift       # App 入口与生命周期
│   ├── AppViewModel.swift     # 状态管理与漏洞利用流程编排
│   ├── ContentView.swift      # 主界面视图
│   ├── TendiesView.swift      # PosterBoard 壁纸界面
│   ├── TendiesEngine.swift    # Tendies 解包与注入逻辑
│   ├── TendiesModel.swift     # 壁纸数据模型
│   ├── RespringHelper.swift   # 基于 WebKit 的 NeoSpring 重启实现
│   ├── Models.swift           # 图片切分、主题布局、归档打包
│   ├── PairingController.swift# Bonjour 主机与配对同步
│   ├── NetworkStatus.swift    # VPN 回环检测
│   ├── Utilities.swift        # 后台保活与工具方法
│   ├── GrappaHelper.[h,m]     # ATC 协议辅助
│   ├── Info.plist             # Bundle 配置
│   └── Assets.xcassets/       # App 图标与图片资源
├── AirliftFFI.xcframework/    # 编译好的 arm64 Rust 静态库与头文件
├── rust-core/                 # Rust 核心源码
├── project.yml                # XcodeGen 工程定义
├── build-ipa.sh               # IPA 构建脚本
├── build-ios.sh               # Rust 框架构建脚本
├── README.md                  # 中文说明文档（本文件）
├── README_EN.md               # 英文原版说明文档
└── LICENSE                    # MIT 许可证
```

## 致谢

- **[@mak5er](https://github.com/mak5er)**：主开发者，负责 UI、密码盘主题、Tendies 引擎与本机配对。
- **[@merybist](https://github.com/merybist)**：最初的 iOS 移植基础版本。
- **[AirLift](https://github.com/0xjohnnydev/airlift)**（作者 **[0xjohnny / @0xjohnnydev](https://github.com/0xjohnnydev)**）：`AirliftFFI` 所依赖的 AirTraffic 与 ATAirlock 沙盒逃逸研究。
- **[NeoSpring](https://github.com/rooootdev/neospring)**：Swift 实现由 **[@skadz108](https://github.com/skadz108)** 与 **[@rooootdev](https://github.com/rooootdev)** 完成，**[@neonmodder123](https://github.com/neonmodder123)** 提供了基于 WebKit GPU 进程的重启技巧。
- 整体思路建立在 **AirCard** 项目之上。
- 简体中文汉化与维护：**SheldonJoO**。

## 感谢上游作者

AirCard-iOS 是一个优秀的开源项目，由 **[@mak5er](https://github.com/mak5er)** 等人无偿开发与维护。
**本仓库只是它的简体中文汉化版本，所有功能实现、漏洞利用研究与工程成果均归上游作者所有**——
我只做了文本翻译，没有做任何原创开发。

如果你想支持这个项目，请**直接向原项目捐赠**：

👉 **[Mak5er/AirCard-iOS](https://github.com/Mak5er/AirCard-iOS)** —— 原项目页面内有官方捐赠渠道

请不要向本汉化仓库捐赠，所有支持都应流向真正付出劳动的上游作者。

## 许可证

MIT License，详见 [LICENSE](LICENSE)。

上游原项目同样基于 MIT 许可证发布，本项目遵循其授权条款。
