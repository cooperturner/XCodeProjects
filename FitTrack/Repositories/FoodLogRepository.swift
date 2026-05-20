import SwiftData
import Foundation

class FoodLogRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func logsForDate(userId: String, date: String) throws -> [FoodLog] {
        let descriptor = FetchDescriptor<FoodLog>(
            predicate: #Predicate { $0.userId == userId && $0.date == date },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    func add(_ log: FoodLog) throws {
        modelContext.insert(log)
        try modelContext.save()
    }

    func delete(_ log: FoodLog) throws {
        modelContext.delete(log)
        try modelContext.save()
    }

    func estimateCalories(apiKey: String, foodName: String) async throws -> String {
        let prompt = """
            Estimate the calories and macros for: "\(foodName)"
            Format:
            Calories: 350 kcal
            Protein: 25g
            Carbs: 30g
            Fat: 10g
            """
        return try await ClaudeService.shared.send(apiKey: apiKey, prompt: prompt, maxTokens: 256)
    }
}
