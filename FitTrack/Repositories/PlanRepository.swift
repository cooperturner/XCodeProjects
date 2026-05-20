import SwiftData
import Foundation

class PlanRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Meal Plan

    func getLatestMealPlan(userId: String) throws -> WeeklyMealPlan? {
        let descriptor = FetchDescriptor<MealPlanRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)]
        )
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        return decodeMealPlan(record.planText)
    }

    func generateMealPlan(user: User, weekStart: String, weeklyBudget: Double = 200, mealRequests: String = "") async throws -> WeeklyMealPlan {
        guard !user.apiKey.isEmpty else {
            throw PlanError.noApiKey
        }
        let goalLabel = goalText(user.goal)
        let macros = MacroTargets.calculate(weightKg: user.weightKg, calories: user.dailyCalorieTarget, goal: user.goal)
        let prefsLine = buildPrefsLine(user)

        let breakfastKcal = Int(Double(user.dailyCalorieTarget) * 0.25)
        let lunchKcal     = Int(Double(user.dailyCalorieTarget) * 0.35)
        let dinnerKcal    = Int(Double(user.dailyCalorieTarget) * 0.30)
        let snackKcal     = user.dailyCalorieTarget - breakfastKcal - lunchKcal - dinnerKcal

        let recipesLine = recipeSection(userId: user.id)

        let prompt = """
            You are a nutrition expert. Generate a practical 7-day meal plan for this person:
            Goal: \(goalLabel) | Age: \(user.age) | Weight: \(user.weightKg)kg | Height: \(user.heightCm)cm | Gender: \(user.gender)
            Daily calorie target: \(user.dailyCalorieTarget) kcal | Protein: \(macros.proteinG)g | Carbs: \(macros.carbsG)g | Fat: \(macros.fatG)g
            \(prefsLine)
            \(recipesLine)

            BUDGET: The household weekly grocery budget is $\(String(format: "%.0f", weeklyBudget)) AUD. Choose affordable, everyday ingredients available at Coles. Prefer home-brand staples, batch-cook friendly proteins (chicken thigh over breast, canned fish, eggs, legumes), and seasonal vegetables. Avoid expensive or specialty items.

            AUSTRALIAN CONTEXT:
            - All ingredients must be available in Australian supermarkets (Woolworths, Coles, Aldi).
            - Use Australian names: capsicum (not bell pepper), coriander (not cilantro), prawns (not shrimp), spring onion (not scallion), eggplant (not aubergine), zucchini (not courgette), rockmelon (not cantaloupe), skim milk (not nonfat milk), mince (not ground beef), sultanas (not raisins).
            - Include a mix of Australian-style meals: e.g. Vegemite toast, Anzac oats, BBQ chicken, meat pies, stir-fries, grain bowls.

            LEFTOVER PLANNING:
            - Plan 2 big batch dinners that produce leftovers (e.g. cook a large bolognese on Monday, use leftovers for lunch Tuesday).
            - When a meal uses leftovers, name it clearly e.g. "Leftover Bolognese with Rice" and set ingredients to ["Leftovers from [meal name]"].
            - This reduces shopping and cooking effort across the week.

            CRITICAL CALORIE RULES — you MUST follow these exactly:
            1. Each day MUST contain exactly 4 meals: Breakfast, Lunch, Dinner, Snack.
            2. Target calories per meal: Breakfast ~\(breakfastKcal) kcal, Lunch ~\(lunchKcal) kcal, Dinner ~\(dinnerKcal) kcal, Snack ~\(snackKcal) kcal.
            3. The 4 meal calories MUST sum to EXACTLY \(user.dailyCalorieTarget) kcal (±20 kcal). Use larger portions if needed.
            4. Before outputting, verify: Breakfast + Lunch + Dinner + Snack = \(user.dailyCalorieTarget). If not, adjust portions until they do.
            5. Do NOT round down — use realistic portions that genuinely hit the calorie targets.

            \({ let r = sanitizePromptInput(mealRequests, maxLength: 500); return r.isEmpty ? "" : """
            SPECIFIC MEAL REQUESTS — you MUST include these meals somewhere in the plan and build the rest of the week around them:
            \(r)
            """ }())

            Respond with ONLY a valid JSON object — no markdown, no explanation, no trailing text.
            {"days":[{"day":"Sunday","meals":[{"type":"Breakfast","name":"Oats with Banana","calories":\(breakfastKcal),"protein":15,"carbs":60,"fat":8,"ingredients":["100g rolled oats","250ml milk","1 banana"],"prep":"Cook oats, top with banana."},{"type":"Lunch",...},{"type":"Dinner",...},{"type":"Snack",...}]},{"day":"Monday",...},{"day":"Tuesday",...},{"day":"Wednesday",...},{"day":"Thursday",...},{"day":"Friday",...},{"day":"Saturday",...}]}

            Rules: all 7 days required starting Sunday; ingredients 3-5 items; prep under 15 words.
            """

        let text = try await ClaudeService.shared.send(apiKey: user.apiKey, prompt: prompt, maxTokens: 6000)
        guard let plan = decodeMealPlan(ClaudeService.shared.extractJson(text)) else {
            throw PlanError.parseFailed("Could not parse meal plan — try regenerating.")
        }
        try saveMealPlan(userId: user.id, weekStart: weekStart, plan: plan)
        return plan
    }

    func generatePartnerMealPlan(partner: PartnerProfile, apiKey: String, weekStart: String, weeklyBudget: Double = 200, mealRequests: String = "") async throws -> WeeklyMealPlan {
        let goalLabel = goalText(partner.goal)
        let macros = MacroTargets.calculate(weightKg: partner.weightKg, calories: partner.dailyCalorieTarget, goal: partner.goal)
        let breakfastKcal = Int(Double(partner.dailyCalorieTarget) * 0.25)
        let lunchKcal     = Int(Double(partner.dailyCalorieTarget) * 0.35)
        let dinnerKcal    = Int(Double(partner.dailyCalorieTarget) * 0.30)
        let snackKcal     = partner.dailyCalorieTarget - breakfastKcal - lunchKcal - dinnerKcal
        var prefsLine = ""
        let partnerPrefs = sanitizePromptInput(partner.dietaryPreferences)
        let partnerDislikes = sanitizePromptInput(partner.dislikedFoods)
        if !partnerPrefs.isEmpty { prefsLine += "Dietary preferences: \(partnerPrefs). " }
        if !partnerDislikes.isEmpty { prefsLine += "NEVER include: \(partnerDislikes)." }

        let recipesLine = recipeSection(userId: partner.userId)

        let prompt = """
            You are a nutrition expert. Generate a practical 7-day meal plan for this person:
            Name: \(partner.name) | Goal: \(goalLabel) | Age: \(partner.age) | Weight: \(partner.weightKg)kg | Height: \(partner.heightCm)cm | Gender: \(partner.gender)
            Daily calorie target: \(partner.dailyCalorieTarget) kcal | Protein: \(macros.proteinG)g | Carbs: \(macros.carbsG)g | Fat: \(macros.fatG)g
            \(prefsLine)
            \(recipesLine)

            BUDGET: The household weekly grocery budget is $\(String(format: "%.0f", weeklyBudget)) AUD shared between 2 people. Choose affordable, everyday ingredients. Prefer budget-friendly proteins (eggs, legumes, tofu, canned fish), home-brand staples, and seasonal vegetables from Coles/Aldi.

            AUSTRALIAN CONTEXT:
            - All ingredients must be available in Australian supermarkets (Woolworths, Coles, Aldi).
            - Use Australian names: capsicum (not bell pepper), coriander (not cilantro), prawns (not shrimp), spring onion (not scallion), eggplant (not aubergine), zucchini (not courgette), skim milk (not nonfat milk), mince (not ground beef).
            - Include a mix of Australian-style meals.

            HOUSEHOLD SHOPPING HINT:
            - This person shares a household. Where possible, use similar base ingredients to their housemate's plan (e.g. if housemate uses zucchini, capsicum, or rice — use these too where appropriate for this person's dietary needs).
            - Plan 2 big batch dinners with leftovers. Mark leftover meals with ingredients: ["Leftovers from [meal name]"].

            CRITICAL CALORIE RULES:
            1. Each day MUST contain exactly 4 meals: Breakfast, Lunch, Dinner, Snack.
            2. Target: Breakfast ~\(breakfastKcal) kcal, Lunch ~\(lunchKcal) kcal, Dinner ~\(dinnerKcal) kcal, Snack ~\(snackKcal) kcal.
            3. MUST sum to EXACTLY \(partner.dailyCalorieTarget) kcal (±20 kcal). Verify before responding.

            \({ let r = sanitizePromptInput(mealRequests, maxLength: 500); return r.isEmpty ? "" : """
            SPECIFIC MEAL REQUESTS — you MUST include these meals somewhere in the plan and build the rest of the week around them:
            \(r)
            """ }())

            Respond with ONLY a valid JSON object — no markdown, no explanation, no trailing text.
            {"days":[{"day":"Sunday","meals":[{"type":"Breakfast","name":"Oats with Banana","calories":\(breakfastKcal),"protein":15,"carbs":60,"fat":8,"ingredients":["100g rolled oats","250ml milk","1 banana"],"prep":"Cook oats, top with banana."},{"type":"Lunch",...},{"type":"Dinner",...},{"type":"Snack",...}]},{"day":"Monday",...},{"day":"Tuesday",...},{"day":"Wednesday",...},{"day":"Thursday",...},{"day":"Friday",...},{"day":"Saturday",...}]}

            Rules: all 7 days required starting Sunday; ingredients 3-5 items; prep under 15 words.
            """

        let text = try await ClaudeService.shared.send(apiKey: apiKey, prompt: prompt, maxTokens: 6000)
        guard let plan = decodeMealPlan(ClaudeService.shared.extractJson(text)) else {
            throw PlanError.parseFailed("Could not parse partner meal plan — try regenerating.")
        }
        let partnerKey = "\(partner.userId)_partner"
        try saveMealPlan(userId: partnerKey, weekStart: weekStart, plan: plan)
        return plan
    }

    func getLatestPartnerMealPlan(userId: String) throws -> WeeklyMealPlan? {
        let partnerKey = "\(userId)_partner"
        return try getLatestMealPlan(userId: partnerKey)
    }

    func generateShoppingList(apiKey: String, myPlan: WeeklyMealPlan, partnerPlan: WeeklyMealPlan? = nil, partnerName: String = "", excludedKeys: Set<String> = [], partnerExcludedKeys: Set<String> = [], weeklyBudget: Double = 200) async throws -> ShoppingList {
        func ingredients(from plan: WeeklyMealPlan, excluded: Set<String>) -> [String] {
            plan.days.flatMap { day in
                day.meals.filter { meal in
                    let key = "\(day.day)_\(meal.type)"
                    return !excluded.contains(key)
                        && meal.ingredients.first?.lowercased().hasPrefix("leftover") != true
                }.flatMap { $0.ingredients }
            }
        }

        let myIngredients = ingredients(from: myPlan, excluded: excludedKeys)
        var ingredientSection = "My meals:\n" + myIngredients.joined(separator: "\n")

        if let partnerPlan {
            let partnerIngredients = ingredients(from: partnerPlan, excluded: partnerExcludedKeys)
            let label = partnerName.isEmpty ? "Partner" : partnerName
            ingredientSection += "\n\n\(label)'s meals:\n" + partnerIngredients.joined(separator: "\n")
        }

        let householdNote = partnerPlan != nil ? "This is a combined list for 2 people with different dietary needs. Combine shared ingredients into one line item with the total quantity needed. Where one person eats meat and the other doesn't, list both (e.g. \"500g chicken mince\" and \"400g firm tofu\") separately." : ""

        let prompt = """
            You are helping an Australian household create a Coles supermarket shopping list.
            \(householdNote)
            Consolidate duplicate ingredients, skip leftover references, and group by Coles department.

            \(ingredientSection)

            BUDGET CONSTRAINT: The total estimated cost of ALL items MUST come in under $\(String(format: "%.2f", weeklyBudget)) AUD. This is a hard limit — if the list would exceed this, reduce quantities, swap expensive items for cheaper alternatives (e.g. chicken thigh instead of breast, canned tuna instead of fresh fish, frozen vegetables instead of fresh, home-brand instead of branded), or remove low-priority extras. The sum of all estimatedPrice values MUST be less than \(String(format: "%.2f", weeklyBudget)).

            Use these Coles department names exactly: Produce, Meat & Seafood, Dairy & Eggs, Bakery, Pantry & Dry Goods, Frozen, Deli & Antipasto, Other.
            Use Australian product names (capsicum, coriander, mince, spring onion, skim milk, etc.).
            Keep each item concise: "500g chicken breast", "1 bag baby spinach", "2 cans diced tomatoes".
            For each item include an estimatedPrice in AUD based on typical 2024-2025 Coles shelf prices. Be realistic — e.g. 500g chicken breast ~$7.00, 1L skim milk ~$2.20, 1 bag baby spinach ~$3.50.

            Respond with ONLY a valid JSON object — no markdown, no explanation. Only include categories that have items. Keep item names short (under 5 words):
            {"categories":[{"category":"Produce","items":[{"name":"1 bag baby spinach","estimatedPrice":3.50}]},{"category":"Meat & Seafood","items":[{"name":"500g chicken breast","estimatedPrice":7.00}]}]}
            """

        let text = try await ClaudeService.shared.send(apiKey: apiKey, prompt: prompt)
        let json: String = ClaudeService.shared.extractJson(text)
        guard let data = json.data(using: .utf8) else {
            throw PlanError.parseFailed("Shopping list response was empty — try again.")
        }
        guard let list = try? JSONDecoder().decode(ShoppingList.self, from: data) else {
            throw PlanError.parseFailed("Shopping list was cut off mid-response — try again. (If this keeps happening, reduce the number of meals selected.)")
        }
        return list
    }

    func replanRemainingMeals(apiKey: String, user: User, consumedCalories: Int, consumedProtein: Float, consumedCarbs: Float, consumedFat: Float, loggedMealTypes: Set<String> = []) async throws -> [MealItem] {
        let hour = Calendar.current.component(.hour, from: Date())
        // Time-based pool of meals still possible today
        let timeBasedPool: [String]
        switch hour {
        case ..<9:    timeBasedPool = ["Breakfast", "Lunch", "Dinner", "Snack"]
        case 9..<12:  timeBasedPool = ["Lunch", "Dinner", "Snack"]
        case 12..<20: timeBasedPool = ["Dinner", "Snack"]
        case 20..<23: timeBasedPool = ["Snack"]
        default: throw PlanError.parseFailed("No remaining meals to re-plan today.")
        }
        // Remove any meal types the user has already logged (case-insensitive)
        let loggedLower = Set(loggedMealTypes.map { $0.lowercased() })
        let remainingTypes = timeBasedPool.filter { !loggedLower.contains($0.lowercased()) }
        guard !remainingTypes.isEmpty else {
            throw PlanError.parseFailed("All remaining meals for today have already been logged.")
        }

        let macros = MacroTargets.calculate(weightKg: user.weightKg, calories: user.dailyCalorieTarget, goal: user.goal)
        let remainingCalories = max(user.dailyCalorieTarget - consumedCalories, 100)
        let remainingProtein  = max(macros.proteinG - Int(consumedProtein), 0)
        let remainingCarbs    = max(macros.carbsG - Int(consumedCarbs), 0)
        let remainingFat      = max(macros.fatG - Int(consumedFat), 0)
        let prefsLine = buildPrefsLine(user)

        let typeExample = remainingTypes.first ?? "Dinner"
        let prompt = """
            A person has already eaten \(consumedCalories) kcal today (protein: \(Int(consumedProtein))g, carbs: \(Int(consumedCarbs))g, fat: \(Int(consumedFat))g).
            Full daily targets: \(user.dailyCalorieTarget) kcal | Protein: \(macros.proteinG)g | Carbs: \(macros.carbsG)g | Fat: \(macros.fatG)g
            Still needed today: ~\(remainingCalories) kcal | Protein: ~\(remainingProtein)g | Carbs: ~\(remainingCarbs)g | Fat: ~\(remainingFat)g
            \(prefsLine)

            Generate exactly \(remainingTypes.count) Australian meal(s) for the rest of today.
            Use EXACTLY these type values (copy them character-for-character, including capitalisation): \(remainingTypes.map { "\"\($0)\"" }.joined(separator: ", ")).
            Together they MUST total exactly \(remainingCalories) kcal (±20 kcal). Distribute calories sensibly across the meal types.
            Use ingredients from Coles/Woolworths. Use Australian names (capsicum, mince, coriander, skim milk, etc.).

            Respond with ONLY a valid JSON object — no markdown, no explanation:
            {"meals":[{"type":"\(typeExample)","name":"Grilled Chicken with Rice","calories":500,"protein":40,"carbs":50,"fat":10,"ingredients":["150g chicken breast","1 cup brown rice","1 cup broccoli"],"prep":"Grill chicken, serve with rice."}]}
            """

        let text = try await ClaudeService.shared.send(apiKey: apiKey, prompt: prompt, maxTokens: 1024)
        let json = ClaudeService.shared.extractJson(text)
        guard let data = json.data(using: .utf8),
              let wrapper = try? JSONDecoder().decode(MealItemsWrapper.self, from: data) else {
            throw PlanError.parseFailed("Could not parse re-planned meals — try again.")
        }
        return wrapper.meals
    }

    private struct MealItemsWrapper: Decodable { let meals: [MealItem] }

    func swapMeal(apiKey: String, day: String, meal: MealItem, dietaryPreferences: String = "", dislikedFoods: String = "") async throws -> MealItem {
        var prefsLine = ""
        let safePrefs = sanitizePromptInput(dietaryPreferences)
        let safeDislikes = sanitizePromptInput(dislikedFoods)
        if !safePrefs.isEmpty { prefsLine += "Dietary requirements: \(safePrefs). " }
        if !safeDislikes.isEmpty { prefsLine += "NEVER include: \(safeDislikes)." }

        let prompt = """
            Suggest an alternative \(meal.type) meal to replace "\(meal.name)".
            Match these targets: \(meal.calories) kcal | Protein: \(meal.protein)g | Carbs: \(meal.carbs)g | Fat: \(meal.fat)g
            \(prefsLine)
            Use Australian ingredients available at Coles/Woolworths.

            Respond with ONLY a JSON object:
            {"type":"\(meal.type)","name":"Alternative name","calories":\(meal.calories),"protein":\(meal.protein),"carbs":\(meal.carbs),"fat":\(meal.fat),"ingredients":["item1","item2"],"prep":"Brief prep."}
            """
        let text = try await ClaudeService.shared.send(apiKey: apiKey, prompt: prompt, maxTokens: 512)
        let json = ClaudeService.shared.extractJson(text)
        guard let data = json.data(using: .utf8),
              let item = try? JSONDecoder().decode(MealItem.self, from: data) else {
            throw PlanError.parseFailed("Could not parse swap response.")
        }
        return item
    }

    func saveMealPlan(userId: String, weekStart: String, plan: WeeklyMealPlan) throws {
        let descriptor = FetchDescriptor<MealPlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        let existing = try modelContext.fetch(descriptor)
        existing.forEach { modelContext.delete($0) }
        let json = (try? JSONEncoder().encode(plan)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        modelContext.insert(MealPlanRecord(userId: userId, weekStartDate: weekStart, planText: json))
        try modelContext.save()
    }

    // MARK: - Exercise Plan

    func getLatestExercisePlan(userId: String) throws -> WeeklyExercisePlan? {
        let descriptor = FetchDescriptor<ExercisePlanRecord>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.weekStartDate, order: .reverse)]
        )
        guard let record = try modelContext.fetch(descriptor).first else { return nil }
        return decodeExercisePlan(record.planText)
    }

    func generateExercisePlan(user: User, weekStart: String) async throws -> WeeklyExercisePlan {
        guard !user.apiKey.isEmpty else { throw PlanError.noApiKey }
        let goalLabel = goalTextExercise(user.goal)
        let sanitizedSport = sanitizePromptInput(user.sport, maxLength: 100)
        let sportLine = sanitizedSport.isEmpty ? "" :
            "Sport: \(sanitizedSport) — design sessions to directly improve performance in this sport (sport-specific conditioning, strength, and movement patterns)."

        let prompt = """
            You are a fitness expert. Generate a 7-day exercise plan for this person:
            Goal: \(goalLabel) | Age: \(user.age) | Weight: \(user.weightKg)kg | Gender: \(user.gender)
            \(sportLine)

            Respond with ONLY a valid JSON object — no markdown, no explanation, no trailing text.
            {"days":[{"day":"Monday","workoutType":"Strength Training","duration":"45 min","isRest":false,"exercises":[{"name":"Squat","sets":3,"reps":"10-12","rest":"60 sec","notes":"Keep chest up."}],"warmup":"5 min walk","cooldown":"5 min stretch"},{"day":"Tuesday",...},{"day":"Wednesday",...},{"day":"Thursday",...},{"day":"Friday",...},{"day":"Saturday",...},{"day":"Sunday",...}]}

            Rest day format: {"day":"...","workoutType":"Rest","duration":"","isRest":true,"exercises":[],"warmup":"","cooldown":""}
            Rules: all 7 days required; 1-2 rest days; 4-6 exercises per workout day; notes under 8 words.
            """

        let text = try await ClaudeService.shared.send(apiKey: user.apiKey, prompt: prompt)
        guard let plan = decodeExercisePlan(ClaudeService.shared.extractJson(text)) else {
            throw PlanError.parseFailed("Could not parse exercise plan — try regenerating.")
        }
        try saveExercisePlan(userId: user.id, weekStart: weekStart, plan: plan)
        return plan
    }

    func swapExercise(apiKey: String, exercise: ExerciseItem, workoutType: String) async throws -> ExerciseItem {
        let prompt = """
            Suggest an alternative exercise to replace "\(exercise.name)" in a \(workoutType) workout.
            Respond with ONLY a JSON object:
            {"name":"Alternative exercise","sets":3,"reps":"10-12","rest":"60 sec","notes":"Form tip"}
            """
        let text = try await ClaudeService.shared.send(apiKey: apiKey, prompt: prompt, maxTokens: 256)
        let json = ClaudeService.shared.extractJson(text)
        guard let data = json.data(using: .utf8),
              let item = try? JSONDecoder().decode(ExerciseItem.self, from: data) else {
            throw PlanError.parseFailed("Could not parse swap response.")
        }
        return item
    }

    func saveExercisePlan(userId: String, weekStart: String, plan: WeeklyExercisePlan) throws {
        let descriptor = FetchDescriptor<ExercisePlanRecord>(
            predicate: #Predicate { $0.userId == userId }
        )
        let existing = try modelContext.fetch(descriptor)
        existing.forEach { modelContext.delete($0) }
        let json = (try? JSONEncoder().encode(plan)).flatMap { String(data: $0, encoding: .utf8) } ?? ""
        modelContext.insert(ExercisePlanRecord(userId: userId, weekStartDate: weekStart, planText: json))
        try modelContext.save()
    }

    // MARK: - Helpers

    private func recipeSection(userId: String) -> String {
        let descriptor = FetchDescriptor<CustomRecipe>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.name)]
        )
        guard let recipes = try? modelContext.fetch(descriptor), !recipes.isEmpty else { return "" }
        let lines = recipes.map { r -> String in
            var line = "• \(r.name)"
            if r.mealType != "Any" { line += " (\(r.mealType))" }
            if r.calories > 0 {
                line += " — \(r.calories) kcal"
                var macros: [String] = []
                if r.proteinG > 0 { macros.append("P:\(Int(r.proteinG))g") }
                if r.carbsG > 0 { macros.append("C:\(Int(r.carbsG))g") }
                if r.fatG > 0 { macros.append("F:\(Int(r.fatG))g") }
                if !macros.isEmpty { line += " | " + macros.joined(separator: " ") }
            }
            if !r.notes.isEmpty { line += " — \(r.notes)" }
            if !r.ingredients.isEmpty {
                let ingredientList = r.ingredients.components(separatedBy: "\n")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .joined(separator: ", ")
                line += "\n  Ingredients: \(ingredientList)"
            }
            if !r.method.isEmpty { line += "\n  Method: \(r.method)" }
            return line
        }
        return "\nHOUSEHOLD RECIPES — include these personal recipes in the rotation where they fit the calorie and macro targets. Use the exact calories and macros provided:\n" + lines.joined(separator: "\n")
    }

    private func decodeMealPlan(_ json: String) -> WeeklyMealPlan? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WeeklyMealPlan.self, from: data)
    }

    private func decodeExercisePlan(_ json: String) -> WeeklyExercisePlan? {
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(WeeklyExercisePlan.self, from: data)
    }

    private func goalText(_ goal: String) -> String {
        switch goal {
        case "gain_muscle":  return "gain muscle mass"
        case "lose_weight":  return "lose weight and burn fat"
        case "body_recomp":  return "body recomposition (lose fat while building muscle simultaneously — high protein, moderate deficit)"
        default:             return "maintain current weight"
        }
    }

    private func goalTextExercise(_ goal: String) -> String {
        switch goal {
        case "gain_muscle":  return "gain muscle mass and strength"
        case "lose_weight":  return "lose weight and improve cardio fitness"
        case "body_recomp":  return "body recomposition — combine resistance training to build muscle with cardio to burn fat"
        default:             return "maintain fitness and overall health"
        }
    }

    private func buildPrefsLine(_ user: User) -> String {
        var parts: [String] = []
        let prefs = sanitizePromptInput(user.dietaryPreferences)
        let dislikes = sanitizePromptInput(user.dislikedFoods)
        if !prefs.isEmpty { parts.append("Dietary preferences: \(prefs).") }
        if !dislikes.isEmpty { parts.append("NEVER include these foods: \(dislikes).") }
        return parts.joined(separator: " ")
    }

    // Strip characters that could alter Claude prompt structure, then cap length.
    // Newlines would inject new prompt lines; backticks could break code-fence context.
    private func sanitizePromptInput(_ input: String, maxLength: Int = 300) -> String {
        let safe = input
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "`", with: "'")
        return String(safe.prefix(maxLength))
    }
}

enum PlanError: Error, LocalizedError {
    case noApiKey
    case parseFailed(String)

    var errorDescription: String? {
        switch self {
        case .noApiKey: return "Claude API key not set. Go to Settings to add it."
        case .parseFailed(let msg): return msg
        }
    }
}
