import SwiftUI

// MARK: - FitButton
struct FitButton: View {
    let title: String
    let action: () -> Void
    var isLoading = false
    var enabled = true

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.fitGreenDark)
                    .frame(height: 52)
                if isLoading {
                    ProgressView().tint(.white)
                } else {
                    Text(title).foregroundStyle(.white).fontWeight(.bold).font(.system(size: 16))
                }
            }
        }
        .disabled(!enabled || isLoading)
    }
}

// MARK: - FitTextField
struct FitTextArea: View {
    let label: String
    @Binding var text: String
    var minHeight: CGFloat = 100

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.darkSurface)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.textSecondary.opacity(0.5), lineWidth: 1))
            if text.isEmpty {
                Text(label)
                    .foregroundStyle(Color.textSecondary.opacity(0.6))
                    .font(.system(size: 15))
                    .padding(14)
            }
            TextEditor(text: $text)
                .scrollContentBackground(.hidden)
                .foregroundStyle(Color.textPrimary)
                .font(.system(size: 15))
                .padding(10)
                .frame(minHeight: minHeight)
        }
    }
}

struct FitTextField: View {
    let label: String
    @Binding var text: String
    var isSecure = false
    var keyboardType: UIKeyboardType = .default

    var body: some View {
        Group {
            if isSecure {
                SecureField(label, text: $text)
            } else {
                TextField(label, text: $text)
                    .keyboardType(keyboardType)
            }
        }
        .padding(14)
        .background(Color.darkSurface)
        .foregroundStyle(Color.textPrimary)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.textSecondary.opacity(0.5), lineWidth: 1))
        .clipShape(RoundedCornerShape(radius: 12))
        .tint(Color.fitGreen)
    }
}

struct RoundedCornerShape: Shape {
    let radius: CGFloat
    func path(in rect: CGRect) -> Path {
        Path(UIBezierPath(roundedRect: rect, cornerRadius: radius).cgPath)
    }
}

// MARK: - FitCard
struct FitCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }
}

// MARK: - ErrorBanner
struct ErrorBanner: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        if !message.isEmpty {
            HStack {
                Text(message).foregroundStyle(Color.fitRed).font(.system(size: 14))
                Spacer()
                Button("Dismiss") { onDismiss() }.foregroundStyle(Color.fitRed)
            }
            .padding(12)
            .background(Color.fitRed.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
    }
}

// MARK: - MacroRow
struct MacroRow: View {
    let label: String
    let consumed: Int
    let target: Int
    let color: Color

    private var progress: Double {
        target > 0 ? min(Double(consumed) / Double(target), 1.0) : 0
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack {
                Text(label).foregroundStyle(color).fontWeight(.semibold).font(.system(size: 13))
                Spacer()
                Text("\(consumed)g / \(target)g").foregroundStyle(Color.textSecondary).font(.system(size: 12))
            }
            ProgressView(value: progress)
                .tint(color)
                .background(Color.darkSurface)
                .clipShape(Capsule())
                .frame(height: 6)
        }
    }
}

// MARK: - CalorieProgressBar
struct CalorieProgressBar: View {
    let consumed: Int
    let target: Int

    private var progress: Double { target > 0 ? min(Double(consumed) / Double(target), 1.0) : 0 }
    private var barColor: Color {
        if progress >= 1 { return .fitRed }
        if progress >= 0.85 { return .fitOrange }
        return .fitGreen
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .bottom) {
                Text("\(consumed) kcal").foregroundStyle(Color.textPrimary).font(.system(size: 22, weight: .bold))
                Spacer()
                Text("/ \(target) kcal").foregroundStyle(Color.textSecondary).font(.system(size: 14))
            }
            ProgressView(value: progress)
                .tint(barColor)
                .background(Color.darkSurface)
                .clipShape(Capsule())
                .frame(height: 10)
            Text("\(max(0, target - consumed)) kcal remaining")
                .foregroundStyle(Color.textSecondary).font(.system(size: 12))
        }
    }
}

// MARK: - SportCard
private let commonSports = ["Rugby League", "Boxing", "MMA", "Jiu-Jitsu", "Wrestling", "Football"]

struct SportCard: View {
    @Binding var sport: String

    var body: some View {
        FitCard {
            Text("Sport / Activity").font(.headline).foregroundStyle(Color.textPrimary)
            Text("Exercise plans will be tailored to your sport. Leave blank for general fitness.")
                .font(.system(size: 13)).foregroundStyle(Color.textSecondary).padding(.top, 2)
            FitTextField(label: "e.g. Rugby League, Boxing, Cycling…", text: $sport)
                .padding(.top, 8)
            Text("Quick select:").font(.system(size: 12)).foregroundStyle(Color.textSecondary).padding(.top, 8)
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                ForEach(commonSports, id: \.self) { s in
                    let selected = sport.lowercased() == s.lowercased()
                    Button(s) { sport = selected ? "" : s }
                        .font(.system(size: 12))
                        .padding(.horizontal, 10).padding(.vertical, 6)
                        .background(selected ? Color.fitGreenDark : Color.darkSurface)
                        .foregroundStyle(selected ? Color.white : Color.textSecondary)
                        .clipShape(Capsule())
                }
            }
            .padding(.top, 4)
        }
    }
}
