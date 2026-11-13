import Foundation
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// Remembers the folder the user picked inside the Files app (normally "Downloads")
/// via a security-scoped bookmark, so later downloads can write straight into it.
final class DownloadsFolderManager {
    static let shared = DownloadsFolderManager()
    private let bookmarkKey = "downloadsFolderBookmark.v1"

    private init() {}

    var hasCustomFolder: Bool {
        UserDefaults.standard.data(forKey: bookmarkKey) != nil
    }

    var customFolderName: String? {
        resolvedFolder()?.lastPathComponent
    }

    func saveBookmark(for folderURL: URL) {
        let needsScope = folderURL.startAccessingSecurityScopedResource()
        defer { if needsScope { folderURL.stopAccessingSecurityScopedResource() } }
        if let data = try? folderURL.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) {
            UserDefaults.standard.set(data, forKey: bookmarkKey)
        }
    }

    func clearBookmark() {
        UserDefaults.standard.removeObject(forKey: bookmarkKey)
    }

    func resolvedFolder() -> URL? {
        guard let data = UserDefaults.standard.data(forKey: bookmarkKey) else { return nil }
        var isStale = false
        let url = try? URL(
            resolvingBookmarkData: data,
            options: [],
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
        if isStale == true, let url {
            saveBookmark(for: url)
        }
        return url
    }

    /// The app's own Documents/Downloads folder. Because file sharing is enabled,
    /// it shows up in the Files app under On My iPhone > IPA Source Browser > Downloads.
    func fallbackDownloadsDirectory() -> URL {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = documents.appendingPathComponent("Downloads", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }
}

/// Downloads an IPA with progress, then saves it into the chosen Files folder
/// (or the in-app Downloads folder as a fallback).
final class IPADownloader: NSObject, ObservableObject, URLSessionDownloadDelegate {
    @Published var isDownloading = false
    @Published var progress: Double = 0
    @Published var statusText: String?
    @Published var savedFileURL: URL?
    @Published var savedIntoCustomFolder = false
    @Published var errorText: String?

    private var session: URLSession?
    private var pendingFileName = "app.ipa"

    func download(from url: URL, fileName: String) {
        guard !isDownloading else { return }
        pendingFileName = fileName
        isDownloading = true
        progress = 0
        errorText = nil
        savedFileURL = nil
        statusText = "正在下载…"

        let configuration = URLSessionConfiguration.default
        session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
        var request = URLRequest(url: url)
        request.setValue("IPASourceBrowser/1.0", forHTTPHeaderField: "User-Agent")
        session?.downloadTask(with: request).resume()
    }

    func cancel() {
        session?.invalidateAndCancel()
        session = nil
        isDownloading = false
        statusText = nil
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didWriteData bytesWritten: Int64, totalBytesWritten: Int64,
                    totalBytesExpectedToWrite: Int64) {
        if totalBytesExpectedToWrite > 0 {
            progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        }
        statusText = "正在下载 \(formatBytes(totalBytesWritten)) / \(formatBytes(totalBytesExpectedToWrite))"
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask,
                    didFinishDownloadingTo location: URL) {
        let fileManager = FileManager.default
        do {
            if let http = downloadTask.response as? HTTPURLResponse,
               !(200...299).contains(http.statusCode) {
                throw NSError(domain: "Download", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: "服务器返回 \(http.statusCode)"])
            }

            var usedCustomFolder = false
            var destination: URL

            if let folder = DownloadsFolderManager.shared.resolvedFolder() {
                let scoped = folder.startAccessingSecurityScopedResource()
                defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
                destination = folder.appendingPathComponent(pendingFileName)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: location, to: destination)
                usedCustomFolder = true
            } else {
                destination = DownloadsFolderManager.shared
                    .fallbackDownloadsDirectory()
                    .appendingPathComponent(pendingFileName)
                if fileManager.fileExists(atPath: destination.path) {
                    try fileManager.removeItem(at: destination)
                }
                try fileManager.moveItem(at: location, to: destination)
            }

            savedFileURL = destination
            savedIntoCustomFolder = usedCustomFolder
            statusText = usedCustomFolder
                ? "已保存到「文件」App 的所选目录"
                : "已保存到 文件 > 我的 iPhone > IPA 源商店 > Downloads"
        } catch {
            errorText = error.localizedDescription
            statusText = nil
        }
        isDownloading = false
        progress = 1
        self.session = nil
    }

    func urlSession(_ session: URLSession, task: URLSessionTask,
                    didCompleteWithError error: Error?) {
        if let error, isDownloading {
            errorText = error.localizedDescription
            isDownloading = false
            statusText = nil
            self.session = nil
        }
    }
}

/// Folder picker used to authorize a folder inside the Files app (e.g. Downloads).
struct FolderPicker: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        picker.allowsMultipleSelection = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    final class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController,
                            didPickDocumentsAt urls: [URL]) {
            if let url = urls.first { onPick(url) }
        }
    }
}
