import CryptoKit
import Foundation
import UIKit

/// Icon/image cache grouped by source.
///
/// Layout on disk:  Caches/IconCache/<sha256(sourceURL)>/<sha256(imageURL)>.<ext>
/// Each subscribed source gets its own folder, so removing a source can delete
/// exactly its icons (and screenshots) without touching other sources' caches.
/// A small in-memory layer sits in front of the disk cache; it is keyed by
/// "<group>|<url>" so a group's entries can be purged from memory too.
final class IconCache {
    static let shared = IconCache()

    private var memory: [String: UIImage] = [:]
    private let lock = NSLock()
    private let memoryLimit = 300

    private init() {}

    // MARK: Keys & paths

    static func groupKey(forSourceURL sourceURL: String) -> String {
        sha256Hex(sourceURL)
    }

    private static func sha256Hex(_ string: String) -> String {
        let digest = SHA256.hash(data: Data(string.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    private func rootDirectory() -> URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = caches.appendingPathComponent("IconCache", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func groupDirectory(groupKey: String) -> URL {
        let dir = rootDirectory().appendingPathComponent(groupKey, isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(groupKey: String, imageURL: URL) -> URL {
        let ext = imageURL.pathExtension.isEmpty ? "png" : imageURL.pathExtension
        return groupDirectory(groupKey: groupKey)
            .appendingPathComponent(Self.sha256Hex(imageURL.absoluteString) + "." + ext)
    }

    // MARK: Loading

    /// Memory -> disk -> network, in that order. `sourceURL` decides the group;
    /// images without a source land in a shared "_global" group.
    func loadImage(from url: URL, sourceURL: String?) async -> UIImage? {
        let groupKey = sourceURL.map { Self.groupKey(forSourceURL: $0) } ?? "_global"
        let memoryKey = groupKey + "|" + url.absoluteString

        lock.lock()
        let hit = memory[memoryKey]
        lock.unlock()
        if let hit { return hit }

        let file = fileURL(groupKey: groupKey, imageURL: url)
        if let data = try? Data(contentsOf: file), let image = UIImage(data: data) {
            store(image, forKey: memoryKey)
            return image
        }

        do {
            var request = URLRequest(url: url)
            request.setValue("IPASourceBrowser/1.0", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
                return nil
            }
            guard let image = UIImage(data: data) else { return nil }
            try? data.write(to: file, options: .atomic)
            store(image, forKey: memoryKey)
            return image
        } catch {
            return nil
        }
    }

    private func store(_ image: UIImage, forKey key: String) {
        lock.lock()
        if memory.count >= memoryLimit { memory.removeAll() }
        memory[key] = image
        lock.unlock()
    }

    // MARK: Removal

    /// Deletes every cached image that belongs to one source: its whole disk
    /// folder plus its in-memory entries. Other sources are untouched.
    func removeCache(forSourceURL sourceURL: String) {
        let groupKey = Self.groupKey(forSourceURL: sourceURL)
        try? FileManager.default.removeItem(at: rootDirectory().appendingPathComponent(groupKey, isDirectory: true))
        lock.lock()
        memory = memory.filter { !$0.key.hasPrefix(groupKey + "|") }
        lock.unlock()
    }
}
