import SwiftData
import Foundation
import CryptoKit

@Model
class User {
    var id: String
    var username: String
    var passwordHash: String
    var name: String
    var age: Int
    var weightKg: Float
    var heightCm: Int
    var gender: String
    var goal: String
    var dailyCalorieTarget: Int
    var claudeApiKey: String
    var profileComplete: Bool
    var dietaryPreferences: String
    var dislikedFoods: String
    var sport: String

    init(username: String, passwordHash: String) {
        self.id = UUID().uuidString
        self.username = username
        self.passwordHash = passwordHash
        self.name = ""
        self.age = 0
        self.weightKg = 0
        self.heightCm = 0
        self.gender = "male"
        self.goal = "maintain"
        self.dailyCalorieTarget = 2000
        self.claudeApiKey = ""
        self.profileComplete = false
        self.dietaryPreferences = ""
        self.dislikedFoods = ""
        self.sport = ""
    }

    // MARK: - API Key (Keychain-backed, never stored in SwiftData)

    /// Reads the Claude API key from the device Keychain.
    /// The stored `claudeApiKey` property is kept only as a migration target;
    /// ProfileViewModel clears it on first load and all new saves go to Keychain.
    var apiKey: String {
        KeychainHelper.load(key: "apikey_\(id)") ?? ""
    }

    static func hash(_ password: String) -> String {
        let digest = SHA256.hash(data: Data(password.utf8))
        return digest.compactMap { String(format: "%02x", $0) }.joined()
    }

    static func calculateCalorieTarget(weight: Float, height: Int, age: Int, gender: String, goal: String) -> Int {
        let bmr: Double
        if gender == "male" {
            bmr = 10 * Double(weight) + 6.25 * Double(height) - 5 * Double(age) + 5
        } else {
            bmr = 10 * Double(weight) + 6.25 * Double(height) - 5 * Double(age) - 161
        }
        let tdee = bmr * 1.55
        return switch goal {
        case "gain_muscle": Int(tdee + 300)
        case "lose_weight": Int(max(1200, tdee - 500))
        default: Int(tdee)
        }
    }
}
