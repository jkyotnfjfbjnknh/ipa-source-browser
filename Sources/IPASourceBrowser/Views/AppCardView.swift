import SwiftUI

/// SideStore-style app row: icon, name, subtitle, and a GET-style pill.
struct AppCardView: View {
    let app: SourceApp
    /// Subscription URL of the owning source; decides the icon cache group.
    var sourceID: String?

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(urlString: app.iconURL, name: app.name, size: 56, cacheSourceURL: sourceID)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.name)
                    .font(.headline)
                    .lineLimit(1)
                Text(app.subtitle ?? app.developerName ?? "")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Text(metaLine)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }

    private var metaLine: String {
        var parts: [String] = []
        if app.displayVersion != "-" { parts.append("v\(app.displayVersion)") }
        let size = formatBytes(app.displaySize)
        if !size.isEmpty { parts.append(size) }
        return parts.joined(separator: " · ")
    }
}
