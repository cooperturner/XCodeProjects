import Foundation
import SwiftData

@Model
class PartnerProfile {
    @Attribute(.unique) var id: String
    var userId: String
    var name: String
    var age: Int
    var weightKg: Float
    var heightCm: Int
    var gender: String
    var goal: String
    var dietaryPreferences: String
    var dislikedFoods: String
    var dailyCalorieTarget: Int

    init(userId: String) {
        self.id = UUID().uuidString
        self.userId = userId
        self.name = ""
        self.age = 0
        self.weightKg = 0
        self.heightCm = 0
        self.gender = "female"
        self.goal = "maintain"
        self.dietaryPreferences = ""
        self.dislikedFoods = ""
        self.dailyCalorieTarget = 2000
    }
}
