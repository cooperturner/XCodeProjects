import SwiftUI

struct MealPlanView: View {
    var vm: PlanViewModel
    var partnerVm: PartnerViewModel
    var trackerVm: TrackerViewModel
    @State private var showShoppingList = false
    @State private var showMealRequestSheet = false
    @State private var mealRequestInput = ""
    @State private var selectedProfile = 0
    @AppStorage("weeklyBudget") private var weeklyBudget: Double = 200

    private var today: String {
        Calendar.current.weekdaySymbols[Calendar.current.component(.weekday, from: Date()) - 1]
    }
    private var weekLabel: String {
        let cal = Calendar.current
        let today = Date()
        let daysFromSunday = cal.component(.weekday, from: today) - 1
        let sun = cal.date(byAdding: .day, value: -daysFromSunday, to: today) ?? today
        let sat = cal.date(byAdding: .day, value: 6, to: sun) ?? today
        let f = DateFormatter(); f.dateFormat = "MMM d"
        return "\(f.string(from: sun)) – \(f.string(from: sat))"
    }

    private var hasPartner: Bool { partnerVm.partner != nil }
    private var partnerName: String { partnerVm.partner?.name ?? "Partner" }
    private var showingPartner: Bool { selectedProfile == 1 }
    private var activePlan: WeeklyMealPlan? { showingPartner ? vm.partnerPlan : vm.mealPlan }
    private var isGenerating: Bool { showingPartner ? vm.isGeneratingPartner : vm.isGeneratingMeal }

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "fork.knife").foregroundStyle(Color.fitGreen).font(.title2)
                    VStack(alignment: .leading) {
                        Text("Meal Plan").font(.title2).bold().foregroundStyle(Color.textPrimary)
                        Text("Week of \(weekLabel)").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                    if vm.mealPlan != nil {
                        Button { showShoppingList = true } label: {
                            Image(systemName: "cart.fill").foregroundStyle(Color.fitGreen).font(.title2)
                        }
                    }
                }

                if hasPartner {
                    Picker("Profile", selection: $selectedProfile) {
                        Text("My Plan").tag(0)
                        Text(partnerName + "'s Plan").tag(1)
                    }
                    .pickerStyle(.segmented)
                }

                FitButton(
                    title: activePlan == nil ? "Generate \(showingPartner ? partnerName + "'s" : "My") Plan" : "Regenerate \(showingPartner ? partnerName + "'s" : "My") Plan",
                    action: { mealRequestInput = ""; showMealRequestSheet = true },
                    isLoading: isGenerating
                )
                .sheet(isPresented: $showMealRequestSheet) {
                    MealRequestSheet(
                        profileName: showingPartner ? partnerName : "your",
                        input: $mealRequestInput,
                        onGenerate: { requests in
                            if showingPartner, let partner = partnerVm.partner {
                                vm.generatePartnerPlan(partner: partner, weeklyBudget: weeklyBudget, mealRequests: requests)
                            } else {
                                vm.generateMealPlan(weeklyBudget: weeklyBudget, mealRequests: requests)
                            }
                        }
                    )
                }

                ErrorBanner(message: vm.error) { vm.clearError() }

                if isGenerating {
                    FitCard {
                        VStack(spacing: 12) {
                            ProgressView().tint(Color.fitGreen)
                            Text("Generating \(showingPartner ? partnerName + "'s" : "your") personalised meal plan…")
                                .foregroundStyle(Color.textSecondary).font(.system(size: 13))
                            Text("This may take up to 30 seconds").foregroundStyle(Color.textSecondary).font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }

                if let plan = activePlan, !isGenerating {
                    ForEach(plan.days) { dayPlan in
                        let isToday = dayPlan.day.lowercased() == today.lowercased()
                        DayMealCard(
                            dayPlan: dayPlan,
                            defaultExpanded: isToday,
                            swappingKey: vm.swappingKey,
                            isReplanning: isToday && !showingPartner && vm.isReplanningToday,
                            onReplan: isToday && !showingPartner ? {
                                vm.replanRemainingMeals(
                                    day: dayPlan.day,
                                    consumedCalories: trackerVm.totalCalories,
                                    consumedProtein: trackerVm.totalProtein,
                                    consumedCarbs: trackerVm.totalCarbs,
                                    consumedFat: trackerVm.totalFat,
                                    loggedMealTypes: Set(trackerVm.logs.map { $0.mealType })
                                )
                            } : nil,
                            onSwap: { meal in
                                if showingPartner {
                                    vm.swapPartnerMeal(day: dayPlan.day, meal: meal, partner: partnerVm.partner)
                                } else {
                                    vm.swapMeal(day: dayPlan.day, meal: meal)
                                }
                            }
                        )
                    }
                }

                if activePlan == nil && !isGenerating {
                    VStack(spacing: 10) {
                        Image(systemName: "fork.knife").font(.system(size: 44)).foregroundStyle(Color.textSecondary)
                        Text("No plan yet for \(showingPartner ? partnerName : "you")").foregroundStyle(Color.textSecondary)
                        Text("Tap Generate to create the plan").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
        }
        .background(Color.darkBg)
        .sheet(isPresented: $showShoppingList) {
            ShoppingListView(vm: vm, partnerName: partnerVm.partner?.name ?? "")
        }
    }
}

struct MealRequestSheet: View {
    let profileName: String
    @Binding var input: String
    let onGenerate: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Any specific meals for \(profileName) plan?")
                        .font(.headline).foregroundStyle(Color.textPrimary)
                    Text("Optional — Claude will build the week around whatever you request.")
                        .font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                }

                ZStack(alignment: .topLeading) {
                    RoundedRectangle(cornerRadius: 12).fill(Color.darkSurface)
                    if input.isEmpty {
                        Text("e.g. Spaghetti bolognese on Tuesday, BBQ chicken on Sunday, salmon on Friday…")
                            .font(.system(size: 14)).foregroundStyle(Color.textSecondary)
                            .padding(12)
                    }
                    TextEditor(text: $input)
                        .font(.system(size: 14)).foregroundStyle(Color.textPrimary)
                        .scrollContentBackground(.hidden)
                        .padding(8)
                }
                .frame(minHeight: 140)

                Spacer()

                HStack(spacing: 12) {
                    Button {
                        dismiss()
                        onGenerate("")
                    } label: {
                        Text("Skip")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.darkSurface)
                            .foregroundStyle(Color.textSecondary)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Button {
                        dismiss()
                        onGenerate(input)
                    } label: {
                        Text("Generate Plan")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.fitGreen)
                            .foregroundStyle(.white)
                            .fontWeight(.semibold)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(24)
            .background(Color.darkBg)
            .navigationTitle("Meal Requests")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
        }
        .presentationDetents([.medium])
        .preferredColorScheme(.dark)
    }
}

struct DayMealCard: View {
    let dayPlan: DayMealPlan
    let defaultExpanded: Bool
    let swappingKey: String?
    let isReplanning: Bool
    let onReplan: (() -> Void)?
    let onSwap: (MealItem) -> Void

    @State private var expanded: Bool

    init(dayPlan: DayMealPlan, defaultExpanded: Bool, swappingKey: String?, isReplanning: Bool = false, onReplan: (() -> Void)? = nil, onSwap: @escaping (MealItem) -> Void) {
        self.dayPlan = dayPlan
        self.defaultExpanded = defaultExpanded
        self.swappingKey = swappingKey
        self.isReplanning = isReplanning
        self.onReplan = onReplan
        self.onSwap = onSwap
        _expanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayPlan.day).font(.headline).foregroundStyle(Color.textPrimary)
                    Text("\(dayPlan.totalCalories) kcal total").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                }
                Spacer()
                if let onReplan {
                    Button {
                        if !isReplanning { onReplan() }
                    } label: {
                        if isReplanning {
                            ProgressView().tint(Color.fitGreen).scaleEffect(0.75).frame(width: 24, height: 24)
                        } else {
                            Label("Re-plan today", systemImage: "arrow.triangle.2.circlepath")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(Color.fitGreen)
                                .padding(.horizontal, 8).padding(.vertical, 4)
                                .background(Color.fitGreen.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.trailing, 6)
                }
                Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(Color.textSecondary)
            }
            .padding(16)
            .contentShape(Rectangle())
            .onTapGesture { withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() } }

            if expanded {
                Divider().background(Color.darkSurface)
                VStack(spacing: 0) {
                    ForEach(Array(dayPlan.meals.enumerated()), id: \.element.id) { idx, meal in
                        if idx > 0 { Divider().background(Color.darkSurface).padding(.horizontal, 16) }
                        MealRowView(
                            meal: meal,
                            isSwapping: swappingKey == "\(dayPlan.day)_\(meal.type)",
                            onSwap: { onSwap(meal) }
                        )
                        .padding(16)
                    }
                }
            }
        }
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct MealRowView: View {
    let meal: MealItem
    let isSwapping: Bool
    let onSwap: () -> Void
    @State private var showDetails = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(meal.type.uppercased())
                        .font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Color.fitGreen)
                    Text(meal.name).font(.headline).foregroundStyle(Color.textPrimary)
                    HStack(spacing: 8) {
                        Text("\(meal.calories) kcal").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.textPrimary)
                        Text("P \(meal.protein)g").font(.system(size: 12)).foregroundStyle(Color.fitBlue)
                        Text("C \(meal.carbs)g").font(.system(size: 12)).foregroundStyle(Color.fitOrange)
                        Text("F \(meal.fat)g").font(.system(size: 12)).foregroundStyle(Color.fitRed)
                    }
                }
                Spacer()
                Button { if !isSwapping { onSwap() } } label: {
                    if isSwapping {
                        ProgressView().tint(Color.fitGreen).scaleEffect(0.8).frame(width: 24, height: 24)
                    } else {
                        Image(systemName: "arrow.left.arrow.right").foregroundStyle(Color.fitGreen)
                    }
                }
                .frame(width: 44, height: 44)
            }

            Button {
                withAnimation { showDetails.toggle() }
            } label: {
                HStack(spacing: 4) {
                    Text(showDetails ? "Hide details" : "Ingredients & prep")
                        .font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                    Image(systemName: showDetails ? "chevron.up" : "chevron.down")
                        .font(.system(size: 11)).foregroundStyle(Color.textSecondary)
                }
            }

            if showDetails {
                VStack(alignment: .leading, spacing: 6) {
                    if !meal.ingredients.isEmpty {
                        Text("Ingredients").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.textSecondary)
                        ForEach(meal.ingredients, id: \.self) { i in
                            Text("• \(i)").font(.system(size: 13)).foregroundStyle(Color.textPrimary)
                        }
                    }
                    if !meal.prep.isEmpty {
                        Text("Preparation").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.textSecondary).padding(.top, 4)
                        Text(meal.prep).font(.system(size: 13)).foregroundStyle(Color.textPrimary)
                    }
                }
            }
        }
    }
}
