import SwiftData
import Foundation

enum ProfileSaveState { case idle, loading, saved, error(String) }

@Observable
class ProfileViewModel {
    var user: User?
    var saveState: ProfileSaveState = .idle

    private let repo: UserRepository
    private let session = SessionManager.shared

    init(modelContext: ModelContext) {
        self.repo = UserRepository(modelContext: modelContext)
        loadUser()
    }

    func loadUser() {
        guard let id = session.userId else { return }
        user = try? repo.findUser(id: id)
        // One-time migration: move API key from SwiftData (plaintext SQLite) → Keychain.
        // After migration the stored field is cleared so it is never read again.
        if let u = user, !u.claudeApiKey.isEmpty {
            KeychainHelper.save(u.claudeApiKey, key: "apikey_\(u.id)")
            u.claudeApiKey = ""
            try? repo.save()
        }
    }

    func saveProfile(name: String, age: String, weightKg: String, heightCm: String,
                     gender: String, goal: String, apiKey: String,
                     dietaryPreferences: String, dislikedFoods: String, sport: String) async {
        // Validate name.
        let trimmedName = name.trimmingCharacters(in: .whitespaces)
        guard !trimmedName.isEmpty, trimmedName.count <= 60 else {
            saveState = .error("Name must be 1–60 characters"); return
        }
        // Validate numeric fields with physiologically sensible ranges.
        guard let ageInt = Int(age), ageInt >= 10, ageInt <= 120 else {
            saveState = .error("Age must be between 10 and 120"); return
        }
        guard let weight = Float(weightKg), weight >= 20, weight <= 500 else {
            saveState = .error("Weight must be between 20 and 500 kg"); return
        }
        guard let height = Int(heightCm), height >= 50, height <= 300 else {
            saveState = .error("Height must be between 50 and 300 cm"); return
        }
        // Validate API key format if provided (must start with Anthropic's prefix).
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespaces)
        if !trimmedKey.isEmpty {
            guard trimmedKey.hasPrefix("sk-ant-"), trimmedKey.count <= 200 else {
                saveState = .error("API key appears invalid — it should start with 'sk-ant-'"); return
            }
        }
        // Length caps on freetext fields injected into AI prompts.
        guard dietaryPreferences.count <= 300 else {
            saveState = .error("Dietary preferences must be under 300 characters"); return
        }
        guard dislikedFoods.count <= 300 else {
            saveState = .error("Foods to avoid must be under 300 characters"); return
        }
        guard sport.count <= 100 else {
            saveState = .error("Sport field must be under 100 characters"); return
        }

        saveState = .loading
        guard let u = user else { saveState = .error("User not found"); return }

        u.name = name.trimmingCharacters(in: .whitespaces)
        u.age = ageInt
        u.weightKg = weight
        u.heightCm = height
        u.gender = gender
        u.goal = goal
        // Store API key in Keychain — never in the SwiftData database.
        if trimmedKey.isEmpty {
            KeychainHelper.delete(key: "apikey_\(u.id)")
        } else {
            KeychainHelper.save(trimmedKey, key: "apikey_\(u.id)")
        }
        u.claudeApiKey = "" // Keep stored field empty; apiKey computed property reads Keychain.
        u.dietaryPreferences = dietaryPreferences.trimmingCharacters(in: .whitespaces)
        u.dislikedFoods = dislikedFoods.trimmingCharacters(in: .whitespaces)
        u.sport = sport.trimmingCharacters(in: .whitespaces)
        u.dailyCalorieTarget = User.calculateCalorieTarget(weight: weight, height: height, age: ageInt, gender: gender, goal: goal)
        u.profileComplete = true

        do {
            try repo.save()
            session.profileComplete = true
            saveState = .saved
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }

    func logout(onDone: () -> Void) {
        session.logout()
        user = nil
        onDone()
    }

    func resetState() { saveState = .idle }
}
