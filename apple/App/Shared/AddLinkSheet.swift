import SwiftUI

struct AddLinkSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var controller: AppController
    @State private var title = ""
    @State private var urlString = ""
    @State private var validationMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                TextField("Title", text: $title)
#if os(iOS)
                TextField("https://example.com", text: $urlString)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
#else
                TextField("https://example.com", text: $urlString)
#endif

                Text("If you paste a link without a scheme, Dekabristi will try to save it as https://...")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let validationMessage {
                    Text(validationMessage)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Add Link")
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
                            let didSave = await controller.addLink(
                                url: urlString,
                                title: title.isEmpty ? nil : title
                            )
                            if didSave {
                                dismiss()
                            } else {
                                validationMessage = controller.syncCoordinator.lastErrorMessage ?? "Could not save the link."
                            }
                        }
                    }
                    .disabled(urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
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
