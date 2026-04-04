import SwiftUI

struct AddLinkSheet: View {
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var controller: AppController
    @State private var title = ""
    @State private var urlString = ""

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
                            await controller.addLink(
                                url: urlString,
                                title: title.isEmpty ? nil : title
                            )
                            dismiss()
                        }
                    }
                    .disabled(urlString.isEmpty)
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
