import SwiftData
import Foundation
import UIKit

@Observable
class ProgressViewModel {
    var entries: [WeightEntry] = []
    var photos: [ProgressPhoto] = []
    var error = ""

    private let repo: WeightRepository
    private let modelContext: ModelContext
    private let session = SessionManager.shared

    init(modelContext: ModelContext) {
        self.repo = WeightRepository(modelContext: modelContext)
        self.modelContext = modelContext
        loadEntries()
        loadPhotos()
    }

    // MARK: - Weight

    func loadEntries() {
        guard let userId = session.userId else { return }
        entries = (try? repo.entries(userId: userId)) ?? []
    }

    func addEntry(date: String, weightKg: Float) {
        guard weightKg > 0 else { error = "Enter a valid weight"; return }
        guard let userId = session.userId else { return }
        try? repo.add(userId: userId, date: date, weightKg: weightKg)
        loadEntries()
    }

    func deleteEntry(_ entry: WeightEntry) {
        try? repo.delete(entry)
        loadEntries()
    }

    func clearError() { error = "" }

    // MARK: - Photos

    func loadPhotos() {
        guard let userId = session.userId else { return }
        let descriptor = FetchDescriptor<ProgressPhoto>(
            predicate: #Predicate { $0.userId == userId },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        photos = (try? modelContext.fetch(descriptor)) ?? []
    }

    func addPhoto(image: UIImage, note: String) {
        guard let userId = session.userId,
              let filename = saveImageToDisk(image, userId: userId) else { return }
        let photo = ProgressPhoto(userId: userId, imagePath: filename, note: note)
        modelContext.insert(photo)
        try? modelContext.save()
        loadPhotos()
    }

    func deletePhoto(_ photo: ProgressPhoto) {
        deleteImageFromDisk(photo.imagePath)
        modelContext.delete(photo)
        try? modelContext.save()
        loadPhotos()
    }

    func imageUrl(for photo: ProgressPhoto) -> URL {
        photosFolder.appendingPathComponent(photo.imagePath)
    }

    private var photosFolder: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("ProgressPhotos")
    }

    private func saveImageToDisk(_ image: UIImage, userId: String) -> String? {
        try? FileManager.default.createDirectory(at: photosFolder, withIntermediateDirectories: true)
        let filename = "\(userId)_\(UUID().uuidString).jpg"
        let url = photosFolder.appendingPathComponent(filename)
        guard let data = image.jpegData(compressionQuality: 0.8) else { return nil }
        try? data.write(to: url)
        return filename
    }

    private func deleteImageFromDisk(_ filename: String) {
        try? FileManager.default.removeItem(at: photosFolder.appendingPathComponent(filename))
    }
}
