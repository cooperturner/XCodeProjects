import SwiftData
import Foundation

class WeightRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func entries(userId: String) throws -> [WeightEntry] {
        let descriptor = FetchDescriptor<WeightEntry>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.id)]
        )
        return try modelContext.fetch(descriptor)
    }

    func add(userId: String, date: String, weightKg: Float) throws {
        modelContext.insert(WeightEntry(userId: userId, date: date, weightKg: weightKg))
        try modelContext.save()
    }

    func delete(_ entry: WeightEntry) throws {
        modelContext.delete(entry)
        try modelContext.save()
    }
}
