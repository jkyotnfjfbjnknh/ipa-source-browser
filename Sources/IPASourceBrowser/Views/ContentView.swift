import SwiftUI

struct ContentView: View {
    @StateObject private var store = SourceStore()
    @State private var searchText = ""
    /// Expansion state per source. Groups are built as a Section with a
    /// tappable header row (not a DisclosureGroup) so the header's swipe
    /// action stays on the header row only and never leaks onto app rows.
    @State private var expansion: [String: Bool] = [:]
    @State private var showManage = false

    var body: some View {
        NavigationStack {
            Group {
                if store.loaded.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "tray")
                            .font(.system(size: 44))
                            .foregroundStyle(.secondary)
                        Text("还没有订阅源").font(.title3.bold())
                        Text("点右上角 + 添加一个 AltStore / SideStore 格式的源。")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                } else {
                    sourceList
                }
            }
            .safeAreaInset(edge: .bottom) {
                Text("IPA 源商店 · 版本 \(Self.appVersion)")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(.bar)
            }
            .navigationTitle("IPA 源商店")
            .searchable(text: $searchText, prompt: "搜索应用")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        showManage = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showManage) {
                ManageSourcesView(store: store)
            }
            .refreshable {
                await store.refreshAll()
            }
        }
    }

    static var appVersion: String {
        let info = Bundle.main.infoDictionary
        let short = info?["CFBundleShortVersionString"] as? String ?? "?"
        let build = info?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    private var sourceList: some View {
        List {
            ForEach(store.loaded) { loaded in
                Section {
                    sourceHeaderRow(for: loaded)
                    if isExpanded(loaded.id) {
                        sectionBody(for: loaded)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        // Real Sections get the system's generous inter-section spacing;
        // tighten it back to the compact gap the groups had before.
        .listSectionSpacing(16)
    }

    /// Groups start collapsed.
    private func isExpanded(_ id: String) -> Bool {
        expansion[id] ?? false
    }

    /// The group's header row: tapping toggles expansion; swiping left
    /// reveals a Refresh action for just this source. The swipe action is
    /// attached to this row only, so app rows below never show it.
    private func sourceHeaderRow(for loaded: LoadedSource) -> some View {
        Button {
            withAnimation {
                expansion[loaded.id] = !isExpanded(loaded.id)
            }
        } label: {
            HStack(spacing: 10) {
                sourceHeader(for: loaded)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tertiary)
                    .rotationEffect(.degrees(isExpanded(loaded.id) ? 90 : 0))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .swipeActions(edge: .trailing) {
            Button {
                Task { await store.refresh(loaded.subscription) }
            } label: {
                Label("刷新", systemImage: "arrow.clockwise")
            }
            .tint(.blue)
        }
    }

    private func sourceHeader(for loaded: LoadedSource) -> some View {
        HStack(spacing: 10) {
            AppIconView(urlString: loaded.source?.iconURL, name: loaded.displayName, size: 30, cacheSourceURL: loaded.subscription.url)
            VStack(alignment: .leading, spacing: 1) {
                Text(loaded.displayName)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .textCase(nil)
                Text(headerSubtitle(for: loaded))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .textCase(nil)
            }
            Spacer()
            if loaded.isLoading {
                ProgressView()
            }
        }
        .padding(.vertical, 4)
    }

    private func headerSubtitle(for loaded: LoadedSource) -> String {
        if loaded.isLoading { return "正在刷新…" }
        if let source = loaded.source {
            var text = "\(filteredApps(in: source).count) 个应用"
            if let fetchedAt = loaded.lastFetchedAt {
                let formatter = DateFormatter()
                formatter.dateFormat = "M月d日 HH:mm"
                text += " · 缓存于 \(formatter.string(from: fetchedAt))"
            }
            return text
        }
        if loaded.errorMessage != nil { return "拉取失败，展开看详情" }
        return "尚未拉取"
    }

    @ViewBuilder
    private func sectionBody(for loaded: LoadedSource) -> some View {
        if let source = loaded.source {
            if let error = loaded.errorMessage {
                Text("刷新失败（\(error)），下面是本地缓存的内容")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            let apps = filteredApps(in: source)
            if apps.isEmpty {
                Text(searchText.isEmpty ? "这个源里暂时没有应用" : "没有匹配「\(searchText)」的应用")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(apps) { app in
                    NavigationLink {
                        AppDetailView(app: app, sourceName: source.name, sourceID: loaded.subscription.url)
                    } label: {
                        AppCardView(app: app, sourceID: loaded.subscription.url)
                    }
                    // Pull the app icon as far left as the list allows.
                    .listRowInsets(EdgeInsets(top: 2, leading: 8, bottom: 2, trailing: 8))
                }
            }
        } else if loaded.isLoading {
            HStack {
                ProgressView()
                Text("正在拉取…").foregroundStyle(.secondary)
            }
        } else if let error = loaded.errorMessage {
            VStack(alignment: .leading, spacing: 8) {
                Text("这个源没拉下来").font(.subheadline.weight(.medium))
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button("重试") {
                    Task { await store.refresh(loaded.subscription) }
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        } else {
            VStack(alignment: .leading, spacing: 8) {
                Text("本地还没有这个源的缓存").font(.subheadline.weight(.medium))
                Text(loaded.subscription.url)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("拉取这个源") {
                    Task { await store.refresh(loaded.subscription) }
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        }
    }

    private func filteredApps(in source: AltSource) -> [SourceApp] {
        let query = searchText.trimmingCharacters(in: .whitespaces).lowercased()
        guard !query.isEmpty else { return source.apps }
        return source.apps.filter {
            $0.name.lowercased().contains(query)
                || ($0.developerName?.lowercased().contains(query) ?? false)
                || ($0.subtitle?.lowercased().contains(query) ?? false)
        }
    }
}
