import Foundation

@MainActor
final class SourceStore: ObservableObject {
    @Published var loaded: [LoadedSource] = []
    @Published var subscriptions: [SubscribedSource] = []

    static let defaultSourceURLs: [String] = [
        "https://apps.altstore.io/",
        "https://community-apps.sidestore.io/sidecommunity.json"
    ]

    private let storageKey = "subscriptions.v1"

    init() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([SubscribedSource].self, from: data),
           !saved.isEmpty {
            subscriptions = saved
        } else {
            subscriptions = Self.defaultSourceURLs.map { SubscribedSource(url: $0) }
            persist()
        }
        loaded = subscriptions.map { LoadedSource(subscription: $0) }
        Task { await refreshAll() }
    }

    // MARK: - Fetching

    func refreshAll() async {
        for subscription in subscriptions {
            await refresh(subscription)
        }
    }

    func refresh(_ subscription: SubscribedSource) async {
        guard let index = loaded.firstIndex(where: { $0.id == subscription.url }) else { return }
        loaded[index].isLoading = true
        loaded[index].errorMessage = nil
        do {
            let source = try await Self.fetchSource(from: subscription.url)
            loaded[index].source = source
        } catch {
            loaded[index].errorMessage = Self.friendlyError(error)
        }
        loaded[index].isLoading = false
    }

    static func fetchSource(from urlString: String) async throws -> AltSource {
        guard let url = URL(string: urlString) else {
            throw URLError(.badURL)
        }
        var request = URLRequest(url: url)
        request.setValue("IPASourceBrowser/1.0", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)
        if let http = response as? HTTPURLResponse, !(200...299).contains(http.statusCode) {
            throw NSError(domain: "SourceFetch", code: http.statusCode,
                          userInfo: [NSLocalizedDescriptionKey: "服务器返回 \(http.statusCode)"])
        }
        return try JSONDecoder().decode(AltSource.self, from: data)
    }

    static func friendlyError(_ error: Error) -> String {
        if let decoding = error as? DecodingError {
            return "源格式解析失败：\(decoding.localizedDescription)"
        }
        return error.localizedDescription
    }

    // MARK: - Subscription management

    enum AddError: LocalizedError {
        case invalidURL
        case duplicate
        case fetchFailed(String)

        var errorDescription: String? {
            switch self {
            case .invalidURL: return "请输入有效的源地址（https:// 开头）"
            case .duplicate: return "这个源已经订阅过了"
            case .fetchFailed(let message): return "拉取失败：\(message)"
            }
        }
    }

    /// Validates the feed before subscribing, so a typo fails fast with a clear message.
    func addSource(urlString raw: String) async throws {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme == "https" || url.scheme == "http" else {
            throw AddError.invalidURL
        }
        guard !subscriptions.contains(where: { $0.url == trimmed }) else {
            throw AddError.duplicate
        }
        do {
            _ = try await Self.fetchSource(from: trimmed)
        } catch {
            throw AddError.fetchFailed(Self.friendlyError(error))
        }
        let subscription = SubscribedSource(url: trimmed)
        subscriptions.append(subscription)
        loaded.append(LoadedSource(subscription: subscription))
        persist()
        await refresh(subscription)
    }

    func removeSource(id: String) {
        subscriptions.removeAll { $0.url == id }
        loaded.removeAll { $0.id == id }
        persist()
    }

    func moveSource(from source: IndexSet, to destination: Int) {
        subscriptions.move(fromOffsets: source, toOffset: destination)
        loaded = subscriptions.map { sub in
            loaded.first(where: { $0.id == sub.url }) ?? LoadedSource(subscription: sub)
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(subscriptions) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }
}
