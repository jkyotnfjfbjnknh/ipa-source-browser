import SwiftUI

struct ManageSourcesView: View {
    @ObservedObject var store: SourceStore
    @Environment(\.dismiss) private var dismiss

    @State private var newURL = ""
    @State private var isAdding = false
    @State private var addError: String?
    @State private var showFolderPicker = false
    @State private var folderVersion = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("https://example.com/source.json", text: $newURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                    Button {
                        Task { await add() }
                    } label: {
                        HStack {
                            if isAdding { ProgressView() }
                            Text(isAdding ? "正在拉取验证…" : "添加源")
                        }
                    }
                    .disabled(newURL.trimmingCharacters(in: .whitespaces).isEmpty || isAdding)
                    if let addError {
                        Text(addError).font(.footnote).foregroundStyle(.red)
                    }
                } header: {
                    Text("订阅新源")
                } footer: {
                    Text("支持 AltStore / SideStore 格式（JSON）。添加前会先拉取一次验证格式。")
                }

                Section("推荐源（点一下填入）") {
                    ForEach(SourceStore.defaultSourceURLs, id: \.self) { url in
                        Button(url) { newURL = url }
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                }

                Section {
                    ForEach(store.subscriptions) { subscription in
                        VStack(alignment: .leading, spacing: 3) {
                            Text(store.loaded.first(where: { $0.id == subscription.url })?.displayName ?? subscription.url)
                                .font(.body.weight(.medium))
                                .lineLimit(1)
                            Text(subscription.url)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            store.removeSource(id: store.subscriptions[index].url)
                        }
                    }
                    .onMove { source, destination in
                        store.moveSource(from: source, to: destination)
                    }
                } header: {
                    Text("已订阅（\(store.subscriptions.count)）")
                } footer: {
                    Text("左滑可取消订阅，拖动可排序。")
                }

                Section {
                    let _ = folderVersion
                    if let name = DownloadsFolderManager.shared.customFolderName {
                        LabeledContent("当前下载目录", value: "文件 App · \(name)")
                        Button("更改下载目录") { showFolderPicker = true }
                        Button("恢复默认目录", role: .destructive) {
                            DownloadsFolderManager.shared.clearBookmark()
                            folderVersion += 1
                        }
                    } else {
                        Button("指定「文件」App 里的下载目录") { showFolderPicker = true }
                    }
                } header: {
                    Text("下载位置")
                } footer: {
                    Text("指定后，从详情页下载的 IPA 会直接存进你在「文件」App 里选的文件夹（通常选「下载」）。未指定时存到 文件 > 我的 iPhone > IPA 源商店 > Downloads。")
                }
            }
            .navigationTitle("管理源")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完成") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarLeading) {
                    EditButton()
                }
            }
            .sheet(isPresented: $showFolderPicker) {
                FolderPicker { url in
                    DownloadsFolderManager.shared.saveBookmark(for: url)
                    folderVersion += 1
                    showFolderPicker = false
                }
            }
        }
    }

    private func add() async {
        isAdding = true
        addError = nil
        do {
            try await store.addSource(urlString: newURL)
            newURL = ""
        } catch {
            addError = error.localizedDescription
        }
        isAdding = false
    }
}
