import SwiftUI

struct LoginView: View {
    @Environment(\.modelContext) var modelContext
    @State private var vm: AuthViewModel?
    @State private var username = ""
    @State private var password = ""
    var onLoginSuccess: () -> Void
    var onNavigateRegister: () -> Void

    var body: some View {
        let authVm = vm ?? { let v = AuthViewModel(modelContext: modelContext); DispatchQueue.main.async { vm = v }; return v }()

        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "flame.fill").font(.system(size: 56)).foregroundStyle(Color.fitGreen)
                    Text("FitTrack").font(.largeTitle).bold().foregroundStyle(Color.textPrimary)
                    Text("Your AI-powered fitness companion").foregroundStyle(Color.textSecondary)
                }
                .padding(.top, 60)

                VStack(spacing: 12) {
                    FitTextField(label: "Username", text: $username)
                    FitTextField(label: "Password", text: $password, isSecure: true)

                    if !authVm.error.isEmpty {
                        Text(authVm.error).foregroundStyle(Color.fitRed).font(.system(size: 13))
                    }

                    FitButton(title: "Log In", action: {
                        Task {
                            if await authVm.login(username: username, password: password) {
                                onLoginSuccess()
                            }
                        }
                    }, isLoading: authVm.isLoading, enabled: !username.isEmpty && !password.isEmpty)
                }

                Button("Don't have an account? Register") {
                    authVm.clearError()
                    onNavigateRegister()
                }
                .foregroundStyle(Color.fitGreen)
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .background(Color.darkBg)
        .scrollBounceBehavior(.basedOnSize)
        .onAppear {
            // Passwords must never be pre-filled from local storage.
            // Username hint is intentionally omitted to avoid username enumeration.
        }
    }
}
