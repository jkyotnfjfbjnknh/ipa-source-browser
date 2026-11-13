import SwiftUI

struct ContentView: View {
    @StateObject private var store = SourceStore()
    @State private var searchText = ""
    @State private var collapsedSources: Set<String> = []
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
            .navigationTitle("IPA 源商店")
            .searchable(text: $searchText, prompt: "搜索应用")
            .toolbar {
                ToolbarItemGroup(placement: .navigationBarTrailing) {
                    Button {
                        Task { await store.refreshAll() }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
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

    private var sourceList: some View {
        List {
            ForEach(store.loaded) { loaded in
                Section {
                    if !isCollapsed(loaded) {
                        sectionBody(for: loaded)
                    }
                } header: {
                    sourceHeader(for: loaded)
                }
            }
        }
        .listStyle(.insetGrouped)
        .animation(.easeInOut(duration: 0.2), value: collapsedSources)
    }

    private func sourceHeader(for loaded: LoadedSource) -> some View {
        Button {
            toggle(loaded.id)
        } label: {
            HStack(spacing: 10) {
                AppIconView(urlString: loaded.source?.iconURL, name: loaded.displayName, size: 30)
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
                } else {
                    Image(systemName: isCollapsed(loaded) ? "chevron.right" : "chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func headerSubtitle(for loaded: LoadedSource) -> String {
        if loaded.isLoading { return "正在刷新…" }
        if loaded.errorMessage != nil { return "加载失败，点开看详情" }
        if let source = loaded.source {
            return "\(filteredApps(in: source).count) 个应用"
        }
        return loaded.subscription.url
    }

    @ViewBuilder
    private func sectionBody(for loaded: LoadedSource) -> some View {
        if let error = loaded.errorMessage, loaded.source == nil {
            VStack(alignment: .leading, spacing: 8) {
                Text("这个源没拉下来").font(.subheadline.weight(.medium))
                Text(error).font(.caption).foregroundStyle(.secondary)
                Button("重试") {
                    Task { await store.refresh(loaded.subscription) }
                }
                .font(.subheadline)
            }
            .padding(.vertical, 4)
        } else if let source = loaded.source {
            let apps = filteredApps(in: source)
            if apps.isEmpty {
                Text(searchText.isEmpty ? "这个源里暂时没有应用" : "没有匹配「\(searchText)」的应用")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(apps) { app in
                    NavigationLink {
                        AppDetailView(app: app, sourceName: source.name)
                    } label: {
                        AppCardView(app: app)
                    }
                }
            }
        } else {
            HStack {
                ProgressView()
                Text("正在加载…").foregroundStyle(.secondary)
            }
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

    private func isCollapsed(_ loaded: LoadedSource) -> Bool {
        collapsedSources.contains(loaded.id)
    }

    private func toggle(_ id: String) {
        if collapsedSources.contains(id) {
            collapsedSources.remove(id)
        } else {
            collapsedSources.insert(id)
        }
    }
}
