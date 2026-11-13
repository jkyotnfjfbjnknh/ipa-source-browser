import Foundation

/// Flexible size: AltStore sources encode `size` either as a number or as a string.
struct FlexibleSize: Decodable {
    let value: Int64

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let number = try? container.decode(Int64.self) {
            value = number
        } else if let string = try? container.decode(String.self), let parsed = Int64(string) {
            value = parsed
        } else if let double = try? container.decode(Double.self) {
            value = Int64(double)
        } else {
            value = 0
        }
    }
}

/// Screenshot entries come in two shapes: plain URL strings (screenshotURLs)
/// or objects with an `imageURL` key (screenshots).
struct Screenshot: Decodable {
    let imageURL: String?

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let string = try? container.decode(String.self) {
            imageURL = string
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        imageURL = (try? container.decode(String.self, forKey: .imageURL))
            ?? (try? container.decode(String.self, forKey: .url))
    }

    private enum CodingKeys: String, CodingKey {
        case imageURL, url
    }
}

struct SourceVersion: Decodable, Identifiable {
    var id: String { version + "|" + downloadURL }
    let version: String
    let buildVersion: String?
    let date: String?
    let downloadURL: String
    let size: FlexibleSize?
    let localizedDescription: String?
    let minOSVersion: String?
    let sha256: String?
}

struct SourceApp: Decodable, Identifiable {
    var id: String { bundleIdentifier }
    let name: String
    let bundleIdentifier: String
    let developerName: String?
    let subtitle: String?
    let localizedDescription: String?
    let iconURL: String?
    let tintColor: String?
    let category: String?
    // Legacy flat fields (older sources put the latest release on the app itself)
    let version: String?
    let versionDate: String?
    let versionDescription: String?
    let downloadURL: String?
    let size: FlexibleSize?
    let versions: [SourceVersion]?
    let screenshotURLs: [String]?
    let screenshots: [Screenshot]?

    var latestVersion: SourceVersion? { versions?.first }

    var displayVersion: String {
        latestVersion?.version ?? version ?? "-"
    }

    var displayDownloadURL: URL? {
        let raw = latestVersion?.downloadURL ?? downloadURL
        return raw.flatMap { URL(string: $0) }
    }

    var displaySize: Int64? {
        latestVersion?.size?.value ?? size?.value
    }

    var releaseNotes: String? {
        latestVersion?.localizedDescription ?? versionDescription
    }

    var allScreenshotURLs: [URL] {
        if let urls = screenshotURLs, !urls.isEmpty {
            return urls.compactMap { URL(string: $0) }
        }
        return (screenshots ?? []).compactMap { $0.imageURL.flatMap { URL(string: $0) } }
    }

    func downloadURL(for version: SourceVersion) -> URL? {
        URL(string: version.downloadURL)
    }

    func suggestedFileName(for version: SourceVersion?) -> String {
        if let url = version.flatMap({ URL(string: $0.downloadURL) }) ?? displayDownloadURL {
            let last = url.lastPathComponent
            if last.lowercased().hasSuffix(".ipa") { return last }
        }
        let safeName = name.replacingOccurrences(of: "/", with: "-")
        return "\(safeName)-\(version?.version ?? displayVersion).ipa"
    }
}

struct AltSource: Decodable {
    let name: String
    let identifier: String?
    let subtitle: String?
    let description: String?
    let website: String?
    let iconURL: String?
    let tintColor: String?
    let sourceURL: String?
    let apps: [SourceApp]
}

struct SubscribedSource: Codable, Identifiable, Equatable {
    var id: String { url }
    let url: String
    let addedAt: Date

    init(url: String, addedAt: Date = Date()) {
        self.url = url
        self.addedAt = addedAt
    }
}

struct LoadedSource: Identifiable {
    var id: String { subscription.url }
    let subscription: SubscribedSource
    var source: AltSource?
    var errorMessage: String?
    var isLoading: Bool = false
    /// When the displayed content was fetched from the network (cache write time).
    var lastFetchedAt: Date?

    var displayName: String {
        source?.name ?? URL(string: subscription.url)?.host ?? subscription.url
    }
}
