import SwiftData
import Foundation

@Observable
class AuthViewModel {
    var isLoading = false
    var error = ""

    private let repo: UserRepository
    private let session = SessionManager.shared

    init(modelContext: ModelContext) {
        self.repo = UserRepository(modelContext: modelContext)
    }

    func login(username: String, password: String) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()
        guard !trimmed.isEmpty, !password.isEmpty else {
            error = "Please fill in all fields"; return false
        }
        isLoading = true
        error = ""
        defer { isLoading = false }
        do {
            guard let user = try repo.findUser(username: trimmed) else {
                // Use a generic message — don't reveal whether the username exists (OWASP A2).
                error = "Invalid username or password"; return false
            }
            guard user.passwordHash == User.hash(password) else {
                error = "Invalid username or password"; return false
            }
            session.login(userId: user.id, profileComplete: user.profileComplete)
            return true
        } catch {
            // Surface a generic message; log internally if needed.
            self.error = "Login failed — please try again"; return false
        }
    }

    func register(username: String, password: String, confirm: String) async -> Bool {
        let trimmed = username.trimmingCharacters(in: .whitespaces).lowercased()

        // Username rules: 3–30 chars, alphanumeric + underscore only.
        guard !trimmed.isEmpty else { error = "Please fill in all fields"; return false }
        guard trimmed.count >= 3 else { error = "Username must be at least 3 characters"; return false }
        guard trimmed.count <= 30 else { error = "Username must be 30 characters or fewer"; return false }
        guard trimmed.range(of: #"^[a-z0-9_]+$"#, options: .regularExpression) != nil else {
            error = "Username may only contain letters, numbers, and underscores"; return false
        }

        // Password rules: 8–128 chars.
        guard !password.isEmpty else { error = "Please fill in all fields"; return false }
        guard password == confirm else { error = "Passwords do not match"; return false }
        guard password.count >= 8 else { error = "Password must be at least 8 characters"; return false }
        guard password.count <= 128 else { error = "Password is too long"; return false }

        isLoading = true
        error = ""
        defer { isLoading = false }
        do {
            let user = try repo.createUser(username: trimmed, password: password)
            session.login(userId: user.id, profileComplete: false)
            // Passwords are never stored in Keychain — only their SHA-256 hash is stored
            // in SwiftData. Session state is managed by SessionManager.
            return true
        } catch {
            self.error = error.localizedDescription; return false
        }
    }

    func clearError() { error = "" }
}
