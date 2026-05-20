import SwiftData
import Foundation

@Model
class FoodLog {
    var id: String
    var userId: String
    var date: String
    var foodName: String
    var calories: Int
    var proteinG: Float
    var carbsG: Float
    var fatG: Float
    var mealType: String

    init(userId: String, date: String, foodName: String, calories: Int,
         proteinG: Float = 0, carbsG: Float = 0, fatG: Float = 0, mealType: String = "snack") {
        self.id = UUID().uuidString
        self.userId = userId
        self.date = date
        self.foodName = foodName
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.mealType = mealType
    }
}
