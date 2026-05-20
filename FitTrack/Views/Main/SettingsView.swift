import SwiftUI
import SwiftData

struct SettingsView: View {
    var profileVm: ProfileViewModel
    var partnerVm: PartnerViewModel
    var onLogout: () -> Void

    @State private var name = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var gender = "male"
    @State private var goal = "maintain"
    @State private var apiKey = ""
    @State private var dietaryPrefs = ""
    @State private var dislikedFoods = ""
    @State private var sport = ""
    @State private var savedBanner = false

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                if savedBanner {
                    Text("✓ Profile saved!")
                        .foregroundStyle(Color.fitGreen).padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.fitGreen.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }

                FitCard {
                    Text("Personal Details").font(.headline).foregroundStyle(Color.textPrimary)
                    VStack(spacing: 10) {
                        FitTextField(label: "Full Name", text: $name).padding(.top, 12)
                        HStack(spacing: 10) {
                            FitTextField(label: "Age", text: $age, keyboardType: .numberPad)
                            FitTextField(label: "Weight (kg)", text: $weight, keyboardType: .decimalPad)
                        }
                        FitTextField(label: "Height (cm)", text: $height, keyboardType: .numberPad)
                    }
                }

                FitCard {
                    Text("Gender").font(.headline).foregroundStyle(Color.textPrimary)
                    HStack(spacing: 10) {
                        ForEach([("male","Male"),("female","Female")], id: \.0) { val, label in
                            Button(label) { gender = val }
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(gender == val ? Color.fitGreenDark : Color.darkSurface)
                                .foregroundStyle(gender == val ? Color.white : Color.textSecondary)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.top, 8)
                }

                FitCard {
                    Text("Your Goal").font(.headline).foregroundStyle(Color.textPrimary)
                    VStack(alignment: .leading, spacing: 4) {
                        ForEach([("gain_muscle","Gain Muscle"),("lose_weight","Lose Weight"),("maintain","Maintain Weight"),("body_recomp","Body Recomposition")], id: \.0) { val, label in
                            Button {
                                goal = val
                            } label: {
                                HStack {
                                    Image(systemName: goal == val ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(goal == val ? Color.fitGreen : Color.textSecondary)
                                    Text(label).foregroundStyle(Color.textPrimary)
                                }
                            }
                            .padding(.vertical, 2)
                        }
                    }
                    .padding(.top, 8)
                }

                FitCard {
                    Text("Claude API Key").font(.headline).foregroundStyle(Color.textPrimary)
                    Text("Required for AI-generated meal and exercise plans")
                        .font(.system(size: 13)).foregroundStyle(Color.textSecondary).padding(.top, 2)
                    FitTextField(label: "sk-ant-...", text: $apiKey).padding(.top, 8)
                }

                FitCard {
                    Text("Dietary Preferences").font(.headline).foregroundStyle(Color.textPrimary)
                    Text("Used when generating your meal plan")
                        .font(.system(size: 13)).foregroundStyle(Color.textSecondary).padding(.top, 2)
                    FitTextField(label: "e.g. vegetarian, dairy-free, high protein", text: $dietaryPrefs).padding(.top, 8)
                    FitTextField(label: "Foods to avoid (e.g. mushrooms, fish, nuts)", text: $dislikedFoods).padding(.top, 8)
                }

                SportCard(sport: $sport)

                if let userId = profileVm.user?.id {
                    MyRecipesCard(userId: userId)
                }

                PartnerProfileCard(partnerVm: partnerVm)

                if case .error(let msg) = profileVm.saveState {
                    Text(msg).foregroundStyle(Color.fitRed).font(.system(size: 13))
                }

                FitButton(title: "Save Changes", action: {
                    Task {
                        await profileVm.saveProfile(
                            name: name, age: age, weightKg: weight, heightCm: height,
                            gender: gender, goal: goal, apiKey: apiKey,
                            dietaryPreferences: dietaryPrefs, dislikedFoods: dislikedFoods, sport: sport
                        )
                    }
                }, isLoading: profileVm.saveState == .loading)

                Button(role: .destructive) {
                    profileVm.logout { onLogout() }
                } label: {
                    Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(Color.fitRed).frame(maxWidth: .infinity)
                        .padding().background(Color.darkCard).clipShape(RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
        }
        .background(Color.darkBg)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear { prefill() }
        .onChange(of: profileVm.saveState) { _, newState in
            if case .saved = newState { savedBanner = true; profileVm.resetState() }
        }
    }

    private func prefill() {
        guard let u = profileVm.user else { return }
        name = u.name; age = u.age > 0 ? "\(u.age)" : ""
        weight = u.weightKg > 0 ? "\(u.weightKg)" : ""; height = u.heightCm > 0 ? "\(u.heightCm)" : ""
        gender = u.gender; goal = u.goal
        // Read API key from Keychain — it is no longer stored in the User model.
        apiKey = KeychainHelper.load(key: "apikey_\(u.id)") ?? ""
        dietaryPrefs = u.dietaryPreferences; dislikedFoods = u.dislikedFoods; sport = u.sport
    }
}

struct MyRecipesCard: View {
    let userId: String
    @Environment(\.modelContext) private var modelContext
    @State private var expanded = false
    @State private var recipes: [CustomRecipe] = []
    @State private var showAddForm = false
    @State private var newName = ""
    @State private var newMealType = "Any"
    @State private var newNotes = ""
    @State private var newCalories = ""
    @State private var newProtein = ""
    @State private var newCarbs = ""
    @State private var newFat = ""
    @State private var newIngredients = ""
    @State private var newMethod = ""

    private let mealTypes = ["Any", "Breakfast", "Lunch", "Dinner", "Snack"]

    var body: some View {
        FitCard {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "book.closed.fill").foregroundStyle(Color.fitGreen)
                    Text("My Recipes").font(.headline).foregroundStyle(Color.textPrimary)
                    Spacer()
                    if !recipes.isEmpty {
                        Text("\(recipes.count) saved").font(.system(size: 12)).foregroundStyle(Color.fitGreen)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(Color.textSecondary)
                }
            }

            if expanded {
                VStack(alignment: .leading, spacing: 12) {
                    if recipes.isEmpty && !showAddForm {
                        Text("Add your favourite recipes and they'll be included in your meal plan generation.")
                            .font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                            .padding(.top, 4)
                    }

                    ForEach(recipes, id: \.id) { recipe in
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(alignment: .top) {
                                VStack(alignment: .leading, spacing: 3) {
                                    HStack(spacing: 6) {
                                        Text(recipe.name)
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Color.textPrimary)
                                        if recipe.mealType != "Any" {
                                            Text(recipe.mealType)
                                                .font(.system(size: 11))
                                                .foregroundStyle(Color.fitGreen)
                                                .padding(.horizontal, 6).padding(.vertical, 2)
                                                .background(Color.fitGreen.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    if recipe.calories > 0 {
                                        HStack(spacing: 8) {
                                            Text("\(recipe.calories) kcal").foregroundStyle(Color.textPrimary)
                                            if recipe.proteinG > 0 { Text("P \(Int(recipe.proteinG))g").foregroundStyle(Color.fitBlue) }
                                            if recipe.carbsG > 0 { Text("C \(Int(recipe.carbsG))g").foregroundStyle(Color.fitOrange) }
                                            if recipe.fatG > 0 { Text("F \(Int(recipe.fatG))g").foregroundStyle(Color.fitRed) }
                                        }
                                        .font(.system(size: 12))
                                    }
                                    if !recipe.notes.isEmpty {
                                        Text(recipe.notes).font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    modelContext.delete(recipe)
                                    try? modelContext.save()
                                    loadRecipes()
                                } label: {
                                    Image(systemName: "trash").font(.system(size: 13)).foregroundStyle(Color.fitRed)
                                }
                            }
                            if !recipe.ingredients.isEmpty {
                                Text("Ingredients: \(recipe.ingredients.components(separatedBy: "\n").joined(separator: ", "))")
                                    .font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 6)
                        if recipe.id != recipes.last?.id {
                            Divider().background(Color.darkSurface)
                        }
                    }

                    if showAddForm {
                        VStack(spacing: 10) {
                            FitTextField(label: "Recipe name (e.g. Mum's Bolognese)", text: $newName)

                            HStack {
                                Text("Meal type").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                                Spacer()
                                Picker("", selection: $newMealType) {
                                    ForEach(mealTypes, id: \.self) { Text($0).tag($0) }
                                }
                                .pickerStyle(.menu).tint(Color.fitGreen)
                            }

                            HStack(spacing: 8) {
                                FitTextField(label: "Calories", text: $newCalories, keyboardType: .numberPad)
                                FitTextField(label: "Protein (g)", text: $newProtein, keyboardType: .decimalPad)
                            }
                            HStack(spacing: 8) {
                                FitTextField(label: "Carbs (g)", text: $newCarbs, keyboardType: .decimalPad)
                                FitTextField(label: "Fat (g)", text: $newFat, keyboardType: .decimalPad)
                            }

                            FitTextArea(label: "Ingredients (one per line)", text: $newIngredients)
                            FitTextArea(label: "Method", text: $newMethod)

                            FitTextField(label: "Notes (optional)", text: $newNotes)

                            HStack(spacing: 10) {
                                Button("Cancel") { showAddForm = false; resetForm() }
                                    .frame(maxWidth: .infinity).padding(10)
                                    .background(Color.darkSurface)
                                    .foregroundStyle(Color.textSecondary)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))

                                Button("Save Recipe") { saveRecipe() }
                                    .frame(maxWidth: .infinity).padding(10)
                                    .background(newName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.darkSurface : Color.fitGreen)
                                    .foregroundStyle(newName.trimmingCharacters(in: .whitespaces).isEmpty ? Color.textSecondary : Color.white)
                                    .fontWeight(.semibold)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                            }
                        }
                        .padding(.top, 4)
                    } else {
                        Button {
                            withAnimation { showAddForm = true }
                        } label: {
                            Label("Add Recipe", systemImage: "plus.circle.fill")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Color.fitGreen)
                        }
                        .padding(.top, 4)
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear { loadRecipes() }
    }

    private func loadRecipes() {
        let descriptor = FetchDescriptor<CustomRecipe>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.name)]
        )
        recipes = (try? modelContext.fetch(descriptor)) ?? []
    }

    private func saveRecipe() {
        let trimmed = newName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let recipe = CustomRecipe(
            userId: userId,
            name: trimmed,
            mealType: newMealType,
            notes: newNotes.trimmingCharacters(in: .whitespaces),
            calories: Int(newCalories) ?? 0,
            proteinG: Double(newProtein) ?? 0,
            carbsG: Double(newCarbs) ?? 0,
            fatG: Double(newFat) ?? 0,
            ingredients: newIngredients.trimmingCharacters(in: .whitespaces),
            method: newMethod.trimmingCharacters(in: .whitespaces)
        )
        modelContext.insert(recipe)
        try? modelContext.save()
        loadRecipes()
        showAddForm = false
        resetForm()
    }

    private func resetForm() {
        newName = ""; newMealType = "Any"; newNotes = ""
        newCalories = ""; newProtein = ""; newCarbs = ""; newFat = ""
        newIngredients = ""; newMethod = ""
    }
}

struct PartnerProfileCard: View {
    var partnerVm: PartnerViewModel
    @State private var expanded = false
    @State private var name = ""
    @State private var age = ""
    @State private var weight = ""
    @State private var height = ""
    @State private var gender = "female"
    @State private var goal = "maintain"
    @State private var dietaryPrefs = ""
    @State private var dislikedFoods = ""
    @State private var savedBanner = false

    var body: some View {
        FitCard {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
            } label: {
                HStack {
                    Image(systemName: "person.2.fill").foregroundStyle(Color.fitGreen)
                    Text("Partner Profile").font(.headline).foregroundStyle(Color.textPrimary)
                    Spacer()
                    if partnerVm.partner != nil {
                        Text("Added").font(.system(size: 12)).foregroundStyle(Color.fitGreen)
                    }
                    Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(Color.textSecondary)
                }
            }

            if expanded {
                VStack(spacing: 10) {
                    if savedBanner {
                        Text("✓ Partner profile saved!")
                            .foregroundStyle(Color.fitGreen).font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    FitTextField(label: "Partner's Name", text: $name).padding(.top, 4)
                    HStack(spacing: 10) {
                        FitTextField(label: "Age", text: $age, keyboardType: .numberPad)
                        FitTextField(label: "Weight (kg)", text: $weight, keyboardType: .decimalPad)
                    }
                    FitTextField(label: "Height (cm)", text: $height, keyboardType: .numberPad)

                    HStack(spacing: 10) {
                        ForEach([("male","Male"),("female","Female")], id: \.0) { val, label in
                            Button(label) { gender = val }
                                .font(.system(size: 13))
                                .padding(.horizontal, 14).padding(.vertical, 7)
                                .background(gender == val ? Color.fitGreenDark : Color.darkSurface)
                                .foregroundStyle(gender == val ? Color.white : Color.textSecondary)
                                .clipShape(Capsule())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Goal").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                        ForEach([("gain_muscle","Gain Muscle"),("lose_weight","Lose Weight"),("maintain","Maintain Weight"),("body_recomp","Body Recomposition")], id: \.0) { val, label in
                            Button {
                                goal = val
                            } label: {
                                HStack {
                                    Image(systemName: goal == val ? "largecircle.fill.circle" : "circle")
                                        .foregroundStyle(goal == val ? Color.fitGreen : Color.textSecondary)
                                    Text(label).font(.system(size: 14)).foregroundStyle(Color.textPrimary)
                                }
                            }
                            .padding(.vertical, 1)
                        }
                    }

                    FitTextField(label: "Dietary preferences (e.g. vegetarian)", text: $dietaryPrefs)
                    FitTextField(label: "Foods to avoid", text: $dislikedFoods)

                    if case .error(let msg) = partnerVm.saveState {
                        Text(msg).foregroundStyle(Color.fitRed).font(.system(size: 13))
                    }

                    HStack(spacing: 10) {
                        FitButton(title: "Save Partner", action: {
                            Task {
                                await partnerVm.save(name: name, age: age, weightKg: weight, heightCm: height,
                                                     gender: gender, goal: goal,
                                                     dietaryPreferences: dietaryPrefs, dislikedFoods: dislikedFoods)
                            }
                        }, isLoading: partnerVm.saveState == .loading,
                           enabled: !name.isEmpty && !age.isEmpty && !weight.isEmpty && !height.isEmpty)

                        if partnerVm.partner != nil {
                            Button {
                                partnerVm.delete()
                                resetFields()
                            } label: {
                                Image(systemName: "trash").foregroundStyle(Color.fitRed).padding(12)
                                    .background(Color.darkSurface).clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                    }
                }
                .padding(.top, 8)
            }
        }
        .onAppear { prefillPartner() }
        .onChange(of: partnerVm.saveState) { _, state in
            if case .saved = state { savedBanner = true; partnerVm.resetState() }
        }
    }

    private func prefillPartner() {
        guard let p = partnerVm.partner else { return }
        name = p.name; age = p.age > 0 ? "\(p.age)" : ""
        weight = p.weightKg > 0 ? "\(p.weightKg)" : ""; height = p.heightCm > 0 ? "\(p.heightCm)" : ""
        gender = p.gender; goal = p.goal
        dietaryPrefs = p.dietaryPreferences; dislikedFoods = p.dislikedFoods
    }

    private func resetFields() {
        name = ""; age = ""; weight = ""; height = ""
        gender = "female"; goal = "maintain"; dietaryPrefs = ""; dislikedFoods = ""
    }
}
