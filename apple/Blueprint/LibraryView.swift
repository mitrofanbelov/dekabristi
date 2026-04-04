import SwiftUI
import SaveCore

public struct LibraryView: View {
    @ObservedObject var coordinator: SyncCoordinator

    public init(coordinator: SyncCoordinator) {
        self.coordinator = coordinator
    }

    public var body: some View {
        NavigationStack {
            List(coordinator.items) { item in
                VStack(alignment: .leading, spacing: 6) {
                    Text(item.title ?? "Untitled")
                        .font(.headline)
                    if let sourceURL = item.sourceURL {
                        Text(sourceURL)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text(item.kind.rawValue.capitalized)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .overlay {
                if coordinator.items.isEmpty {
                    ContentUnavailableView(
                        "No Saved Content Yet",
                        systemImage: "tray",
                        description: Text("New links and files will appear here once they are synced.")
                    )
                }
            }
            .toolbar {
                Button("Refresh") {
                    Task {
                        await coordinator.refreshFromLaunchOrManualTrigger()
                    }
                }
            }
            .navigationTitle("Library")
        }
    }
}
