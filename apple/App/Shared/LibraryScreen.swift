import SaveCore
import SwiftUI
import UniformTypeIdentifiers

struct LibraryScreen: View {
    @Environment(\.openURL) private var openURL

    @ObservedObject var controller: AppController
    @ObservedObject private var coordinator: SyncCoordinator
    @ObservedObject private var monitor: ConnectivityMonitor

    @State private var isShowingAddLinkSheet = false
    @State private var isShowingFileImporter = false
    @State private var itemPendingCommentEdit: RemoteItem?
    @State private var itemPendingDeletion: RemoteItem?

    init(controller: AppController) {
        self.controller = controller
        self.coordinator = controller.syncCoordinator
        self.monitor = controller.connectivityMonitor
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(coordinator.items) { item in
                    VStack(alignment: .leading, spacing: 10) {
                        Button {
                            performPrimaryAction(for: item)
                        } label: {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(item.title ?? fallbackTitle(for: item))
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                if let detailLine = detailLine(for: item) {
                                    Text(detailLine)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .textSelection(.enabled)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if let comment = item.comment, !comment.isEmpty {
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "text.bubble")
                                    .foregroundStyle(.secondary)
                                Text(comment)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        HStack(spacing: 8) {
                            Button(item.kind == .link ? "Open Link" : "Download") {
                                performPrimaryAction(for: item)
                            }

                            Button(item.comment == nil ? "Add Comment" : "Edit Comment") {
                                itemPendingCommentEdit = item
                            }

                            Button("Delete", role: .destructive) {
                                itemPendingDeletion = item
                            }
                        }
                        .buttonStyle(.borderless)
                        .font(.caption)

                        HStack {
                            Text(item.kind.rawValue.capitalized)
                            Text(item.status.rawValue.capitalized)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 6)
                }
            }
            .overlay {
                if coordinator.items.isEmpty {
                    ContentUnavailableView(
                        "No Saved Content Yet",
                        systemImage: "tray",
                        description: Text("Save a link or import a file to start testing sync.")
                    )
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: toolbarPlacement) {
                    Button("Add Link") {
                        isShowingAddLinkSheet = true
                    }

                    Button("Import File") {
                        isShowingFileImporter = true
                    }

                    Button("Refresh") {
                        Task {
                            await controller.refreshNow()
                        }
                    }
                }
            }
            .navigationTitle("Library")
            .safeAreaInset(edge: .top) {
                VStack(spacing: 0) {
                    ConnectionStatusBanner(status: monitor.status)

                    if let lastErrorMessage = coordinator.lastErrorMessage {
                        BannerRow(
                            message: lastErrorMessage,
                            iconName: "exclamationmark.triangle.fill",
                            backgroundColor: Color.red.opacity(0.9)
                        ) {
                            coordinator.clearErrorMessage()
                        }
                    }

                    if let noticeMessage = controller.noticeMessage {
                        BannerRow(
                            message: noticeMessage,
                            iconName: "checkmark.circle.fill",
                            backgroundColor: Color.green.opacity(0.9)
                        ) {
                            controller.clearNoticeMessage()
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $isShowingAddLinkSheet) {
            AddLinkSheet(controller: controller)
        }
        .sheet(item: $itemPendingCommentEdit) { item in
            EditCommentSheet(controller: controller, item: item)
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            do {
                guard let selectedURL = try result.get().first else {
                    coordinator.setErrorMessage("No file was selected.")
                    return
                }

                Task {
                    _ = await controller.importFile(
                        from: selectedURL,
                        title: selectedURL.lastPathComponent
                    )
                }
            } catch {
                coordinator.setErrorMessage(error.localizedDescription)
            }
        }
        .task {
            await controller.refreshNow()
        }
        .alert(
            "Delete this item?",
            isPresented: Binding(
                get: { itemPendingDeletion != nil },
                set: { newValue in
                    if !newValue {
                        itemPendingDeletion = nil
                    }
                }
            ),
            presenting: itemPendingDeletion
        ) { item in
            Button("Delete", role: .destructive) {
                Task {
                    _ = await controller.delete(item)
                }
                itemPendingDeletion = nil
            }

            Button("Cancel", role: .cancel) {
                itemPendingDeletion = nil
            }
        } message: { item in
            let itemName = item.title ?? fallbackTitle(for: item)
            Text("\"\(itemName)\" will be removed from all your devices.")
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .primaryAction
#else
        .topBarTrailing
#endif
    }

    private func fallbackTitle(for item: RemoteItem) -> String {
        if item.kind == .file, let attachment = item.attachments.first {
            return attachment.originalFilename
        }

        return "Untitled"
    }

    private func detailLine(for item: RemoteItem) -> String? {
        if let sourceURL = item.sourceURL {
            return sourceURL
        }

        return item.attachments.first?.originalFilename
    }

    private func performPrimaryAction(for item: RemoteItem) {
        switch item.kind {
        case .link:
            guard let sourceURL = item.sourceURL, let url = URL(string: sourceURL) else {
                coordinator.setErrorMessage("This link is missing a valid URL.")
                return
            }
            openURL(url)
        case .file:
            Task {
                _ = await controller.downloadFile(for: item)
            }
        }
    }
}

private struct BannerRow: View {
    let message: String
    let iconName: String
    let backgroundColor: Color
    let onDismiss: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: iconName)
                .foregroundStyle(.white)
            Text(message)
                .font(.caption)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .leading)
            Button("Dismiss") {
                onDismiss()
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white.opacity(0.9))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(backgroundColor)
    }
}
