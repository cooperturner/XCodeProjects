import SwiftData
import Foundation

@Observable
class TrackerViewModel {
    var logs: [FoodLog] = []
    var todayPlannedMeals: [MealItem] = []
    var isEstimating = false
    var estimateResult = ""
    var error = ""

    var totalCalories: Int { logs.reduce(0) { $0 + $1.calories } }
    var totalProtein: Float { logs.reduce(0) { $0 + $1.proteinG } }
    var totalCarbs: Float { logs.reduce(0) { $0 + $1.carbsG } }
    var totalFat: Float { logs.reduce(0) { $0 + $1.fatG } }

    private let foodRepo: FoodLogRepository
    private let planRepo: PlanRepository
    private let session = SessionManager.shared
    private var today: String { ISO8601DateFormatter.localDate() }

    init(modelContext: ModelContext) {
        self.foodRepo = FoodLogRepository(modelContext: modelContext)
        self.planRepo = PlanRepository(modelContext: modelContext)
        loadToday()
    }

    func loadToday() {
        guard let userId = session.userId else { return }
        logs = (try? foodRepo.logsForDate(userId: userId, date: today)) ?? []

        let todayName = Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
        if let plan = try? planRepo.getLatestMealPlan(userId: userId) {
            todayPlannedMeals = plan.days.first(where: { $0.day.lowercased() == todayName.lowercased() })?.meals ?? []
        }
    }

    func addLog(foodName: String, calories: Int, protein: Float, carbs: Float, fat: Float, mealType: String) {
        guard let userId = session.userId else { return }
        let log = FoodLog(userId: userId, date: today, foodName: foodName,
                          calories: calories, proteinG: protein, carbsG: carbs, fatG: fat, mealType: mealType)
        try? foodRepo.add(log)
        loadToday()
    }

    func deleteLog(_ log: FoodLog) {
        try? foodRepo.delete(log)
        loadToday()
    }

    func estimateCalories(apiKey: String, foodName: String) {
        guard !apiKey.isEmpty else { error = "API key not set"; return }
        isEstimating = true
        estimateResult = ""
        error = ""
        Task {
            do {
                let result = try await foodRepo.estimateCalories(apiKey: apiKey, foodName: foodName)
                await MainActor.run { estimateResult = result; isEstimating = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isEstimating = false }
            }
        }
    }

    func clearEstimate() { estimateResult = ""; error = "" }
}

extension ISO8601DateFormatter {
    static func localDate() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
