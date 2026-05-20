import SwiftData
import Foundation

@Model
class ProgressPhoto {
    var id: String
    var userId: String
    var date: Date
    var note: String
    var imagePath: String  // filename stored in Documents/ProgressPhotos/

    init(userId: String, imagePath: String, note: String = "") {
        self.id = UUID().uuidString
        self.userId = userId
        self.date = Date()
        self.note = note
        self.imagePath = imagePath
    }
}
