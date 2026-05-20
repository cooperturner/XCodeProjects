import SwiftUI
import Charts
import PhotosUI
import UIKit

// MARK: - Progress Tab Root

struct WeightProgressView: View {
    var vm: ProgressViewModel
    var onNavigateSettings: () -> Void
    @State private var segment = 0
    @State private var showLogDialog = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Picker("", selection: $segment) {
                    Text("Weight").tag(0)
                    Text("Photos").tag(1)
                }
                .pickerStyle(.segmented)
                .padding(.bottom, 4)

                if segment == 0 {
                    WeightContent(vm: vm, showLogDialog: $showLogDialog)
                } else {
                    PhotoProgressContent(vm: vm)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 16)
        }
        .background(Color.darkBg)
        .navigationTitle("Progress")
        .navigationBarTitleDisplayMode(.large)
        .sheet(isPresented: $showLogDialog) {
            LogWeightSheet(onSave: { date, weight in
                vm.addEntry(date: date, weightKg: weight)
                showLogDialog = false
            }, onDismiss: { showLogDialog = false })
        }
    }
}

// MARK: - Weight Content

private struct WeightContent: View {
    var vm: ProgressViewModel
    @Binding var showLogDialog: Bool

    var body: some View {
        if !vm.entries.isEmpty {
            StatsCard(entries: vm.entries)
            FitCard {
                Text("Weight Chart").font(.subheadline).foregroundStyle(Color.textSecondary)
                WeightChart(entries: Array(vm.entries.suffix(30)))
                    .frame(height: 200)
                    .padding(.top, 8)
            }
        }

        FitButton(title: "Log Weight") { showLogDialog = true }

        ErrorBanner(message: vm.error) { vm.clearError() }

        if vm.entries.isEmpty {
            VStack(spacing: 10) {
                Image(systemName: "chart.line.uptrend.xyaxis").font(.system(size: 44)).foregroundStyle(Color.textSecondary)
                Text("No weight logged yet").foregroundStyle(Color.textSecondary)
                Text("Tap Log Weight to start tracking").font(.system(size: 13)).foregroundStyle(Color.textSecondary)
            }
            .frame(maxWidth: .infinity).padding(40)
        }

        if !vm.entries.isEmpty {
            Text("History").font(.headline).foregroundStyle(Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
            ForEach(vm.entries.reversed(), id: \.id) { entry in
                WeightHistoryRow(entry: entry, onDelete: { vm.deleteEntry(entry) })
            }
        }
    }
}

// MARK: - Photo Content

private struct PhotoProgressContent: View {
    var vm: ProgressViewModel
    @State private var selectedItem: PhotosPickerItem?
    @State private var showLibraryPicker = false
    @State private var showCamera = false
    @State private var pendingImage: UIImage?
    @State private var showNoteSheet = false
    @State private var selectedPhoto: ProgressPhoto?
    @State private var compareMode = false
    @State private var compareSelection: [ProgressPhoto] = []
    @State private var showCompare = false

    private let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Menu {
                    if UIImagePickerController.isSourceTypeAvailable(.camera) {
                        Button { showCamera = true } label: {
                            Label("Take Photo", systemImage: "camera")
                        }
                    }
                    Button { showLibraryPicker = true } label: {
                        Label("Choose from Library", systemImage: "photo.on.rectangle")
                    }
                } label: {
                    Label("Add Photo", systemImage: "camera.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        .background(Color.fitGreenDark)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }

                Spacer()

                if !vm.photos.isEmpty {
                    Button(compareMode ? "Done" : "Compare") {
                        compareMode.toggle()
                        compareSelection = []
                    }
                    .font(.system(size: 14))
                    .foregroundStyle(Color.fitGreen)
                }
            }

            if compareMode && compareSelection.count == 2 {
                Button("View Side by Side") { showCompare = true }
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity).padding(.vertical, 10)
                    .background(Color.fitGreenDark)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if vm.photos.isEmpty {
                VStack(spacing: 10) {
                    Image(systemName: "camera.fill").font(.system(size: 44)).foregroundStyle(Color.textSecondary)
                    Text("No progress photos yet").foregroundStyle(Color.textSecondary)
                    Text("Add photos to track your visual journey").font(.system(size: 13)).foregroundStyle(Color.textSecondary).multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity).padding(40)
            } else {
                LazyVGrid(columns: columns, spacing: 10) {
                    ForEach(vm.photos, id: \.id) { photo in
                        PhotoCell(
                            photo: photo,
                            imageUrl: vm.imageUrl(for: photo),
                            compareMode: compareMode,
                            compareSelection: $compareSelection,
                            onTap: { selectedPhoto = photo }
                        )
                    }
                }
            }
        }
        .photosPicker(isPresented: $showLibraryPicker, selection: $selectedItem, matching: .images)
        .onChange(of: selectedItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self),
                   let image = UIImage(data: data) {
                    await MainActor.run { pendingImage = image; showNoteSheet = true }
                }
                await MainActor.run { selectedItem = nil }
            }
        }
        .sheet(isPresented: $showCamera) {
            CameraView { image in
                pendingImage = image
                showNoteSheet = true
            }
            .ignoresSafeArea()
        }
        .sheet(isPresented: $showNoteSheet) {
            AddPhotoNoteSheet(image: pendingImage, onSave: { note in
                if let image = pendingImage { vm.addPhoto(image: image, note: note) }
                pendingImage = nil
                showNoteSheet = false
            }, onDismiss: {
                pendingImage = nil
                showNoteSheet = false
            })
        }
        .sheet(item: $selectedPhoto) { photo in
            PhotoDetailView(photo: photo, imageUrl: vm.imageUrl(for: photo), vm: vm)
        }
        .sheet(isPresented: $showCompare) {
            if compareSelection.count == 2 {
                PhotoCompareView(
                    photo1: compareSelection[0], url1: vm.imageUrl(for: compareSelection[0]),
                    photo2: compareSelection[1], url2: vm.imageUrl(for: compareSelection[1])
                )
            }
        }
        .onAppear { vm.loadPhotos() }
    }
}

// MARK: - Camera

private struct CameraView: UIViewControllerRepresentable {
    let onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.allowsEditing = false
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView
        init(_ parent: CameraView) { self.parent = parent }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.onCapture(image)
            }
            picker.dismiss(animated: true)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            picker.dismiss(animated: true)
        }
    }
}

private struct PhotoCell: View {
    let photo: ProgressPhoto
    let imageUrl: URL
    let compareMode: Bool
    @Binding var compareSelection: [ProgressPhoto]
    let onTap: () -> Void

    @State private var uiImage: UIImage?
    private var isSelected: Bool { compareSelection.contains(where: { $0.id == photo.id }) }

    var body: some View {
        ZStack {
            Group {
                if let uiImage {
                    Image(uiImage: uiImage).resizable().scaledToFill()
                } else {
                    Color.darkSurface
                        .overlay(Image(systemName: "photo").foregroundStyle(Color.textSecondary))
                }
            }
            .frame(height: 170).clipped()

            VStack {
                Spacer()
                VStack(alignment: .leading, spacing: 2) {
                    Text(photo.date, format: .dateTime.day().month(.abbreviated).year())
                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white)
                    if !photo.note.isEmpty {
                        Text(photo.note).font(.system(size: 10)).foregroundStyle(.white.opacity(0.8)).lineLimit(1)
                    }
                }
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.black.opacity(0.45))
            }

            if compareMode && isSelected {
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.fitGreen).font(.system(size: 22)).padding(8)
                    }
                    Spacer()
                }
            }
        }
        .frame(height: 170)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(compareMode && isSelected ? Color.fitGreen : Color.clear, lineWidth: 3))
        .onTapGesture {
            if compareMode {
                if isSelected {
                    compareSelection.removeAll { $0.id == photo.id }
                } else if compareSelection.count < 2 {
                    compareSelection.append(photo)
                }
            } else {
                onTap()
            }
        }
        .onAppear { uiImage = UIImage(contentsOfFile: imageUrl.path) }
    }
}

struct AddPhotoNoteSheet: View {
    let image: UIImage?
    let onSave: (String) -> Void
    let onDismiss: () -> Void

    @State private var note = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if let image {
                    Image(uiImage: image)
                        .resizable().scaledToFit()
                        .frame(maxHeight: 300)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                FitTextField(label: "Add a note (optional, e.g. '12 weeks in')", text: $note)
                Spacer()
            }
            .padding(20)
            .background(Color.darkBg)
            .navigationTitle("Save Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { onSave(note) }.foregroundStyle(Color.fitGreen)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

private struct PhotoDetailView: View {
    let photo: ProgressPhoto
    let imageUrl: URL
    var vm: ProgressViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var uiImage: UIImage?
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    if let uiImage {
                        Image(uiImage: uiImage).resizable().scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    FitCard {
                        HStack {
                            Image(systemName: "calendar").foregroundStyle(Color.fitGreen)
                            Text(photo.date, format: .dateTime.day().month().year())
                                .foregroundStyle(Color.textPrimary)
                            Spacer()
                        }
                        if !photo.note.isEmpty {
                            HStack {
                                Image(systemName: "text.bubble").foregroundStyle(Color.fitGreen)
                                Text(photo.note).foregroundStyle(Color.textPrimary)
                                Spacer()
                            }
                            .padding(.top, 8)
                        }
                    }

                    Button(role: .destructive) { showDeleteConfirm = true } label: {
                        Label("Delete Photo", systemImage: "trash")
                            .frame(maxWidth: .infinity).padding()
                            .background(Color.fitRed.opacity(0.15))
                            .foregroundStyle(Color.fitRed)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(16)
            }
            .background(Color.darkBg)
            .navigationTitle("Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.fitGreen)
                }
            }
            .confirmationDialog("Delete this photo?", isPresented: $showDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) { vm.deletePhoto(photo); dismiss() }
                Button("Cancel", role: .cancel) {}
            }
        }
        .onAppear { uiImage = UIImage(contentsOfFile: imageUrl.path) }
    }
}

private struct PhotoCompareView: View {
    let photo1: ProgressPhoto
    let url1: URL
    let photo2: ProgressPhoto
    let url2: URL

    @Environment(\.dismiss) private var dismiss
    @State private var image1: UIImage?
    @State private var image2: UIImage?

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                HStack(spacing: 8) {
                    photoColumn(photo: photo1, image: image1, height: geo.size.height - 80)
                    photoColumn(photo: photo2, image: image2, height: geo.size.height - 80)
                }
                .padding(12)
            }
            .background(Color.darkBg)
            .navigationTitle("Compare")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }.foregroundStyle(Color.fitGreen)
                }
            }
        }
        .onAppear {
            image1 = UIImage(contentsOfFile: url1.path)
            image2 = UIImage(contentsOfFile: url2.path)
        }
    }

    @ViewBuilder
    private func photoColumn(photo: ProgressPhoto, image: UIImage?, height: CGFloat) -> some View {
        VStack(spacing: 6) {
            Group {
                if let image {
                    Image(uiImage: image).resizable().scaledToFill()
                        .frame(maxWidth: .infinity).frame(height: height).clipped()
                } else {
                    Color.darkSurface.frame(height: height)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Text(photo.date, format: .dateTime.day().month(.abbreviated).year())
                .font(.system(size: 12)).foregroundStyle(Color.textSecondary)

            if !photo.note.isEmpty {
                Text(photo.note).font(.system(size: 11)).foregroundStyle(Color.textSecondary)
                    .lineLimit(2).multilineTextAlignment(.center)
            }
        }
    }
}

// MARK: - Weight helpers (unchanged)

struct StatsCard: View {
    let entries: [WeightEntry]

    var body: some View {
        let first = entries.first!.weightKg
        let current = entries.last!.weightKg
        let change = current - first

        FitCard {
            HStack {
                StatItem(label: "Starting", value: String(format: "%.1f kg", first), color: .textSecondary)
                Spacer()
                Divider().frame(height: 48).background(Color.darkSurface)
                Spacer()
                StatItem(label: "Current", value: String(format: "%.1f kg", current), color: .fitGreen)
                Spacer()
                Divider().frame(height: 48).background(Color.darkSurface)
                Spacer()
                let changeColor: Color = change < 0 ? .fitGreen : change > 0 ? .fitRed : .textSecondary
                let prefix = change > 0 ? "+" : ""
                StatItem(label: "Change", value: "\(prefix)\(String(format: "%.1f", change)) kg", color: changeColor)
            }
        }
    }
}

struct StatItem: View {
    let label: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value).font(.system(size: 18, weight: .bold)).foregroundStyle(color)
            Text(label).font(.system(size: 12)).foregroundStyle(Color.textSecondary)
        }
    }
}

struct WeightChart: View {
    let entries: [WeightEntry]

    var body: some View {
        Chart {
            ForEach(entries, id: \.id) { entry in
                AreaMark(x: .value("Date", entry.date), y: .value("Weight", entry.weightKg))
                    .foregroundStyle(Color.fitGreen.opacity(0.2))
                    .interpolationMethod(.catmullRom)
                LineMark(x: .value("Date", entry.date), y: .value("Weight", entry.weightKg))
                    .foregroundStyle(Color.fitGreen)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                PointMark(x: .value("Date", entry.date), y: .value("Weight", entry.weightKg))
                    .foregroundStyle(Color.fitGreen).symbolSize(40)
            }
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisValueLabel {
                    if let str = value.as(String.self) {
                        Text(formatDateShort(str)).font(.system(size: 10)).foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks { value in
                AxisGridLine(stroke: StrokeStyle(dash: [2])).foregroundStyle(Color.white.opacity(0.06))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text("\(Int(v))kg").font(.system(size: 10)).foregroundStyle(Color.textSecondary)
                    }
                }
            }
        }
        .chartBackground { _ in Color.darkCard }
    }

    private func formatDateShort(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let out = DateFormatter(); out.dateFormat = "d MMM"
        return out.string(from: date)
    }
}

struct WeightHistoryRow: View {
    let entry: WeightEntry
    let onDelete: () -> Void

    var body: some View {
        HStack {
            Image(systemName: "scalemass.fill").foregroundStyle(Color.fitGreen).font(.system(size: 18))
            VStack(alignment: .leading, spacing: 2) {
                Text(String(format: "%.1f kg", entry.weightKg)).font(.system(size: 16, weight: .semibold)).foregroundStyle(Color.textPrimary)
                Text(formatDateFull(entry.date)).font(.system(size: 12)).foregroundStyle(Color.textSecondary)
            }
            Spacer()
            Button { onDelete() } label: {
                Image(systemName: "trash").foregroundStyle(Color.textSecondary).font(.system(size: 16))
            }
        }
        .padding(14)
        .background(Color.darkCard)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private func formatDateFull(_ dateStr: String) -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        guard let date = f.date(from: dateStr) else { return dateStr }
        let out = DateFormatter(); out.dateFormat = "d MMM yyyy"
        return out.string(from: date)
    }
}

struct LogWeightSheet: View {
    var onSave: (String, Float) -> Void
    var onDismiss: () -> Void

    @State private var weight = ""
    @State private var date: String = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"; return f.string(from: Date())
    }()

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                FitTextField(label: "Weight (kg)", text: $weight, keyboardType: .decimalPad)
                FitTextField(label: "Date (YYYY-MM-DD)", text: $date)
                Spacer()
            }
            .padding(20)
            .background(Color.darkBg)
            .navigationTitle("Log Weight")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { onDismiss() }.foregroundStyle(Color.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if let w = Float(weight) { onSave(date, w) }
                    }
                    .foregroundStyle(Color.fitGreen)
                    .disabled(weight.isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }
}
