import SwiftUI

/// SideStore-style app row: icon, name, subtitle, and a GET-style pill.
struct AppCardView: View {
    let app: SourceApp

    var body: some View {
        HStack(spacing: 12) {
            AppIconView(urlString: app.iconURL, name: app.name, size: 56)

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

            Spacer(minLength: 4)

            Text("查看")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(Color(hexString: app.tintColor) ?? .accentColor)
                .padding(.horizontal, 14)
                .padding(.vertical, 6)
                .background((Color(hexString: app.tintColor) ?? .accentColor).opacity(0.14))
                .clipShape(Capsule())
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
