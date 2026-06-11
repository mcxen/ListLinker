
# ListLinker

一个基于 Flutter 开发的跨平台文件管理客户端，为 [OpenList](https://github.com/alist-org/alist) / [Alist](https://github.com/alist-org/alist) 文件管理服务器提供原生的移动端体验。

## 简介

ListLinker 是一款功能丰富的文件管理应用，支持 Android、iOS、macOS、Windows、Linux 和 Web 六大平台。它为用户提供了流畅的文件浏览、多媒体播放和文件管理体验，可随时随地连接您的 Alist 服务器，像使用本地文件管理器一样操作云端文件。

## 功能特性

**文件管理** — 浏览服务器文件与文件夹，支持文件搜索、收藏夹、最近访问记录，以及文件夹密码保护和双因素认证（2FA）。

**多媒体播放** — 内置视频播放器（支持横屏、倍速播放、字幕、音轨切换、硬件加速），音频播放器（播放列表、后台播放、单曲循环、随机播放），图片浏览器（手势缩放、滑动浏览、保存至相册），以及 PDF 和文本文件预览。

**文件操作** — 支持文件下载管理（后台下载、断点续传、队列控制）、文件上传（图片、视频、文档）、复制/移动文件、删除与重命名、新建文件夹、分享文件链接。

**用户体验** — Material 3 设计语言，深色/浅色主题自动切换，中英双语支持，自适应界面设计，应用内版本更新检测。

## 技术架构

| 模块 | 技术选型 |
|------|---------|
| 框架 | Flutter 3.13.x (Dart >=3.0) |
| 状态管理 | GetX |
| 网络请求 | Dio |
| 本地数据库 | Floor (SQLite) |
| 视频播放 | flutter_aliplayer / GSYVideoPlayer (Android) |
| 音频播放 | just_audio + just_audio_background |
| 图片加载 | extended_image |
| PDF 阅读 | flutter_pdfview |
| WebView | flutter_inappwebview |

## 支持平台

| 平台 | 最低版本 | 状态 |
|------|---------|------|
| Android | 5.0 (API 21) | ✅ |
| iOS | 12.0 | ✅ |
| macOS | — | ✅ |
| Windows | — | ✅ |
| Linux | — | ✅ |
| Web | — | ✅ |

## 快速开始

### 环境要求

- Flutter SDK >= 3.13.8
- Dart SDK >= 3.0
- [FVM](https://fvm.app/) (推荐，项目已配置 FVM)

### 构建步骤

```bash
# 1. 克隆仓库
git clone https://github.com/mcxen/ListLinker.git
cd ListLinker

# 2. 安装依赖
flutter pub get

# 3. 生成数据库代码（Floor）
flutter packages pub run build_runner build

# 4. 运行
flutter run
```

如果使用 FVM：

```bash
fvm install
fvm flutter pub get
fvm flutter packages pub run build_runner build
fvm flutter run
```

### 服务器配置

启动应用后在登录界面输入您的 Alist / OpenList 服务器地址（如 `http://example.com:5244` 或 `https://example.com`），填写用户名和密码后即可连接。也支持以游客模式匿名访问公开资源。

## 项目结构

```
lib/
├── database/          # Floor 数据库定义与 DAO
├── entity/            # 数据模型与 JSON 序列化
├── generated/         # 生成的代码（主题色、JSON 解析）
├── l10n/              # 国际化资源（中/英）
├── net/               # 网络层（Dio 封装、拦截器、错误处理）
├── screen/            # 页面（文件列表、播放器、设置等）
├── util/              # 工具类（下载管理、文件类型、排序等）
├── widget/            # 自定义组件
├── router.dart        # 路由配置
└── main.dart          # 入口
```

## CI/CD

项目使用 GitHub Actions 实现全平台自动构建。每次推送至 `main` 分支或提交 Pull Request 时，将自动触发 Android、iOS、macOS、Windows、Linux 和 Web 六个平台的构建流水线，构建产物以 Artifact 形式上传。

## 截图

## 相关链接

- [Alist 项目](https://github.com/alist-org/alist) — 一个支持多种存储的文件列表程序
- [Flutter 官方文档](https://flutter.dev/docs)

## 贡献

欢迎提交 Issue 和 Pull Request。如果您有好的建议或发现了 Bug，请通过 [GitHub Issues](https://github.com/mcxen/ListLinker/issues) 反馈。

---

**当前版本**: 1.1.1+13
