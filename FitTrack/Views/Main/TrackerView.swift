import SwiftUI

struct TrackerView: View {
    var vm: TrackerViewModel
    var user: User?
    @State private var showAddDialog = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading) {
                        Text("Food Tracker").font(.title2).bold().foregroundStyle(Color.textPrimary)
                        Text("Log your meals for today").foregroundStyle(Color.textSecondary).font(.subheadline)
                    }
                    Spacer()
                    Button { showAddDialog = true } label: {
                        Image(systemName: "plus.circle.fill").font(.title).foregroundStyle(Color.fitGreen)
                    }
                }

                FitCard { CalorieProgressBar(consumed: vm.totalCalories, target: user?.dailyCalorieTarget ?? 2000) }

                if let u = user {
                    let macros = MacroTargets.calculate(weightKg: u.weightKg, calories: u.dailyCalorieTarget, goal: u.goal)
                    FitCard {
                        Text("Daily Macros").font(.subheadline).foregroundStyle(Color.textSecondary)
                        VStack(spacing: 10) {
                            MacroRow(label: "Protein", consumed: Int(vm.totalProtein), target: macros.proteinG, color: .fitBlue)
                            MacroRow(label: "Carbs",   consumed: Int(vm.totalCarbs),   target: macros.carbsG, color: .fitOrange)
                            MacroRow(label: "Fat",     consumed: Int(vm.totalFat),     target: macros.fatG, color: .fitRed)
                        }
                        .padding(.top, 8)
                    }
                }

                Text("Today's Meals").font(.headline).foregroundStyle(Color.textPrimary)

                if vm.logs.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "fork.knife").font(.system(size: 44)).foregroundStyle(Color.textSecondary)
                        Text("No meals logged yet").foregroundStyle(Color.textSecondary)
                        Text("Tap + to add your first meal").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                } else {
                    ForEach(vm.logs, id: \.id) { log in
                        FoodLogRow(log: log, onDelete: { vm.deleteLog(log) })
                    }
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
        }
        .background(Color.darkBg)
        .sheet(isPresented: $showAddDialog) {
            AddFoodSheet(vm: vm, user: user, onDismiss: { showAddDialog = false })
        }
        .onAppear { vm.loadToday() }
    }
}

struct FoodLogRow: View {
    let log: FoodLog
    let onDelete: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(log.foodName).fontWeight(.medium).foregroundStyle(Color.textPrimary)
                Text(log.mealType.capitalized).font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                if log.proteinG > 0 || log.carbsG > 0 || log.fatG > 0 {
                    Text("P: \(Int(log.proteinG))g  C: \(Int(log.carbsG))g  F: \(Int(log.fatG))g")
                        .font(.system(size: 11)).foregroundStyle(Color.textSecondary)
                }
            }
            Spacer()
            Text("\(log.calories) kcal").foregroundStyle(Color.fitGreen).fontWeight(.bold)
            Button { onDelete() } label: {
                Image(systemName: "trash").foregroundStyle(Color.textSecondary).font(.system(size: 16))
            }
            .padding(.leading, 8)
        }
        .padding(12)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

struct AddFoodSheet: View {
    var vm: TrackerViewModel
    var user: User?
    var onDismiss: () -> Void

    @State private var foodName = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""
    @State private var mealType = "snack"
    @State private var showPlanPicker = true

    private let mealTypes = ["breakfast", "lunch", "dinner", "snack"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Planned meals picker
                    if !vm.todayPlannedMeals.isEmpty {
                        FitCard {
                            Button {
                                withAnimation { showPlanPicker.toggle() }
                            } label: {
                                HStack {
                                    Text("Pick from today's plan").font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fitGreen)
                                    Spacer()
                                    Image(systemName: showPlanPicker ? "chevron.up" : "chevron.down").foregroundStyle(Color.fitGreen)
                                }
                            }
                            if showPlanPicker {
                                VStack(spacing: 8) {
                                    ForEach(vm.todayPlannedMeals) { meal in
                                        Button {
                                            foodName = meal.name
                                            calories = "\(meal.calories)"
                                            protein = "\(meal.protein)"
                                            carbs = "\(meal.carbs)"
                                            fat = "\(meal.fat)"
                                            mealType = meal.type.lowercased()
                                            showPlanPicker = false
                                        } label: {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(meal.type.uppercased())
                                                        .font(.system(size: 9, weight: .bold)).tracking(1).foregroundStyle(Color.fitGreen)
                                                    Text(meal.name).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.textPrimary)
                                                    Text("P \(meal.protein)g  C \(meal.carbs)g  F \(meal.fat)g")
                                                        .font(.system(size: 11)).foregroundStyle(Color.textSecondary)
                                                }
                                                Spacer()
                                                Text("\(meal.calories) kcal").font(.system(size: 13, weight: .bold)).foregroundStyle(Color.fitGreen)
                                            }
                                            .padding(10).background(Color.darkSurface).clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                                .padding(.top, 8)
                            }
                        }
                    }

                    FitTextField(label: "Food Name", text: $foodName)

                    if !(user?.apiKey ?? "").isEmpty {
                        Button {
                            guard !foodName.isEmpty else { return }
                            vm.estimateCalories(apiKey: user!.apiKey, foodName: foodName)
                        } label: {
                            HStack {
                                if vm.isEstimating { ProgressView().tint(Color.fitGreen).scaleEffect(0.8) }
                                Text(vm.isEstimating ? "Estimating…" : "Estimate with AI")
                            }
                            .frame(maxWidth: .infinity).padding(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.fitGreen, lineWidth: 1))
                            .foregroundStyle(Color.fitGreen)
                        }
                        .disabled(foodName.isEmpty || vm.isEstimating)
                    }

                    if !vm.estimateResult.isEmpty {
                        Text(vm.estimateResult).font(.system(size: 13)).foregroundStyle(Color.textPrimary)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.fitGreen.opacity(0.1)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    if !vm.error.isEmpty {
                        Text(vm.error).foregroundStyle(Color.fitRed).font(.system(size: 12))
                    }

                    FitTextField(label: "Calories (kcal)", text: $calories, keyboardType: .numberPad)
                    HStack(spacing: 8) {
                        FitTextField(label: "Protein (g)", text: $protein, keyboardType: .decimalPad)
                        FitTextField(label: "Carbs (g)", text: $carbs, keyboardType: .decimalPad)
                        FitTextField(label: "Fat (g)", text: $fat, keyboardType: .decimalPad)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Meal Type").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                        HStack(spacing: 8) {
                            ForEach(mealTypes, id: \.self) { t in
                                Button(t.capitalized) { mealType = t }
                                    .font(.system(size: 12))
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(mealType == t ? Color.fitGreenDark : Color.darkSurface)
                                    .foregroundStyle(mealType == t ? Color.white : Color.textSecondary)
                                    .clipShape(Capsule())
                            }
                        }
                    }

                    FitButton(title: "Add", action: {
                        vm.addLog(
                            foodName: foodName,
                            calories: Int(calories) ?? 0,
                            protein: Float(protein) ?? 0,
                            carbs: Float(carbs) ?? 0,
                            fat: Float(fat) ?? 0,
                            mealType: mealType
                        )
                        vm.clearEstimate()
                        onDismiss()
                    }, enabled: !foodName.isEmpty && !calories.isEmpty)
                }
                .padding(16)
            }
            .background(Color.darkBg)
            .navigationTitle("Log a Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") { vm.clearEstimate(); onDismiss() }.foregroundStyle(Color.textSecondary)
                }
            }
        }
        .presentationDetents([.large])
    }
}
