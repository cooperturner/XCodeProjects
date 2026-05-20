import SwiftData
import Foundation

@Model
class WeightEntry {
    var id: String
    var userId: String
    var date: String
    var weightKg: Float

    init(userId: String, date: String, weightKg: Float) {
        self.id = UUID().uuidString
        self.userId = userId
        self.date = date
        self.weightKg = weightKg
    }
}
