import SwiftData
import Foundation

@Observable
class PlanViewModel {
    var mealPlan: WeeklyMealPlan?
    var partnerPlan: WeeklyMealPlan?
    var exercisePlan: WeeklyExercisePlan?
    var shoppingList: ShoppingList?
    var isGeneratingMeal = false
    var isGeneratingPartner = false
    var isGeneratingExercise = false
    var isGeneratingList = false
    var isReplanningToday = false
    var swappingKey: String?
    var error = ""

    private let planRepo: PlanRepository
    private let userRepo: UserRepository
    private let session = SessionManager.shared

    private var weekStart: String {
        let cal = Calendar.current
        let today = Date()
        let daysFromSunday = cal.component(.weekday, from: today) - 1
        let sunday = cal.date(byAdding: .day, value: -daysFromSunday, to: today) ?? today
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: sunday)
    }

    init(modelContext: ModelContext) {
        self.planRepo = PlanRepository(modelContext: modelContext)
        self.userRepo = UserRepository(modelContext: modelContext)
        loadSaved()
    }

    private func loadSaved() {
        guard let userId = session.userId else { return }
        mealPlan = try? planRepo.getLatestMealPlan(userId: userId)
        partnerPlan = try? planRepo.getLatestPartnerMealPlan(userId: userId)
        exercisePlan = try? planRepo.getLatestExercisePlan(userId: userId)
        loadCompletions()
    }

    func generateMealPlan(weeklyBudget: Double = 200, mealRequests: String = "") {
        guard let user = currentUser() else { error = "User not found"; return }
        isGeneratingMeal = true
        error = ""
        Task {
            do {
                let plan = try await planRepo.generateMealPlan(user: user, weekStart: weekStart, weeklyBudget: weeklyBudget, mealRequests: mealRequests)
                await MainActor.run { mealPlan = plan; isGeneratingMeal = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isGeneratingMeal = false }
            }
        }
    }

    func generateExercisePlan() {
        guard let user = currentUser() else { error = "User not found"; return }
        isGeneratingExercise = true
        error = ""
        Task {
            do {
                let plan = try await planRepo.generateExercisePlan(user: user, weekStart: weekStart)
                await MainActor.run { exercisePlan = plan; isGeneratingExercise = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isGeneratingExercise = false }
            }
        }
    }

    func swapMeal(day: String, meal: MealItem) {
        guard let user = currentUser() else { return }
        let key = "\(day)_\(meal.type)"
        swappingKey = key
        error = ""
        Task {
            do {
                let newMeal = try await planRepo.swapMeal(apiKey: user.apiKey, day: day, meal: meal, dietaryPreferences: user.dietaryPreferences, dislikedFoods: user.dislikedFoods)
                await MainActor.run {
                    updateMeal(day: day, meal: meal, with: newMeal)
                    swappingKey = nil
                    if let userId = session.userId, let plan = mealPlan {
                        try? planRepo.saveMealPlan(userId: userId, weekStart: weekStart, plan: plan)
                    }
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; swappingKey = nil }
            }
        }
    }

    func swapExercise(day: String, index: Int, exercise: ExerciseItem, workoutType: String) {
        guard let user = currentUser() else { return }
        let key = "\(day)_ex_\(index)"
        swappingKey = key
        error = ""
        Task {
            do {
                let newEx = try await planRepo.swapExercise(apiKey: user.apiKey, exercise: exercise, workoutType: workoutType)
                await MainActor.run {
                    updateExercise(day: day, index: index, with: newEx)
                    swappingKey = nil
                    if let userId = session.userId, let plan = exercisePlan {
                        try? planRepo.saveExercisePlan(userId: userId, weekStart: weekStart, plan: plan)
                    }
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; swappingKey = nil }
            }
        }
    }

    func generatePartnerPlan(partner: PartnerProfile, weeklyBudget: Double = 200, mealRequests: String = "") {
        guard let user = currentUser() else { error = "User not found"; return }
        isGeneratingPartner = true
        error = ""
        Task {
            do {
                let plan = try await planRepo.generatePartnerMealPlan(partner: partner, apiKey: user.apiKey, weekStart: weekStart, weeklyBudget: weeklyBudget, mealRequests: mealRequests)
                await MainActor.run { partnerPlan = plan; isGeneratingPartner = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isGeneratingPartner = false }
            }
        }
    }

    func generateShoppingList(partnerName: String = "", excludedKeys: Set<String> = [], partnerExcludedKeys: Set<String> = [], weeklyBudget: Double = 200) {
        guard let plan = mealPlan, let user = currentUser() else { error = "Generate a meal plan first"; return }
        isGeneratingList = true
        error = ""
        Task {
            do {
                let list = try await planRepo.generateShoppingList(apiKey: user.apiKey, myPlan: plan, partnerPlan: partnerPlan, partnerName: partnerName, excludedKeys: excludedKeys, partnerExcludedKeys: partnerExcludedKeys, weeklyBudget: weeklyBudget)
                await MainActor.run { shoppingList = list; isGeneratingList = false }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; isGeneratingList = false }
            }
        }
    }

    func clearError() { error = "" }

    private func currentUser() -> User? {
        guard let id = session.userId else { return nil }
        return try? userRepo.findUser(id: id)
    }

    func replanRemainingMeals(day: String, consumedCalories: Int, consumedProtein: Float, consumedCarbs: Float, consumedFat: Float, loggedMealTypes: Set<String> = []) {
        guard let user = currentUser() else { return }
        isReplanningToday = true
        error = ""
        Task {
            do {
                let newMeals = try await planRepo.replanRemainingMeals(
                    apiKey: user.apiKey, user: user,
                    consumedCalories: consumedCalories, consumedProtein: consumedProtein,
                    consumedCarbs: consumedCarbs, consumedFat: consumedFat,
                    loggedMealTypes: loggedMealTypes
                )
                await MainActor.run {
                    self.replaceRemainingMeals(day: day, with: newMeals)
                    self.isReplanningToday = false
                    if let userId = self.session.userId, let plan = self.mealPlan {
                        try? self.planRepo.saveMealPlan(userId: userId, weekStart: self.weekStart, plan: plan)
                    }
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.isReplanningToday = false }
            }
        }
    }

    private func replaceRemainingMeals(day: String, with newMeals: [MealItem]) {
        guard let plan = mealPlan else { return }
        let newTypesLower = Set(newMeals.map { $0.type.lowercased() })
        let order = ["Breakfast", "Lunch", "Dinner", "Snack"]
        mealPlan = WeeklyMealPlan(days: plan.days.map { d in
            guard d.day == day else { return d }
            let kept = d.meals.filter { !newTypesLower.contains($0.type.lowercased()) }
            let merged = (kept + newMeals).sorted {
                (order.firstIndex(of: $0.type.capitalized) ?? 99) < (order.firstIndex(of: $1.type.capitalized) ?? 99)
            }
            return DayMealPlan(day: d.day, meals: merged)
        })
    }

    func swapPartnerMeal(day: String, meal: MealItem, partner: PartnerProfile?) {
        guard let user = currentUser() else { return }
        let key = "\(day)_\(meal.type)"
        swappingKey = key
        error = ""
        Task {
            do {
                let newMeal = try await planRepo.swapMeal(apiKey: user.apiKey, day: day, meal: meal, dietaryPreferences: partner?.dietaryPreferences ?? "", dislikedFoods: partner?.dislikedFoods ?? "")
                await MainActor.run {
                    self.updatePartnerMeal(day: day, meal: meal, with: newMeal)
                    self.swappingKey = nil
                    if let userId = self.session.userId, let plan = self.partnerPlan {
                        let partnerKey = "\(userId)_partner"
                        try? self.planRepo.saveMealPlan(userId: partnerKey, weekStart: self.weekStart, plan: plan)
                    }
                }
            } catch {
                await MainActor.run { self.error = error.localizedDescription; self.swappingKey = nil }
            }
        }
    }

    private func updateMeal(day: String, meal: MealItem, with newMeal: MealItem) {
        guard let plan = mealPlan else { return }
        mealPlan = WeeklyMealPlan(days: plan.days.map { d in
            guard d.day == day else { return d }
            return DayMealPlan(day: d.day, meals: d.meals.map { m in m.type == meal.type ? newMeal : m })
        })
    }

    private func updatePartnerMeal(day: String, meal: MealItem, with newMeal: MealItem) {
        guard let plan = partnerPlan else { return }
        partnerPlan = WeeklyMealPlan(days: plan.days.map { d in
            guard d.day == day else { return d }
            return DayMealPlan(day: d.day, meals: d.meals.map { m in m.type == meal.type ? newMeal : m })
        })
    }

    private func updateExercise(day: String, index: Int, with newEx: ExerciseItem) {
        guard let plan = exercisePlan else { return }
        exercisePlan = WeeklyExercisePlan(days: plan.days.map { d in
            guard d.day == day else { return d }
            var exList = d.exercises
            if index < exList.count { exList[index] = newEx }
            return DayExercisePlan(day: d.day, workoutType: d.workoutType, duration: d.duration,
                                   isRest: d.isRest, exercises: exList, warmup: d.warmup, cooldown: d.cooldown)
        })
    }

    // MARK: - Workout Completion & Log Tracking

    var completedExercises: Set<String> = []
    private(set) var allWorkoutLogs: [WorkoutSetRecord] = []

    struct WorkoutSetRecord: Codable {
        let date: String
        let exerciseName: String
        let setNumber: Int
        let weightKg: Float
        let repsCompleted: Int
    }

    private var todayString: String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
    private var completionsKey: String { "completions_\(session.userId ?? "0")_\(todayString)" }
    private var workoutLogsKey: String { "workoutlogs_\(session.userId ?? "0")" }

    func loadCompletions() {
        let arr = UserDefaults.standard.stringArray(forKey: completionsKey) ?? []
        completedExercises = Set(arr)
        guard let data = UserDefaults.standard.data(forKey: workoutLogsKey),
              let decoded = try? JSONDecoder().decode([WorkoutSetRecord].self, from: data) else { return }
        allWorkoutLogs = decoded
    }

    func markExerciseCompleted(_ name: String) {
        completedExercises = completedExercises.union([name])
        UserDefaults.standard.set(Array(completedExercises), forKey: completionsKey)
    }

    func markExerciseIncomplete(_ name: String) {
        completedExercises = completedExercises.subtracting([name])
        UserDefaults.standard.set(Array(completedExercises), forKey: completionsKey)
    }

    func saveSetLog(exerciseName: String, sets: [(Float, Int)]) {
        let today = todayString
        var logs = allWorkoutLogs.filter { !($0.date == today && $0.exerciseName == exerciseName) }
        logs += sets.enumerated().map { i, s in
            WorkoutSetRecord(date: today, exerciseName: exerciseName, setNumber: i + 1, weightKg: s.0, repsCompleted: s.1)
        }
        allWorkoutLogs = logs
        if let data = try? JSONEncoder().encode(allWorkoutLogs) {
            UserDefaults.standard.set(data, forKey: workoutLogsKey)
        }
        markExerciseCompleted(exerciseName)
    }

    func progressionFor(exerciseName: String) -> [(date: String, sets: [(weightKg: Float, reps: Int)])] {
        let relevant = allWorkoutLogs.filter { $0.exerciseName == exerciseName }
        let grouped = Dictionary(grouping: relevant, by: \.date)
        return grouped
            .sorted { $0.key > $1.key }
            .map { date, records in
                (date: date, sets: records.sorted { $0.setNumber < $1.setNumber }.map { ($0.weightKg, $0.repsCompleted) })
            }
    }
}
