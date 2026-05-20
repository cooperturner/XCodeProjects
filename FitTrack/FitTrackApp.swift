import SwiftUI
import SwiftData

@main
struct FitTrackApp: App {
    let container: ModelContainer

    init() {
        let schema = Schema([
            User.self,
            FoodLog.self,
            WeightEntry.self,
            MealPlanRecord.self,
            ExercisePlanRecord.self,
            PartnerProfile.self,
            CustomRecipe.self,
            ProgressPhoto.self
        ])
        do {
            container = try ModelContainer(for: schema)
        } catch {
            // Migration failed — destroy corrupted store and recreate
            let config = ModelConfiguration(schema: schema)
            try? FileManager.default.removeItem(at: config.url)
            container = try! ModelContainer(for: schema)
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(container)
    }
}
