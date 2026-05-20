import SwiftUI

struct ShoppingListView: View {
    var vm: PlanViewModel
    var partnerName: String = ""

    @AppStorage("weeklyBudget") private var weeklyBudget: Double = 200
    @State private var budgetInput = ""
    @State private var editingBudget = false
    @State private var checked: Set<String> = []
    @State private var excludedKeys: Set<String> = []
    @State private var partnerExcludedKeys: Set<String> = []
    @State private var showMealPicker = true
    @State private var showPartnerMealPicker = true
    @State private var copied = false

    private var allDayMeals: [(day: String, type: String)] {
        (vm.mealPlan?.days ?? []).flatMap { d in d.meals.map { (day: d.day, type: $0.type) } }
    }
    private var allDays: [String] {
        var seen = Set<String>()
        return allDayMeals.compactMap { seen.insert($0.day).inserted ? $0.day : nil }
    }
    private func mealsFor(day: String) -> [String] {
        allDayMeals.filter { $0.day == day }.map { $0.type }
    }

    private var partnerAllDayMeals: [(day: String, type: String)] {
        (vm.partnerPlan?.days ?? []).flatMap { d in d.meals.map { (day: d.day, type: $0.type) } }
    }
    private var partnerAllDays: [String] {
        var seen = Set<String>()
        return partnerAllDayMeals.compactMap { seen.insert($0.day).inserted ? $0.day : nil }
    }
    private func partnerMealsFor(day: String) -> [String] {
        partnerAllDayMeals.filter { $0.day == day }.map { $0.type }
    }

    private func mealKey(_ day: String, _ type: String) -> String { "\(day)_\(type)" }

    private var estimatedTotal: Double { vm.shoppingList?.estimatedTotal ?? 0 }
    private var budgetRemaining: Double { weeklyBudget - estimatedTotal }
    private var overBudget: Bool { budgetRemaining < 0 }

    private var checkedTotal: Double {
        guard let list = vm.shoppingList else { return 0 }
        return list.categories.flatMap { $0.items }
            .filter { checked.contains(itemKey($0)) }
            .reduce(0) { $0 + $1.estimatedPrice }
    }

    private var formattedListText: String {
        guard let list = vm.shoppingList else { return "" }
        var lines = ["🛒 Coles Shopping List — Est. $\(String(format: "%.2f", estimatedTotal))\n"]
        for cat in list.categories {
            lines.append(cat.category.uppercased())
            cat.items.forEach { lines.append("• \($0.name)  ~$\(String(format: "%.2f", $0.estimatedPrice))") }
            lines.append("")
        }
        return lines.joined(separator: "\n")
    }
    private var wiselistText: String {
        guard let list = vm.shoppingList else { return "" }
        return list.categories.flatMap { $0.items.map { $0.name } }.joined(separator: "\n")
    }

    var body: some View {
        NavigationStack {
            Group {
                if vm.isGeneratingList {
                    VStack(spacing: 16) {
                        ProgressView().tint(Color.fitGreen).scaleEffect(1.2)
                        Text("Building your Coles shopping list…").foregroundStyle(Color.textSecondary)
                        Text("This may take a few seconds").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.darkBg)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {

                            // Budget card
                            FitCard {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("Weekly Budget").font(.headline).foregroundStyle(Color.textPrimary)
                                        if editingBudget {
                                            HStack {
                                                Text("$").foregroundStyle(Color.textSecondary)
                                                TextField("200", text: $budgetInput)
                                                    .keyboardType(.decimalPad)
                                                    .foregroundStyle(Color.textPrimary)
                                                Button("Done") {
                                                    if let val = Double(budgetInput) { weeklyBudget = val }
                                                    editingBudget = false
                                                }
                                                .foregroundStyle(Color.fitGreen)
                                            }
                                        } else {
                                            HStack(spacing: 4) {
                                                Text("$\(String(format: "%.2f", weeklyBudget))")
                                                    .font(.system(size: 22, weight: .bold))
                                                    .foregroundStyle(Color.textPrimary)
                                                Button { budgetInput = String(format: "%.2f", weeklyBudget); editingBudget = true } label: {
                                                    Image(systemName: "pencil").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                                                }
                                            }
                                        }
                                    }
                                    Spacer()
                                    if estimatedTotal > 0 {
                                        VStack(alignment: .trailing, spacing: 4) {
                                            Text("Est. total").font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                                            Text("$\(String(format: "%.2f", estimatedTotal))")
                                                .font(.system(size: 22, weight: .bold))
                                                .foregroundStyle(overBudget ? Color.fitRed : Color.fitGreen)
                                        }
                                    }
                                }

                                if estimatedTotal > 0 {
                                    // Progress bar
                                    let progress = min(estimatedTotal / weeklyBudget, 1.0)
                                    GeometryReader { geo in
                                        ZStack(alignment: .leading) {
                                            RoundedRectangle(cornerRadius: 4).fill(Color.darkSurface).frame(height: 8)
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(overBudget ? Color.fitRed : Color.fitGreen)
                                                .frame(width: geo.size.width * progress, height: 8)
                                        }
                                    }
                                    .frame(height: 8)
                                    .padding(.top, 8)

                                    HStack {
                                        Text(overBudget ? "Over budget by $\(String(format: "%.2f", abs(budgetRemaining)))" : "$\(String(format: "%.2f", budgetRemaining)) remaining")
                                            .font(.system(size: 12))
                                            .foregroundStyle(overBudget ? Color.fitRed : Color.textSecondary)
                                        Spacer()
                                        if checked.count > 0 {
                                            Text("In cart: $\(String(format: "%.2f", checkedTotal))")
                                                .font(.system(size: 12)).foregroundStyle(Color.textSecondary)
                                        }
                                    }
                                    .padding(.top, 4)
                                }
                            }

                            // My meal exclusion picker
                            if !allDayMeals.isEmpty {
                                MealExclusionCard(
                                    title: partnerAllDayMeals.isEmpty ? "Select Meals to Include" : "My Meals to Include",
                                    days: allDays,
                                    mealsFor: mealsFor,
                                    mealKey: mealKey,
                                    excludedKeys: $excludedKeys,
                                    isExpanded: $showMealPicker
                                )
                            }

                            // Partner meal exclusion picker
                            if !partnerAllDayMeals.isEmpty {
                                MealExclusionCard(
                                    title: "\(partnerName.isEmpty ? "Partner" : partnerName)'s Meals to Include",
                                    days: partnerAllDays,
                                    mealsFor: partnerMealsFor,
                                    mealKey: mealKey,
                                    excludedKeys: $partnerExcludedKeys,
                                    isExpanded: $showPartnerMealPicker
                                )
                            }

                            ErrorBanner(message: vm.error) { vm.clearError() }

                            FitButton(
                                title: vm.shoppingList == nil ? "Generate Coles List" : "Regenerate List",
                                action: { checked.removeAll(); vm.generateShoppingList(partnerName: partnerName, excludedKeys: excludedKeys, partnerExcludedKeys: partnerExcludedKeys, weeklyBudget: weeklyBudget) }
                            )

                            // List
                            if let list = vm.shoppingList {
                                HStack(spacing: 12) {
                                    Text("\(checked.count)/\(list.categories.flatMap { $0.items }.count) in cart")
                                        .font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                                    Spacer()
                                    Button { copied = true; UIPasteboard.general.string = formattedListText
                                        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { copied = false }
                                    } label: {
                                        Label(copied ? "Copied!" : "Copy", systemImage: copied ? "checkmark" : "doc.on.doc")
                                            .font(.system(size: 13))
                                            .foregroundStyle(copied ? Color.fitGreen : Color.textSecondary)
                                    }
                                    ShareLink(item: formattedListText) {
                                        Label("Share", systemImage: "square.and.arrow.up").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                                    }
                                    ShareLink(item: wiselistText) {
                                        Label("Wiselist", systemImage: "list.bullet").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                                    }
                                    Button("Clear") { checked.removeAll() }.font(.system(size: 13)).foregroundStyle(Color.textSecondary)
                                }
                                .padding(.horizontal, 4)

                                ForEach(list.categories) { category in
                                    FitCard {
                                        HStack {
                                            Text(category.category).font(.headline).foregroundStyle(Color.fitGreen)
                                            Spacer()
                                            Text("$\(String(format: "%.2f", category.items.reduce(0) { $0 + $1.estimatedPrice }))")
                                                .font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.textSecondary)
                                        }
                                        VStack(spacing: 0) {
                                            ForEach(category.items) { item in
                                                let key = itemKey(item)
                                                let isDone = checked.contains(key)
                                                Button {
                                                    if isDone { checked.remove(key) } else { checked.insert(key) }
                                                } label: {
                                                    HStack(spacing: 12) {
                                                        Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                                            .foregroundStyle(isDone ? Color.fitGreen : Color.textSecondary)
                                                            .font(.system(size: 20))
                                                        Text(item.name)
                                                            .font(.system(size: 15))
                                                            .foregroundStyle(isDone ? Color.textSecondary : Color.textPrimary)
                                                            .strikethrough(isDone, color: Color.textSecondary)
                                                            .frame(maxWidth: .infinity, alignment: .leading)
                                                        Text("~$\(String(format: "%.2f", item.estimatedPrice))")
                                                            .font(.system(size: 12))
                                                            .foregroundStyle(isDone ? Color.textSecondary.opacity(0.5) : Color.textSecondary)
                                                    }
                                                    .padding(.vertical, 10)
                                                }
                                                if item.id != category.items.last?.id {
                                                    Divider().background(Color.darkSurface)
                                                }
                                            }
                                        }
                                        .padding(.top, 8)
                                    }
                                }
                            } else {
                                VStack(spacing: 10) {
                                    Image(systemName: "cart.fill").font(.system(size: 44)).foregroundStyle(Color.textSecondary)
                                    Text("Select your meals above and tap Generate").foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                                }
                                .frame(maxWidth: .infinity).padding(40)
                            }
                        }
                        .padding(.horizontal, 16).padding(.vertical, 16)
                    }
                    .background(Color.darkBg)
                }
            }
            .navigationTitle("Coles Shopping List")
            .navigationBarTitleDisplayMode(.large)
        }
        .preferredColorScheme(.dark)
    }

    private func itemKey(_ item: ShoppingItem) -> String { "\(item.name)" }
}

struct MealExclusionCard: View {
    let title: String
    let days: [String]
    let mealsFor: (String) -> [String]
    let mealKey: (String, String) -> String
    @Binding var excludedKeys: Set<String>
    @Binding var isExpanded: Bool

    var body: some View {
        FitCard {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack {
                    Text(title).font(.headline).foregroundStyle(Color.textPrimary)
                    Spacer()
                    if excludedKeys.count > 0 {
                        Text("\(excludedKeys.count) excluded").font(.system(size: 12)).foregroundStyle(Color.fitRed)
                    }
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down").foregroundStyle(Color.textSecondary)
                }
            }

            if isExpanded {
                VStack(spacing: 12) {
                    ForEach(days, id: \.self) { day in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(day).font(.system(size: 13, weight: .semibold)).foregroundStyle(Color.fitGreen)
                                Spacer()
                                Button {
                                    let keys = mealsFor(day).map { mealKey(day, $0) }
                                    let allExcluded = keys.allSatisfy { excludedKeys.contains($0) }
                                    if allExcluded { keys.forEach { excludedKeys.remove($0) } }
                                    else { keys.forEach { excludedKeys.insert($0) } }
                                } label: {
                                    let allExcluded = mealsFor(day).map { mealKey(day, $0) }.allSatisfy { excludedKeys.contains($0) }
                                    Text(allExcluded ? "Include all" : "Exclude all")
                                        .font(.system(size: 11)).foregroundStyle(Color.textSecondary)
                                }
                            }
                            HStack(spacing: 8) {
                                ForEach(mealsFor(day), id: \.self) { type in
                                    let key = mealKey(day, type)
                                    let excluded = excludedKeys.contains(key)
                                    Button {
                                        if excluded { excludedKeys.remove(key) } else { excludedKeys.insert(key) }
                                    } label: {
                                        HStack(spacing: 4) {
                                            Image(systemName: excluded ? "xmark.circle.fill" : "checkmark.circle.fill").font(.system(size: 12))
                                            Text(type).font(.system(size: 12))
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 5)
                                        .background(excluded ? Color.fitRed.opacity(0.15) : Color.fitGreen.opacity(0.15))
                                        .foregroundStyle(excluded ? Color.fitRed : Color.fitGreen)
                                        .clipShape(Capsule())
                                    }
                                }
                            }
                        }
                    }
                }
                .padding(.top, 10)
            }
        }
    }
}
