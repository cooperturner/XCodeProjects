import SwiftUI

struct RegisterView: View {
    @Environment(\.modelContext) var modelContext
    @State private var vm: AuthViewModel?
    @State private var username = ""
    @State private var password = ""
    @State private var confirm = ""
    var onRegisterSuccess: () -> Void
    var onNavigateLogin: () -> Void

    var body: some View {
        let authVm = vm ?? { let v = AuthViewModel(modelContext: modelContext); DispatchQueue.main.async { vm = v }; return v }()

        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Create Account").font(.largeTitle).bold().foregroundStyle(Color.textPrimary)
                    Text("Join FitTrack today").foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 60)

                VStack(spacing: 12) {
                    FitTextField(label: "Username", text: $username)
                    FitTextField(label: "Password", text: $password, isSecure: true)
                    FitTextField(label: "Confirm Password", text: $confirm, isSecure: true)

                    if !authVm.error.isEmpty {
                        Text(authVm.error).foregroundStyle(Color.fitRed).font(.system(size: 13))
                    }

                    FitButton(title: "Register", action: {
                        Task {
                            if await authVm.register(username: username, password: password, confirm: confirm) {
                                onRegisterSuccess()
                            }
                        }
                    }, isLoading: authVm.isLoading, enabled: !username.isEmpty && !password.isEmpty && !confirm.isEmpty)
                }

                Button("Already have an account? Log In") { onNavigateLogin() }
                    .foregroundStyle(Color.fitGreen)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.darkBg)
        .scrollBounceBehavior(.basedOnSize)
    }
}
