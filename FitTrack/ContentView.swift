import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var appState: AppState = .loading
    @State private var setupVm: ProfileViewModel?

    private enum AppState {
        case loading, login, register, setup, main
    }

    var body: some View {
        Group {
            switch appState {
            case .loading:
                Color.darkBg.ignoresSafeArea()
                    .onAppear { resolveState() }

            case .login:
                LoginView(
                    onLoginSuccess: { handlePostLogin() },
                    onNavigateRegister: { appState = .register }
                )

            case .register:
                RegisterView(
                    onRegisterSuccess: { navigateToSetup() },
                    onNavigateLogin: { appState = .login }
                )

            case .setup:
                if let vm = setupVm {
                    SetupView(profileVm: vm, onSetupComplete: { appState = .main })
                }

            case .main:
                MainTabView(onLogout: { handleLogout() })
            }
        }
        .preferredColorScheme(.dark)
    }

    private func resolveState() {
        let session = SessionManager.shared
        guard session.isLoggedIn, let userId = session.userId else {
            appState = .login
            return
        }
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
        let user = try? modelContext.fetch(descriptor).first
        if let user, !user.name.isEmpty {
            appState = .main
        } else if user != nil {
            navigateToSetup()
        } else {
            session.logout()
            appState = .login
        }
    }

    private func handlePostLogin() {
        let session = SessionManager.shared
        guard let userId = session.userId else { return }
        let descriptor = FetchDescriptor<User>(predicate: #Predicate { $0.id == userId })
        let user = try? modelContext.fetch(descriptor).first
        if user?.name.isEmpty == false {
            appState = .main
        } else {
            navigateToSetup()
        }
    }

    private func navigateToSetup() {
        setupVm = ProfileViewModel(modelContext: modelContext)
        appState = .setup
    }

    private func handleLogout() {
        setupVm = nil
        appState = .login
    }
}
