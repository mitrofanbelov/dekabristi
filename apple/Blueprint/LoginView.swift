import SwiftUI
import SaveCore

public struct LoginView: View {
    @ObservedObject var sessionViewModel: SessionViewModel
    @State private var email = ""
    @State private var password = ""

    public init(sessionViewModel: SessionViewModel) {
        self.sessionViewModel = sessionViewModel
    }

    public var body: some View {
        Form {
            TextField("Email", text: $email)
                .textInputAutocapitalization(.never)
            SecureField("Password", text: $password)

            Button("Sign In") {
                Task {
                    await sessionViewModel.login(email: email, password: password)
                }
            }
            .disabled(email.isEmpty || password.count < 8 || sessionViewModel.isBusy)

            if let errorMessage = sessionViewModel.errorMessage {
                Text(errorMessage)
                    .foregroundStyle(.red)
            }
        }
        .navigationTitle("Sign In")
    }
}
