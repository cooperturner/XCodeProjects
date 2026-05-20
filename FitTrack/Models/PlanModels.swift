import Foundation

struct MealItem: Codable, Identifiable {
    var id = UUID()
    let type: String
    let name: String
    let calories: Int
    let protein: Int
    let carbs: Int
    let fat: Int
    let ingredients: [String]
    let prep: String

    enum CodingKeys: String, CodingKey {
        case type, name, calories, protein, carbs, fat, ingredients, prep
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        type = try c.decode(String.self, forKey: .type)
        name = try c.decode(String.self, forKey: .name)
        calories = try c.decodeFlexibleInt(forKey: .calories)
        protein  = try c.decodeFlexibleInt(forKey: .protein)
        carbs    = try c.decodeFlexibleInt(forKey: .carbs)
        fat      = try c.decodeFlexibleInt(forKey: .fat)
        ingredients = try c.decode([String].self, forKey: .ingredients)
        prep = try c.decode(String.self, forKey: .prep)
    }
}

private extension KeyedDecodingContainer {
    func decodeFlexibleInt(forKey key: Key) throws -> Int {
        if let v = try? decode(Int.self, forKey: key) { return v }
        if let v = try? decode(Double.self, forKey: key) { return Int(v.rounded()) }
        throw DecodingError.typeMismatch(Int.self, .init(codingPath: [key], debugDescription: "Expected Int or Double"))
    }
}

struct DayMealPlan: Codable, Identifiable {
    var id = UUID()
    let day: String
    let meals: [MealItem]

    var totalCalories: Int { meals.reduce(0) { $0 + $1.calories } }

    enum CodingKeys: String, CodingKey { case day, meals }
}

struct WeeklyMealPlan: Codable {
    let days: [DayMealPlan]
}

struct ExerciseItem: Codable, Identifiable {
    var id = UUID()
    let name: String
    let sets: Int
    let reps: String
    let rest: String
    let notes: String

    enum CodingKeys: String, CodingKey {
        case name, sets, reps, rest, notes
    }
}

extension ExerciseItem {
    var isWeightBased: Bool {
        reps.trimmingCharacters(in: .whitespaces)
            .range(of: #"^\d+(-\d+)?$"#, options: .regularExpression) != nil
    }
}

struct DayExercisePlan: Codable, Identifiable {
    var id = UUID()
    let day: String
    let workoutType: String
    let duration: String
    let isRest: Bool
    let exercises: [ExerciseItem]
    let warmup: String
    let cooldown: String

    enum CodingKeys: String, CodingKey {
        case day, workoutType, duration, isRest, exercises, warmup, cooldown
    }
}

struct WeeklyExercisePlan: Codable {
    let days: [DayExercisePlan]
}

struct MacroTargets {
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    static func calculate(weightKg: Float, calories: Int, goal: String) -> MacroTargets {
        let proteinPerKg: Float
        let fatPct: Float
        switch goal {
        case "gain_muscle":  proteinPerKg = 2.2; fatPct = 0.25
        case "lose_weight":  proteinPerKg = 2.0; fatPct = 0.30
        case "body_recomp":  proteinPerKg = 2.2; fatPct = 0.28
        default:             proteinPerKg = 1.7; fatPct = 0.30
        }
        let proteinG = Int(weightKg * proteinPerKg)
        let fatG = Int(Float(calories) * fatPct / 9)
        let carbsG = max(0, (calories - proteinG * 4 - fatG * 9) / 4)
        return MacroTargets(proteinG: proteinG, carbsG: carbsG, fatG: fatG)
    }
}
