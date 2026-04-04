import SwiftUI

struct LoginScreen: View {
    enum Mode: String, CaseIterable, Identifiable {
        case signIn = "Sign In"
        case register = "Register"

        var id: String { rawValue }
    }

    @ObservedObject var controller: AppController
    @State private var mode: Mode = .signIn
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        NavigationStack {
            Form {
                Picker("Mode", selection: $mode) {
                    ForEach(Mode.allCases) { value in
                        Text(value.rawValue).tag(value)
                    }
                }
                .pickerStyle(.segmented)

#if os(iOS)
                TextField("Email", text: $email)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.emailAddress)
#else
                TextField("Email", text: $email)
#endif

                SecureField("Password", text: $password)

                Button(mode.rawValue) {
                    Task {
                        if mode == .signIn {
                            await controller.signIn(email: email, password: password)
                        } else {
                            await controller.register(email: email, password: password)
                        }
                    }
                }
                .disabled(email.isEmpty || password.count < 8 || controller.isAuthenticating)

                if let authErrorMessage = controller.authErrorMessage {
                    Text(authErrorMessage)
                        .foregroundStyle(.red)
                }
            }
            .navigationTitle("Dekabristi")
        }
    }
}
