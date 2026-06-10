# ListLinker

一个基于 Flutter 开发的跨平台文件管理客户端，支持 OpenList 和 Alist 文件管理服务器。

## 项目简介

ListLinker 是一款功能强大的移动端文件管理应用，采用 Flutter 框架开发，支持 Android 和 iOS 平台。它为用户提供了便捷的文件访问和管理体验，让您可以随时随地浏览、预览和管理服务器上的各类文件。

## 技术栈

- **框架**: Flutter SDK (>=2.19.6 <3.0.0)
- **状态管理**: GetX (^4.6.5)
- **网络请求**: Dio (^5.1.1)
- **本地存储**: SharedPreferences, SP_Util, Floor Database
- **多媒体播放**:
  - 视频播放: flutter_aliplayer
  - 音频播放: just_audio + just_audio_background
- **文件处理**:
  - PDF 阅读: flutter_pdfview
  - 图片加载: extended_image
  - 文档选择: flutter_document_picker
- **UI 组件**:
  - 对话框: flutter_smart_dialog
  - 侧滑菜单: flutter_slidable
  - 网格布局: flutter_staggered_grid_view
  - 下拉刷新: pull_to_refresh
- **其他功能**:
  - WebView: flutter_inappwebview
  - 权限管理: permission_handler
  - 设备信息: device_info_plus, package_info_plus

## 核心功能

### 文件管理
- 📁 浏览服务器文件和文件夹
- 🔍 文件搜索功能
- ⭐ 收藏夹管理
- 📝 最近访问记录
- 🔐 文件夹密码保护

### 媒体播放
- 🎥 在线视频播放，支持多种格式
- 🎵 音频播放器，支持后台播放
- 🖼️ 图片浏览和缩放
- 📄 PDF 文档阅读
- 📊 文本文件预览

### 文件操作
- ⬇️ 文件下载管理
- ⬆️ 文件上传（支持图片、视频、文档）
- 📋 复制和移动文件
- 🗑️ 删除文件
- ✏️ 重命名文件
- 📤 分享文件

### 用户体验
- 🌓 深色模式支持
- 🌍 多语言支持（中文、英文）
- 💾 离线缓存管理
- 📱 自适应界面设计
- 🔔 下载进度通知

## 使用指南

### 安装要求

- **Android**: Android 5.0 (API 21) 及以上
- **iOS**: iOS 12.0 及以上
- **开发环境**: Flutter SDK 2.19.6 或更高版本

### 构建项目

1. **克隆项目**
```bash
git clone <repository-url>
cd ListLinker
```

2. **安装依赖**
```bash
flutter pub get
```

3. **生成数据库代码**
```bash
flutter packages pub run build_runner build
```

4. **运行项目**
```bash
# Android
flutter run

# iOS
flutter run
```

### 配置服务器

1. 启动应用后，进入登录界面
2. 输入您的服务器地址（支持 HTTP/HTTPS）
   - 格式: `http://example.com:5244` 或 `https://example.com`
3. 输入用户名和密码（如需登录）
4. 或选择"游客模式"进行访问

### 主要功能使用

#### 文件浏览
- 点击文件夹进入目录
- 长按文件显示操作菜单
- 滑动返回上级目录

#### 下载文件
- 点击文件选择"下载"
- 在"下载管理"中查看进度
- 支持断点续传

#### 上传文件
- 点击底部 "+" 按钮
- 选择文件类型（图片、视频、文档）
- 选择文件并上传

#### 播放媒体
- 视频: 点击视频文件直接播放，支持横屏、倍速、字幕
- 音频: 支持播放列表、后台播放、循环模式
- 图片: 支持手势缩放、滑动浏览

### 设置选项

- **下载设置**: 设置最大并发下载数、默认下载路径
- **播放器设置**: 配置默认播放器、硬件加速等
- **缓存管理**: 清理图片缓存、视频缓存
- **账户管理**: 切换账户、管理多个服务器

## 许可证

本项目基于 [LICENSE](LICENSE) 文件中的许可证发布。

## 相关链接

- [OpenList 项目](https://github.com/alist-org/alist)
- [Flutter 官方文档](https://flutter.dev/docs)

## 贡献

欢迎提交 Issue 和 Pull Request！

---

**版本**: 1.1.1+13
