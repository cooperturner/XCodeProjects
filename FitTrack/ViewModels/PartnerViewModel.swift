import SwiftData
import Foundation

enum PartnerSaveState { case idle, loading, saved, error(String) }

extension PartnerSaveState: Equatable {
    static func == (lhs: PartnerSaveState, rhs: PartnerSaveState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.saved, .saved): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}

@Observable
class PartnerViewModel {
    var partner: PartnerProfile?
    var saveState: PartnerSaveState = .idle

    private let modelContext: ModelContext
    private let session = SessionManager.shared

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        load()
    }

    func load() {
        guard let userId = session.userId else { return }
        let descriptor = FetchDescriptor<PartnerProfile>(
            predicate: #Predicate { $0.userId == userId }
        )
        partner = try? modelContext.fetch(descriptor).first
    }

    func save(name: String, age: String, weightKg: String, heightCm: String,
              gender: String, goal: String, dietaryPreferences: String, dislikedFoods: String) async {
        guard let userId = session.userId else { return }
        guard let ageInt = Int(age), let weight = Float(weightKg), let height = Int(heightCm) else {
            saveState = .error("Please check your inputs"); return
        }
        saveState = .loading

        let profile: PartnerProfile
        if let existing = partner {
            profile = existing
        } else {
            profile = PartnerProfile(userId: userId)
            modelContext.insert(profile)
        }

        profile.name = name.trimmingCharacters(in: .whitespaces)
        profile.age = ageInt
        profile.weightKg = weight
        profile.heightCm = height
        profile.gender = gender
        profile.goal = goal
        profile.dietaryPreferences = dietaryPreferences.trimmingCharacters(in: .whitespaces)
        profile.dislikedFoods = dislikedFoods.trimmingCharacters(in: .whitespaces)
        profile.dailyCalorieTarget = User.calculateCalorieTarget(weight: weight, height: height, age: ageInt, gender: gender, goal: goal)

        do {
            try modelContext.save()
            partner = profile
            saveState = .saved
        } catch {
            saveState = .error(error.localizedDescription)
        }
    }

    func delete() {
        guard let p = partner else { return }
        modelContext.delete(p)
        try? modelContext.save()
        partner = nil
    }

    func resetState() { saveState = .idle }
}
