# IPA 源商店（IPASourceBrowser）

一个仿 SideStore 界面的 iOS 源浏览器：订阅公开的侧载 IPA 源（AltStore / SideStore 的 JSON 源格式），按源分组浏览应用，在详情页把 IPA 下载到 iPhone 的「文件」App 里。

> 本应用只负责**浏览与下载**，不负责签名与安装。下载好的 IPA 可用 SideStore、LiveContainer、Impactor、Sideloadly 等工具签名安装。

## 功能

- **订阅源**：右上角 `+` 添加任意 AltStore / SideStore 格式的源地址，添加前会先拉取验证；可删除、排序。订阅列表保存在本机。
- **预置源**（已实测可拉取）：
  - AltStore 官方源：`https://apps.altstore.io/`
  - SideStore 团队精选源：`https://community-apps.sidestore.io/sidecommunity.json`
- **按源分组**：主界面按源分组，点分组标题可**展开 / 收缩**；下拉刷新、右上角按钮全量刷新；顶部可按名称 / 开发者 / 副标题搜索。
- **图标本地缓存（按源分组）**：应用图标与截图缓存在 `Caches/IconCache/<源地址哈希>/` 下，内存 + 磁盘两层，拉过一次后离线也能显示；**删除某个源时，它那一组的缓存图标会一并删掉**，不影响其他源。
- **应用卡片 → 详情页**：点卡片进入详情，含大图标、版本、大小、发布日期、最低系统、介绍、版本说明、截图预览、版本历史。
- **下载到「文件」App**：
  - 详情页点「下载 IPA」带进度条，可取消，也可下载任意历史版本。
  - 首次使用建议先在「管理源 > 下载位置」或详情页里**指定「文件」App 里的下载目录**（选「下载」文件夹并授权），之后的下载会直接存进该目录。
  - 未指定时，文件存到 `文件 > 我的 iPhone > IPA 源商店 > Downloads`（应用已开启文件共享，该目录在「文件」App 里可见），详情页也提供系统分享按钮，可再另存到任意位置。

## 源格式兼容

兼容新旧两种写法：

- 新格式：应用带 `versions[]`（`version` / `date` / `downloadURL` / `size` / `localizedDescription` / `minOSVersion`）
- 旧格式：应用本身带平铺的 `version` / `downloadURL` / `size` 等字段
- `size` 为数字或字符串都可；截图支持 `screenshotURLs[]` 或 `screenshots[{imageURL}]`；主题色支持 `018084` 与 `#21486b` 两种写法。

## 构建与发布（GitHub Actions）

源码用 [XcodeGen](https://github.com/yonaskolb/XcodeGen) 的 `project.yml` 描述工程，不提交 `.xcodeproj`。

- `.github/workflows/build.yml` 在 GitHub 免费的 `macos-15` 机器上运行：
  1. `brew install xcodegen` 并生成工程
  2. `xcodebuild` 以**未签名**方式构建 iphoneos Release
  3. 打包 `Payload/*.app` 为 `IPASourceBrowser.ipa`
  4. 上传构建产物，并发布到仓库 **Releases** 页面
- 触发方式：
  - 手动：Actions 页选 “Build & Release IPA” → Run workflow，填版本号（如 `v1.0.0`）
  - 或推 `v*` 标签

本地构建（有 Mac 时）：

```bash
brew install xcodegen
xcodegen generate
open IPASourceBrowser.xcodeproj
```

## 技术栈

- SwiftUI（iOS 16+），无第三方依赖
- `URLSession` 拉取源 JSON 与下载 IPA（带进度）
- 安全作用域书签（security-scoped bookmark）记住「文件」App 里授权的下载目录

Bundle ID：`com.jkyotnfjfbjnknh.ipasourcebrowser`
