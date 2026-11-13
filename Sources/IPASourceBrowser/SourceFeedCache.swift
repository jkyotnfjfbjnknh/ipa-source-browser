import CryptoKit
import Foundation

/// Persists the raw JSON of each subscribed source feed, one file per source:
/// Application Support/SourceFeeds/<sha256(sourceURL)>.json
///
/// The app reads these files at launch and only goes to the network when the
/// user explicitly refreshes. Removing a source removes its file.
final class SourceFeedCache {
    static let shared = SourceFeedCache()

    private init() {}

    private func directory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("SourceFeeds", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private func fileURL(for sourceURL: String) -> URL {
        let digest = SHA256.hash(data: Data(sourceURL.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined() + ".json"
        return directory().appendingPathComponent(name)
    }

    func save(data: Data, for sourceURL: String) {
        try? data.write(to: fileURL(for: sourceURL), options: .atomic)
    }

    func loadData(for sourceURL: String) -> Data? {
        try? Data(contentsOf: fileURL(for: sourceURL))
    }

    func loadSource(for sourceURL: String) -> AltSource? {
        guard let data = loadData(for: sourceURL) else { return nil }
        return try? JSONDecoder().decode(AltSource.self, from: data)
    }

    /// When the cached copy was written (file modification time).
    func fetchedAt(for sourceURL: String) -> Date? {
        let attrs = try? FileManager.default.attributesOfItem(atPath: fileURL(for: sourceURL).path)
        return attrs?[.modificationDate] as? Date
    }

    func remove(for sourceURL: String) {
        try? FileManager.default.removeItem(at: fileURL(for: sourceURL))
    }
}
