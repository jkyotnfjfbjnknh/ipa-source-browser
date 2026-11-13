import SwiftUI
import UIKit

extension Color {
    /// Parses AltStore tint colors, which appear both as "018084" and "#21486b".
    init?(hexString: String?) {
        guard var hex = hexString?.trimmingCharacters(in: .whitespacesAndNewlines), !hex.isEmpty else {
            return nil
        }
        if hex.hasPrefix("#") { hex.removeFirst() }
        guard hex.count == 6, let value = UInt64(hex, radix: 16) else { return nil }
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}

func formatBytes(_ bytes: Int64?) -> String {
    guard let bytes, bytes > 0 else { return "" }
    return ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
}

func formatDateString(_ raw: String?) -> String {
    guard let raw else { return "" }
    let iso = ISO8601DateFormatter()
    iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    if let date = iso.date(from: raw) ?? ISO8601DateFormatter().date(from: raw) {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }
    return String(raw.prefix(10))
}

/// Rounded app icon, served from the per-source local cache (see IconCache),
/// with a letter placeholder while loading or when offline with no cache.
struct AppIconView: View {
    let urlString: String?
    let name: String
    var size: CGFloat = 56
    /// Subscription URL of the source this icon belongs to; decides its cache group.
    var cacheSourceURL: String?

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                Image(uiImage: uiImage).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: size * 0.24, style: .continuous)
                .strokeBorder(Color.primary.opacity(0.08), lineWidth: 1)
        )
        .task(id: urlString) {
            uiImage = nil
            guard let urlString, let url = URL(string: urlString) else { return }
            uiImage = await IconCache.shared.loadImage(from: url, sourceURL: cacheSourceURL)
        }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondary.opacity(0.2)
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.42, weight: .semibold))
                .foregroundStyle(.secondary)
        }
    }
}

/// Full-bleed remote image (screenshots) backed by the same per-source cache.
struct CachedRemoteImageView: View {
    let url: URL
    var cacheSourceURL: String?
    /// true: fill the frame (thumbnails); false: fit the whole image (fullscreen viewer).
    var fill: Bool = true

    @State private var uiImage: UIImage?

    var body: some View {
        Group {
            if let uiImage {
                if fill {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                } else {
                    Image(uiImage: uiImage).resizable().scaledToFit()
                }
            } else {
                Color.secondary.opacity(0.15)
            }
        }
        .task(id: url) {
            uiImage = await IconCache.shared.loadImage(from: url, sourceURL: cacheSourceURL)
        }
    }
}
