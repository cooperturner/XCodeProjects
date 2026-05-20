import SwiftUI

struct MainTabView: View {
    @Environment(\.modelContext) var modelContext
    var onLogout: () -> Void

    @State private var profileVm: ProfileViewModel?
    @State private var trackerVm: TrackerViewModel?
    @State private var planVm: PlanViewModel?
    @State private var progressVm: ProgressViewModel?
    @State private var partnerVm: PartnerViewModel?

    var body: some View {
        let pVm  = profileVm  ?? { let v = ProfileViewModel(modelContext: modelContext);  profileVm  = v; return v }()
        let tVm  = trackerVm  ?? { let v = TrackerViewModel(modelContext: modelContext);  trackerVm  = v; return v }()
        let plVm = planVm     ?? { let v = PlanViewModel(modelContext: modelContext);     planVm     = v; return v }()
        let prVm = progressVm ?? { let v = ProgressViewModel(modelContext: modelContext); progressVm = v; return v }()
        let ptVm = partnerVm  ?? { let v = PartnerViewModel(modelContext: modelContext);  partnerVm  = v; return v }()

        TabView {
            HomeView(profileVm: pVm, trackerVm: tVm, planVm: plVm)
                .tabItem { Label("Home", systemImage: "house.fill") }

            TrackerView(vm: tVm, user: pVm.user)
                .tabItem { Label("Tracker", systemImage: "plus.circle.fill") }

            MealPlanView(vm: plVm, partnerVm: ptVm, trackerVm: tVm)
                .tabItem { Label("Meals", systemImage: "fork.knife") }

            ExercisePlanView(vm: plVm)
                .tabItem { Label("Exercise", systemImage: "figure.strengthtraining.traditional") }

            NavigationStack {
                WeightProgressView(vm: prVm, onNavigateSettings: {})
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            NavigationLink(destination: SettingsView(profileVm: pVm, partnerVm: ptVm, onLogout: onLogout)) {
                                Image(systemName: "gearshape.fill").foregroundStyle(Color.textSecondary)
                            }
                        }
                    }
            }
            .tabItem { Label("Progress", systemImage: "chart.line.uptrend.xyaxis") }
        }
        .tint(Color.fitGreen)
        .preferredColorScheme(.dark)
    }
}
