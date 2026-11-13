import SwiftUI

/// Fullscreen screenshot viewer.
/// - Swipe left/right to move between images (paged TabView)
/// - Swipe up/down, or tap the X at the top right, to close
struct ScreenshotViewer: View {
    let urls: [URL]
    var cacheSourceURL: String?

    @State private var index: Int
    @Environment(\.dismiss) private var dismiss

    init(urls: [URL], startIndex: Int, cacheSourceURL: String?) {
        self.urls = urls
        self.cacheSourceURL = cacheSourceURL
        _index = State(initialValue: min(max(startIndex, 0), max(urls.count - 1, 0)))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            TabView(selection: $index) {
                ForEach(Array(urls.enumerated()), id: \.offset) { page, url in
                    CachedRemoteImageView(url: url, cacheSourceURL: cacheSourceURL, fill: false)
                        .padding(.horizontal, 8)
                        .tag(page)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            // Vertical swipe dismiss. Kept simultaneous so horizontal paging
            // in the TabView keeps working; only a mostly-vertical drag with
            // enough travel closes the viewer.
            .simultaneousGesture(
                DragGesture(minimumDistance: 24)
                    .onEnded { value in
                        let vertical = value.translation.height
                        let horizontal = value.translation.width
                        if abs(vertical) > 90 && abs(vertical) > abs(horizontal) * 1.6 {
                            dismiss()
                        }
                    }
            )

            VStack {
                HStack {
                    Spacer()
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(Color.white.opacity(0.18))
                            .clipShape(Circle())
                    }
                }
                Spacer()
                if urls.count > 1 {
                    Text("\(index + 1) / \(urls.count)")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.15))
                        .clipShape(Capsule())
                }
            }
            .padding()
        }
    }
}
