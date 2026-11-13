import SwiftUI

struct AppDetailView: View {
    let app: SourceApp
    let sourceName: String
    /// Subscription URL of the owning source; decides the image cache group.
    var sourceID: String?

    @StateObject private var downloader = IPADownloader()
    @State private var showFolderPicker = false
    @State private var folderVersion = 0 // bump to refresh folder label after picking

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header
                downloadSection
                infoGrid
                if !app.allScreenshotURLs.isEmpty { screenshots }
                if let description = app.localizedDescription, !description.isEmpty {
                    section(title: "介绍") {
                        Text(description).font(.body)
                    }
                }
                if let notes = app.releaseNotes, !notes.isEmpty {
                    section(title: "最新版本说明") {
                        Text(notes).font(.body)
                    }
                }
                if let versions = app.versions, versions.count > 1 {
                    versionHistory(versions)
                }
                Text("来源：\(sourceName)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle(app.name)
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showFolderPicker) {
            FolderPicker { url in
                DownloadsFolderManager.shared.saveBookmark(for: url)
                folderVersion += 1
                showFolderPicker = false
            }
        }
    }

    // MARK: Sections

    private var header: some View {
        HStack(spacing: 16) {
            AppIconView(urlString: app.iconURL, name: app.name, size: 92, cacheSourceURL: sourceID)
            VStack(alignment: .leading, spacing: 4) {
                Text(app.name).font(.title2.bold()).lineLimit(2)
                if let subtitle = app.subtitle {
                    Text(subtitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
                if let developer = app.developerName {
                    Text(developer)
                        .font(.subheadline)
                        .foregroundStyle(Color(hexString: app.tintColor) ?? .accentColor)
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var downloadSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if downloader.isDownloading {
                ProgressView(value: downloader.progress)
                HStack {
                    Text(downloader.statusText ?? "正在下载…").font(.footnote).foregroundStyle(.secondary)
                    Spacer()
                    Button("取消", role: .destructive) { downloader.cancel() }
                        .font(.footnote)
                }
            } else {
                Button {
                    if let url = app.displayDownloadURL {
                        downloader.download(from: url, fileName: app.suggestedFileName(for: app.latestVersion))
                    }
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.circle.fill")
                        Text("下载 IPA · v\(app.displayVersion)")
                    }
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color(hexString: app.tintColor) ?? .accentColor)
                .disabled(app.displayDownloadURL == nil)
            }

            if let error = downloader.errorText {
                Text("下载失败：\(error)")
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            if let saved = downloader.savedFileURL {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                    Text(downloader.savedIntoCustomFolder
                         ? "已保存到「文件」App：\(saved.lastPathComponent)"
                         : "已保存到 文件 > 我的 iPhone > IPA 源商店 > Downloads")
                        .font(.footnote)
                    Spacer()
                    ShareLink(item: saved) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }

            folderRow
        }
    }

    private var folderRow: some View {
        VStack(alignment: .leading, spacing: 4) {
            let _ = folderVersion
            if let name = DownloadsFolderManager.shared.customFolderName {
                Text("下载目录：「文件」App 里的「\(name)」文件夹")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("更改下载目录") { showFolderPicker = true }
                    .font(.footnote)
            } else {
                Text("尚未指定「文件」App 的下载目录，默认存进本应用的 Downloads（在「文件 > 我的 iPhone > IPA 源商店」里可见）。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Button("指定「文件」App 里的下载目录") { showFolderPicker = true }
                    .font(.footnote)
            }
        }
    }

    private var infoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            infoItem(title: "版本", value: app.displayVersion)
            infoItem(title: "大小", value: formatBytes(app.displaySize).isEmpty ? "-" : formatBytes(app.displaySize))
            infoItem(title: "发布日期", value: formatDateString(app.latestVersion?.date ?? app.versionDate).isEmpty ? "-" : formatDateString(app.latestVersion?.date ?? app.versionDate))
            infoItem(title: "开发者", value: app.developerName ?? "-")
            infoItem(title: "类别", value: app.category ?? "-")
            infoItem(title: "最低系统", value: app.latestVersion?.minOSVersion.map { "iOS \($0)+" } ?? "-")
        }
        .padding()
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func infoItem(title: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.weight(.medium)).lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }

    private var screenshots: some View {
        section(title: "预览") {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(app.allScreenshotURLs.enumerated()), id: \.offset) { _, url in
                        CachedRemoteImageView(url: url, cacheSourceURL: sourceID)
                            .frame(width: 150, height: 300)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    }
                }
            }
        }
    }

    private func versionHistory(_ versions: [SourceVersion]) -> some View {
        section(title: "版本历史") {
            VStack(spacing: 0) {
                ForEach(versions) { version in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("v\(version.version)").font(.subheadline.weight(.medium))
                            Text([formatDateString(version.date), formatBytes(version.size?.value)]
                                .filter { !$0.isEmpty }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button {
                            if let url = app.downloadURL(for: version) {
                                downloader.download(from: url, fileName: app.suggestedFileName(for: version))
                            }
                        } label: {
                            Image(systemName: "arrow.down.circle")
                                .font(.title3)
                        }
                        .disabled(downloader.isDownloading)
                    }
                    .padding(.vertical, 8)
                    if version.id != versions.last?.id {
                        Divider()
                    }
                }
            }
        }
    }

    private func section<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.title3.bold())
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
