import Foundation

class SessionManager {
    static let shared = SessionManager()
    private let userIdKey = "loggedInUserId"
    private let profileCompleteKey = "profileComplete"

    var isLoggedIn: Bool { UserDefaults.standard.string(forKey: userIdKey) != nil }
    var profileComplete: Bool {
        get { UserDefaults.standard.bool(forKey: profileCompleteKey) }
        set { UserDefaults.standard.set(newValue, forKey: profileCompleteKey) }
    }

    var userId: String? { UserDefaults.standard.string(forKey: userIdKey) }

    func login(userId: String, profileComplete: Bool) {
        UserDefaults.standard.set(userId, forKey: userIdKey)
        self.profileComplete = profileComplete
    }

    func logout() {
        UserDefaults.standard.removeObject(forKey: userIdKey)
        UserDefaults.standard.removeObject(forKey: profileCompleteKey)
    }
}
