import SwiftUI

struct HomeView: View {
    var profileVm: ProfileViewModel
    var trackerVm: TrackerViewModel
    var planVm: PlanViewModel

    @State private var loggingExercise: ExerciseItem? = nil
    @State private var historyExercise: ExerciseItem? = nil

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Good morning" }
        if hour < 17 { return "Good afternoon" }
        return "Good evening"
    }

    private var todayDayPlan: DayExercisePlan? {
        let f = DateFormatter(); f.dateFormat = "EEEE"
        let name = f.string(from: Date())
        return planVm.exercisePlan?.days.first { $0.day.caseInsensitiveCompare(name) == .orderedSame }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Greeting
                VStack(alignment: .leading, spacing: 4) {
                    Text(greeting).font(.subheadline).foregroundStyle(Color.textSecondary)
                    Text(profileVm.user?.name.isEmpty == false ? profileVm.user!.name : "Athlete")
                        .font(.title).bold().foregroundStyle(Color.textPrimary)
                }

                // Calorie snapshot
                FitCard {
                    HStack {
                        Image(systemName: "flame.fill").foregroundStyle(Color.fitGreen)
                        Text("Today's Calories").font(.headline).foregroundStyle(Color.textPrimary)
                    }
                    CalorieProgressBar(
                        consumed: trackerVm.totalCalories,
                        target: profileVm.user?.dailyCalorieTarget ?? 2000
                    )
                    .padding(.top, 8)
                }

                // Macro snapshot
                if let user = profileVm.user {
                    FitCard {
                        Text("Daily Macros").font(.subheadline).foregroundStyle(Color.textSecondary)
                        let macros = MacroTargets.calculate(weightKg: user.weightKg, calories: user.dailyCalorieTarget, goal: user.goal)
                        VStack(spacing: 10) {
                            MacroRow(label: "Protein", consumed: Int(trackerVm.totalProtein), target: macros.proteinG, color: .fitBlue)
                            MacroRow(label: "Carbs",   consumed: Int(trackerVm.totalCarbs),   target: macros.carbsG,   color: .fitOrange)
                            MacroRow(label: "Fat",     consumed: Int(trackerVm.totalFat),     target: macros.fatG,     color: .fitRed)
                        }
                        .padding(.top, 8)
                    }
                }

                // Today's workout
                TodayWorkoutCard(
                    dayPlan: todayDayPlan,
                    completedExercises: planVm.completedExercises,
                    onToggle: { exercise in
                        if planVm.completedExercises.contains(exercise.name) {
                            planVm.markExerciseIncomplete(exercise.name)
                        } else if exercise.isWeightBased {
                            loggingExercise = exercise
                        } else {
                            planVm.markExerciseCompleted(exercise.name)
                        }
                    },
                    onViewHistory: { historyExercise = $0 }
                )

                // Quick stats
                if let user = profileVm.user {
                    HStack(spacing: 12) {
                        QuickStatCard(icon: "scalemass.fill", label: "Weight", value: String(format: "%.1f kg", user.weightKg))
                        QuickStatCard(icon: "target",         label: "Goal",   value: goalLabel(user.goal))
                        QuickStatCard(icon: "burn",           label: "Target", value: "\(user.dailyCalorieTarget) kcal")
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
        }
        .background(Color.darkBg)
        .onAppear { trackerVm.loadToday() }
        .sheet(item: $loggingExercise) { exercise in
            SetLogSheet(exercise: exercise) { sets in
                planVm.saveSetLog(exerciseName: exercise.name, sets: sets)
            } onSkip: {
                planVm.markExerciseCompleted(exercise.name)
            }
        }
        .sheet(item: $historyExercise) { exercise in
            WorkoutProgressionSheet(
                exercise: exercise,
                progression: planVm.progressionFor(exerciseName: exercise.name)
            )
        }
    }

    private func goalLabel(_ goal: String) -> String {
        switch goal {
        case "gain_muscle": return "Gain Muscle"
        case "lose_weight": return "Lose Weight"
        case "body_recomp": return "Recomp"
        default:            return "Maintain"
        }
    }
}

// MARK: - Today's Workout Card

private struct TodayWorkoutCard: View {
    let dayPlan: DayExercisePlan?
    let completedExercises: Set<String>
    let onToggle: (ExerciseItem) -> Void
    let onViewHistory: (ExerciseItem) -> Void

    var body: some View {
        FitCard {
            HStack {
                Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(Color.fitGreen)
                Text("Today's Workout").font(.headline).foregroundStyle(Color.textPrimary)
                Spacer()
                if let plan = dayPlan, !plan.isRest {
                    let done = plan.exercises.filter { completedExercises.contains($0.name) }.count
                    Text("\(done)/\(plan.exercises.count)")
                        .font(.subheadline).bold()
                        .foregroundStyle(Color.fitGreen)
                }
            }

            if let plan = dayPlan {
                if plan.isRest {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill").foregroundStyle(Color.textSecondary)
                        Text("Rest Day — Take it easy today!")
                            .font(.subheadline).foregroundStyle(Color.textSecondary)
                    }
                    .padding(.top, 6)
                } else {
                    Text("\(plan.workoutType)  •  \(plan.duration)")
                        .font(.caption).foregroundStyle(Color.textSecondary)
                        .padding(.top, 2)
                    Divider().padding(.vertical, 8)
                    ForEach(Array(plan.exercises.enumerated()), id: \.element.id) { index, exercise in
                        ExerciseCheckRow(
                            exercise: exercise,
                            isCompleted: completedExercises.contains(exercise.name),
                            onToggle: { onToggle(exercise) },
                            onViewHistory: { onViewHistory(exercise) }
                        )
                        if index < plan.exercises.count - 1 {
                            Divider()
                        }
                    }
                }
            } else {
                Text("No exercise plan yet — generate one in the Exercise tab.")
                    .font(.subheadline).foregroundStyle(Color.textSecondary)
                    .padding(.top, 6)
            }
        }
    }
}

// MARK: - Exercise Check Row

private struct ExerciseCheckRow: View {
    let exercise: ExerciseItem
    let isCompleted: Bool
    let onToggle: () -> Void
    let onViewHistory: () -> Void

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            // Checkbox + label — tap to toggle
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isCompleted ? Color.fitGreen : Color.textSecondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(exercise.name)
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(isCompleted ? Color.textSecondary : Color.textPrimary)
                        .strikethrough(isCompleted, color: Color.textSecondary)
                    Text("\(exercise.sets) sets × \(exercise.reps)  •  \(exercise.rest) rest")
                        .font(.caption).foregroundStyle(Color.textSecondary)
                }
                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture { onToggle() }

            // History button — only shown for weight-based exercises
            if exercise.isWeightBased {
                Button(action: onViewHistory) {
                    Image(systemName: "chart.line.uptrend.xyaxis")
                        .font(.subheadline)
                        .foregroundStyle(Color.textSecondary)
                        .padding(6)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Set Log Sheet

private struct SetEntry {
    var weight: String = ""
    var reps: String = ""
}

private struct SetLogSheet: View {
    let exercise: ExerciseItem
    let onSave: ([(Float, Int)]) -> Void
    let onSkip: () -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var entries: [SetEntry] = []

    private var setCount: Int { max(exercise.sets, 1) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Planned: \(exercise.sets) sets × \(exercise.reps) reps")
                        .font(.subheadline).foregroundStyle(Color.textSecondary)
                        .padding(.horizontal)

                    if !exercise.notes.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "lightbulb.fill").foregroundStyle(Color.fitGreen).font(.caption)
                            Text(exercise.notes).font(.caption).foregroundStyle(Color.textSecondary)
                        }
                        .padding(.horizontal)
                    }

                    ForEach(entries.indices, id: \.self) { i in
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Set \(i + 1)")
                                .font(.subheadline).bold()
                                .foregroundStyle(Color.textSecondary)
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Weight (kg)")
                                        .font(.caption).foregroundStyle(Color.textSecondary)
                                    TextField("0.0", text: $entries[i].weight)
                                        .keyboardType(.decimalPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Reps completed")
                                        .font(.caption).foregroundStyle(Color.textSecondary)
                                    TextField("0", text: $entries[i].reps)
                                        .keyboardType(.numberPad)
                                        .textFieldStyle(.roundedBorder)
                                }
                            }
                        }
                        .padding()
                        .background(Color.darkCard)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(Color.darkBg)
            .navigationTitle("Log \(exercise.name)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Skip") {
                        onSkip()
                        dismiss()
                    }
                    .foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save & Complete") {
                        let sets: [(Float, Int)] = entries.compactMap { e in
                            guard let w = Float(e.weight), let r = Int(e.reps) else { return nil }
                            return (w, r)
                        }
                        onSave(sets)
                        dismiss()
                    }
                    .bold().foregroundStyle(Color.fitGreen)
                }
            }
            .onAppear {
                if entries.isEmpty {
                    entries = Array(repeating: SetEntry(), count: setCount)
                }
            }
        }
    }
}

// MARK: - Workout Progression Sheet

private struct WorkoutProgressionSheet: View {
    let exercise: ExerciseItem
    let progression: [(date: String, sets: [(weightKg: Float, reps: Int)])]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if progression.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 48)).foregroundStyle(Color.textSecondary)
                        Text("No history yet")
                            .font(.title3).bold().foregroundStyle(Color.textPrimary)
                        Text("Complete this exercise and log your sets to start tracking progression.")
                            .font(.subheadline).foregroundStyle(Color.textSecondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Planned: \(exercise.sets) sets × \(exercise.reps) reps")
                                .font(.caption).foregroundStyle(Color.textSecondary)
                                .padding(.horizontal)

                            ForEach(progression, id: \.date) { entry in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text(formattedDate(entry.date))
                                            .font(.subheadline).bold().foregroundStyle(Color.textSecondary)
                                        Spacer()
                                        let best = entry.sets.map(\.weightKg).max() ?? 0
                                        Text(String(format: "Best: %.1f kg", best))
                                            .font(.caption).foregroundStyle(Color.fitGreen)
                                    }
                                    VStack(spacing: 6) {
                                        ForEach(entry.sets.indices, id: \.self) { i in
                                            HStack {
                                                Text("Set \(i + 1)")
                                                    .font(.caption).foregroundStyle(Color.textSecondary)
                                                    .frame(width: 38, alignment: .leading)
                                                Text(String(format: "%.1f kg", entry.sets[i].weightKg))
                                                    .font(.subheadline).fontWeight(.semibold).foregroundStyle(Color.textPrimary)
                                                Text("×").font(.caption).foregroundStyle(Color.textSecondary)
                                                Text("\(entry.sets[i].reps) reps")
                                                    .font(.subheadline).foregroundStyle(Color.textPrimary)
                                                Spacer()
                                            }
                                        }
                                    }
                                    .padding()
                                    .background(Color.darkCard)
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        .padding()
                    }
                }
            }
            .background(Color.darkBg)
            .navigationTitle("\(exercise.name) History")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.fitGreen)
                }
            }
        }
    }

    private func formattedDate(_ s: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let d = f.date(from: s) else { return s }
        let out = DateFormatter(); out.dateStyle = .medium
        return out.string(from: d)
    }
}

// MARK: - Quick Stat Card

struct QuickStatCard: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).foregroundStyle(Color.fitGreen).font(.title3)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.textPrimary).lineLimit(1)
            Text(label).font(.system(size: 11)).foregroundStyle(Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
