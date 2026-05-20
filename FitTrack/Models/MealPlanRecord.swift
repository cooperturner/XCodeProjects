import SwiftData
import Foundation

@Model
class MealPlanRecord {
    var id: String
    var userId: String
    var weekStartDate: String
    var planText: String

    init(userId: String, weekStartDate: String, planText: String) {
        self.id = UUID().uuidString
        self.userId = userId
        self.weekStartDate = weekStartDate
        self.planText = planText
    }
}
