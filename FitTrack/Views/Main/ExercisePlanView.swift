import SwiftUI

struct ExercisePlanView: View {
    var vm: PlanViewModel

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

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                HStack {
                    Image(systemName: "figure.strengthtraining.traditional").foregroundStyle(Color.fitGreen).font(.title2)
                    VStack(alignment: .leading) {
                        Text("Exercise Plan").font(.title2).bold().foregroundStyle(Color.textPrimary)
                        Text("Week of \(weekLabel)").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    }
                    Spacer()
                }

                FitButton(
                    title: vm.exercisePlan == nil ? "Generate Exercise Plan" : "Regenerate Exercise Plan",
                    action: { vm.generateExercisePlan() },
                    isLoading: vm.isGeneratingExercise
                )

                ErrorBanner(message: vm.error) { vm.clearError() }

                if vm.isGeneratingExercise {
                    FitCard {
                        VStack(spacing: 12) {
                            ProgressView().tint(Color.fitGreen)
                            Text("Generating your personalised exercise plan…").foregroundStyle(Color.textSecondary).font(.system(size: 13))
                            Text("This may take up to 30 seconds").foregroundStyle(Color.textSecondary).font(.system(size: 11))
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }

                if let plan = vm.exercisePlan, !vm.isGeneratingExercise {
                    ForEach(plan.days) { dayPlan in
                        DayExerciseCard(
                            dayPlan: dayPlan,
                            defaultExpanded: dayPlan.day.lowercased() == today.lowercased(),
                            swappingKey: vm.swappingKey,
                            onSwap: { idx, ex in vm.swapExercise(day: dayPlan.day, index: idx, exercise: ex, workoutType: dayPlan.workoutType) }
                        )
                    }
                }

                if vm.exercisePlan == nil && !vm.isGeneratingExercise {
                    VStack(spacing: 10) {
                        Image(systemName: "figure.strengthtraining.traditional").font(.system(size: 44)).foregroundStyle(Color.textSecondary)
                        Text("No exercise plan yet").foregroundStyle(Color.textSecondary)
                        Text("Tap Generate to create your plan").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity).padding(40)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
        }
        .background(Color.darkBg)
    }
}

struct DayExerciseCard: View {
    let dayPlan: DayExercisePlan
    let defaultExpanded: Bool
    let swappingKey: String?
    let onSwap: (Int, ExerciseItem) -> Void

    @State private var expanded: Bool

    init(dayPlan: DayExercisePlan, defaultExpanded: Bool, swappingKey: String?, onSwap: @escaping (Int, ExerciseItem) -> Void) {
        self.dayPlan = dayPlan; self.defaultExpanded = defaultExpanded
        self.swappingKey = swappingKey; self.onSwap = onSwap
        _expanded = State(initialValue: defaultExpanded)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(dayPlan.day).font(.headline).foregroundStyle(Color.textPrimary)
                    if dayPlan.isRest {
                        Text("Rest Day").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    } else {
                        Text(dayPlan.workoutType).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fitGreen)
                        if !dayPlan.duration.isEmpty {
                            Text(dayPlan.duration).font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                        }
                    }
                }
                Spacer()
                if dayPlan.isRest {
                    Image(systemName: "bed.double.fill").foregroundStyle(Color.textSecondary)
                } else {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                    } label: {
                        Image(systemName: expanded ? "chevron.up" : "chevron.down").foregroundStyle(Color.textSecondary)
                    }
                }
            }
            .padding(16)

            if !dayPlan.isRest && expanded {
                Divider().background(Color.darkSurface)
                VStack(alignment: .leading, spacing: 0) {
                    if !dayPlan.warmup.isEmpty {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk").foregroundStyle(Color.textSecondary).font(.system(size: 14))
                            VStack(alignment: .leading) {
                                Text("Warm-up").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.textSecondary)
                                Text(dayPlan.warmup).font(.system(size: 13)).foregroundStyle(Color.textPrimary)
                            }
                        }
                        .padding(16)
                        Divider().background(Color.darkSurface)
                    }

                    ForEach(Array(dayPlan.exercises.enumerated()), id: \.element.id) { idx, ex in
                        if idx > 0 { Divider().background(Color.darkSurface).padding(.horizontal, 16) }
                        ExerciseRowView(
                            index: idx, exercise: ex,
                            isSwapping: swappingKey == "\(dayPlan.day)_ex_\(idx)",
                            onSwap: { onSwap(idx, ex) }
                        )
                        .padding(16)
                    }

                    if !dayPlan.cooldown.isEmpty {
                        Divider().background(Color.darkSurface)
                        HStack(spacing: 6) {
                            Image(systemName: "figure.cooldown").foregroundStyle(Color.textSecondary).font(.system(size: 14))
                            VStack(alignment: .leading) {
                                Text("Cool-down").font(.system(size: 11, weight: .bold)).foregroundStyle(Color.textSecondary)
                                Text(dayPlan.cooldown).font(.system(size: 13)).foregroundStyle(Color.textPrimary)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

struct ExerciseRowView: View {
    let index: Int
    let exercise: ExerciseItem
    let isSwapping: Bool
    let onSwap: () -> Void
    @State private var showNotes = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("#\(index + 1)").font(.system(size: 10, weight: .bold)).tracking(1).foregroundStyle(Color.fitGreen)
                    Text(exercise.name).font(.headline).foregroundStyle(Color.textPrimary)
                    HStack(spacing: 16) {
                        StatPill(label: "Sets", value: "\(exercise.sets)")
                        StatPill(label: "Reps", value: exercise.reps)
                        StatPill(label: "Rest", value: exercise.rest)
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

            if !exercise.notes.isEmpty {
                Button {
                    withAnimation { showNotes.toggle() }
                } label: {
                    HStack(spacing: 4) {
                        Text(showNotes ? "Hide tip" : "Form tip").font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                        Image(systemName: showNotes ? "chevron.up" : "chevron.down").font(.system(size: 11)).foregroundStyle(Color.textSecondary)
                    }
                }
                if showNotes {
                    Text(exercise.notes).font(.system(size: 13)).foregroundStyle(Color.textPrimary)
                }
            }
        }
    }
}

struct StatPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 1) {
            Text(label).font(.system(size: 10)).foregroundStyle(Color.textSecondary)
            Text(value).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.textPrimary)
        }
    }
}
