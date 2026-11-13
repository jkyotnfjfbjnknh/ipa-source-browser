import Foundation
import UIKit
import UniformTypeIdentifiers

/// True when the app runs as a guest app inside LiveContainer (its bundle
/// lives inside LiveContainer's container). Used to describe file locations
/// the way the user will actually find them.
var isRunningInLiveContainer: Bool {
    Bundle.main.bundlePath.contains("LiveContainer")
}

/// Presents the system folder picker the canonical UIKit way: a real
/// UIDocumentPickerViewController presented from the topmost view controller,
/// with a strongly retained delegate.
///
/// Earlier attempts embedded the picker in a SwiftUI sheet and used
/// SwiftUI's fileImporter from inside a sheet; in re-signed / LiveContainer
/// environments the picker appeared but tapping "Open" never delivered a
/// result. Apple's documented flow presents the picker from a view
/// controller, which is what this does.
final class FolderPickerPresenter: NSObject, UIDocumentPickerDelegate {
    static let shared = FolderPickerPresenter()

    private var completion: ((URL?) -> Void)?

    private override init() { super.init() }

    func present(completion: @escaping (URL?) -> Void) {
        guard let top = Self.topViewController() else {
            completion(nil)
            return
        }
        self.completion = completion
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [UTType.folder])
        picker.delegate = self
        picker.allowsMultipleSelection = false
        // No directoryURL hint: let the system start at its normal location.
        top.present(picker, animated: true)
    }

    func documentPicker(_ controller: UIDocumentPickerViewController,
                        didPickDocumentsAt urls: [URL]) {
        let result = urls.first
        completion?(result)
        completion = nil
    }

    func documentPickerWasCancelled(_ controller: UIDocumentPickerViewController) {
        completion?(nil)
        completion = nil
    }

    private static func topViewController() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let window = scenes.flatMap { $0.windows }.first { $0.isKeyWindow }
            ?? scenes.flatMap { $0.windows }.first
        var top = window?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// Where the fallback Downloads folder actually shows up for the user,
/// described for the environment the app currently runs in.
var defaultDownloadsLocationDescription: String {
    if isRunningInLiveContainer {
        return "本应用在 LiveContainer 里的数据文件夹 > Documents > Downloads（在「文件」App 里打开 LiveContainer，再进本应用的数据文件夹就能找到）"
    }
    return "文件 > 我的 iPhone > IPA 源商店 > Downloads"
}

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
                : "已保存到默认 Downloads 文件夹"
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

