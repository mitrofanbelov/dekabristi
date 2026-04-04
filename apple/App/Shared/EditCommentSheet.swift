import SaveCore
import SwiftUI

struct EditCommentSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var controller: AppController
    let item: RemoteItem

    @State private var comment: String
    @State private var validationMessage: String?

    init(controller: AppController, item: RemoteItem) {
        self.controller = controller
        self.item = item
        _comment = State(initialValue: item.comment ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                if let title = item.title, !title.isEmpty {
                    Section("Item") {
                        Text(title)
                            .font(.body)
                    }
                }

                Section("Comment") {
                    TextEditor(text: $comment)
                        .frame(minHeight: 140)

                    Text("Leave this field empty if you want to remove the comment.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let validationMessage {
                        Text(validationMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle(item.comment == nil ? "Add Comment" : "Edit Comment")
            .toolbar {
                ToolbarItem(placement: cancelPlacement) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: confirmPlacement) {
                    Button("Save") {
                        Task {
                            validationMessage = nil
                            let didSave = await controller.saveComment(for: item, comment: comment)
                            if didSave {
                                dismiss()
                            } else {
                                validationMessage = controller.syncCoordinator.lastErrorMessage
                                    ?? "The comment could not be saved."
                            }
                        }
                    }
                }
            }
        }
    }

    private var cancelPlacement: ToolbarItemPlacement {
#if os(macOS)
        .cancellationAction
#else
        .topBarLeading
#endif
    }

    private var confirmPlacement: ToolbarItemPlacement {
#if os(macOS)
        .confirmationAction
#else
        .topBarTrailing
#endif
    }
}
