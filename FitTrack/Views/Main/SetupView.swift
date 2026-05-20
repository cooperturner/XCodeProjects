import SwiftUI

struct SetupView: View {
    var profileVm: ProfileViewModel
    var onSetupComplete: () -> Void

    var body: some View {
        ProfileFormView(profileVm: profileVm, isSetup: true, onSaved: onSetupComplete)
            .navigationBarBackButtonHidden(true)
    }
}

struct ProfileFormView: View {
    var profileVm: ProfileViewModel
    var isSetup: Bool
    var onSaved: (() -> Void)?
    var onLogout: (() -> Void)?

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
                if isSetup {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Set Up Your Profile").font(.title).bold().foregroundStyle(Color.textPrimary)
                        Text("We'll use this to personalise your plans").foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    HStack {
                        Image(systemName: "gearshape.fill").foregroundStyle(Color.fitGreen).font(.title2)
                        Text("Settings").font(.title2).bold().foregroundStyle(Color.textPrimary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    if savedBanner {
                        Text("✓ Profile saved!").foregroundStyle(Color.fitGreen)
                            .padding(10).frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.fitGreen.opacity(0.15)).clipShape(RoundedRectangle(cornerRadius: 10))
                    }
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
                    Text("Required for AI meal and exercise plan generation.")
                        .font(.system(size: 13)).foregroundStyle(Color.textSecondary).padding(.top, 2)
                    FitTextField(label: "sk-ant-...", text: $apiKey).padding(.top, 8)
                }

                FitCard {
                    Text("Dietary Preferences").font(.headline).foregroundStyle(Color.textPrimary)
                    Text("Optional — used when generating your meal plan")
                        .font(.system(size: 13)).foregroundStyle(Color.textSecondary).padding(.top, 2)
                    FitTextField(label: "e.g. vegetarian, dairy-free, high protein", text: $dietaryPrefs).padding(.top, 8)
                    FitTextField(label: "Foods to avoid (e.g. mushrooms, fish, nuts)", text: $dislikedFoods).padding(.top, 8)
                }

                SportCard(sport: $sport)

                if case .error(let msg) = profileVm.saveState {
                    Text(msg).foregroundStyle(Color.fitRed).font(.system(size: 13))
                }

                FitButton(title: isSetup ? "Save & Continue" : "Save Changes", action: {
                    Task {
                        await profileVm.saveProfile(
                            name: name, age: age, weightKg: weight, heightCm: height,
                            gender: gender, goal: goal, apiKey: apiKey,
                            dietaryPreferences: dietaryPrefs, dislikedFoods: dislikedFoods, sport: sport
                        )
                    }
                }, isLoading: profileVm.saveState == .loading,
                   enabled: !name.isEmpty && !age.isEmpty && !weight.isEmpty && !height.isEmpty)

                if !isSetup {
                    Button(role: .destructive) {
                        profileVm.logout { onLogout?() }
                    } label: {
                        Label("Log Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundStyle(Color.fitRed).frame(maxWidth: .infinity)
                            .padding().background(Color.darkCard).clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
        }
        .background(Color.darkBg)
        .onAppear { prefill() }
        .onChange(of: profileVm.saveState) { _, newState in
            if case .saved = newState {
                if isSetup { onSaved?() }
                else { savedBanner = true; profileVm.resetState() }
            }
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

extension ProfileSaveState: Equatable {
    static func == (lhs: ProfileSaveState, rhs: ProfileSaveState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading), (.saved, .saved): return true
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
