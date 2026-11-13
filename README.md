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
- **源内容本地缓存**：源的 JSON 缓存在本地，打开应用直接读缓存、不联网；只有点刷新按钮（或下拉刷新）才重新拉取。刷新失败时继续显示缓存内容。**删除源订阅时，其源缓存与图标缓存一并删除。** 首次安装没有缓存的源，分组里点「拉取这个源」即可。
- **应用卡片 → 详情页**：点卡片进入详情，含大图标、版本、大小、发布日期、最低系统、介绍、版本说明、截图预览、版本历史。截图点开可全屏查看：左右滑切换，上下滑或点右上角 × 关闭。
- **下载到「文件」App**：
  - 详情页点「下载 IPA」带进度条，可取消，也可下载任意历史版本。
  - 首次使用建议先在「管理源 > 下载位置」或详情页里**指定「文件」App 里的下载目录**（选「下载」文件夹并授权），之后的下载会直接存进该目录。
  - 未指定时，文件存到 `文件 > 我的 iPhone > IPA 源商店 > Downloads`（应用已开启文件共享，该目录在「文件」App 里可见），详情页也提供系统分享按钮，可再另存到任意位置。

## 源格式兼容

兼容新旧两种写法：

- 新格式：应用带 `versions[]`（`version` / `date` / `downloadURL` / `size` / `localizedDescription` / `minOSVersion`）
- 旧格式：应用本身带平铺的 `version` / `downloadURL` / `size` 等字段
- `size` 为数字或字符串都可；截图支持 `screenshotURLs[]` 或 `screenshots[{imageURL}]`；主题色支持 `018084` 与 `#21486b` 两种写法。

## 技术栈

- SwiftUI（iOS 16+），无第三方依赖
- `URLSession` 拉取源 JSON 与下载 IPA（带进度）
- 安全作用域书签（security-scoped bookmark）记住「文件」App 里授权的下载目录

Bundle ID：`com.jkyotnfjfbjnknh.ipasourcebrowser`
