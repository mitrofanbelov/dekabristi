import SaveCore
import SwiftUI
import UniformTypeIdentifiers

struct LibraryScreen: View {
    @ObservedObject var controller: AppController
    @ObservedObject private var coordinator: SyncCoordinator
    @ObservedObject private var monitor: ConnectivityMonitor

    @State private var isShowingAddLinkSheet = false
    @State private var isShowingFileImporter = false

    init(controller: AppController) {
        self.controller = controller
        self.coordinator = controller.syncCoordinator
        self.monitor = controller.connectivityMonitor
    }

    var body: some View {
        NavigationStack {
            List(coordinator.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title ?? "Untitled")
                        .font(.headline)

                    if let sourceURL = item.sourceURL {
                        Text(sourceURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }

                    HStack {
                        Text(item.kind.rawValue.capitalized)
                        Text(item.status.rawValue.capitalized)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
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
                ConnectionStatusBanner(status: monitor.status)
            }
        }
        .sheet(isPresented: $isShowingAddLinkSheet) {
            AddLinkSheet(controller: controller)
        }
        .fileImporter(
            isPresented: $isShowingFileImporter,
            allowedContentTypes: [.data, .item],
            allowsMultipleSelection: false
        ) { result in
            guard let selectedURL = try? result.get().first else { return }
            Task {
                await controller.importFile(from: selectedURL, title: selectedURL.lastPathComponent)
            }
        }
        .task {
            await controller.refreshNow()
        }
    }

    private var toolbarPlacement: ToolbarItemPlacement {
#if os(macOS)
        .primaryAction
#else
        .topBarTrailing
#endif
    }
}
