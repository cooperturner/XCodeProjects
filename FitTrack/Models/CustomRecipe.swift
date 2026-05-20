import SwiftData
import Foundation

@Model
class CustomRecipe {
    var id: String
    var userId: String
    var name: String
    var mealType: String   // "Any", "Breakfast", "Lunch", "Dinner", "Snack"
    var notes: String
    var calories: Int
    var proteinG: Double
    var carbsG: Double
    var fatG: Double
    var ingredients: String  // newline-separated
    var method: String

    init(userId: String, name: String, mealType: String = "Any", notes: String = "",
         calories: Int = 0, proteinG: Double = 0, carbsG: Double = 0, fatG: Double = 0,
         ingredients: String = "", method: String = "") {
        self.id = UUID().uuidString
        self.userId = userId
        self.name = name
        self.mealType = mealType
        self.notes = notes
        self.calories = calories
        self.proteinG = proteinG
        self.carbsG = carbsG
        self.fatG = fatG
        self.ingredients = ingredients
        self.method = method
    }
}
