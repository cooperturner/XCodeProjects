import SwiftData
import Foundation

class UserRepository {
    private let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    func findUser(username: String) throws -> User? {
        let lower = username.lowercased()
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.username == lower }
        )
        return try modelContext.fetch(descriptor).first
    }

    func findUser(id: String) throws -> User? {
        let descriptor = FetchDescriptor<User>(
            predicate: #Predicate { $0.id == id }
        )
        return try modelContext.fetch(descriptor).first
    }

    func createUser(username: String, password: String) throws -> User {
        let lower = username.lowercased()
        if (try findUser(username: lower)) != nil {
            throw RepositoryError.usernameTaken
        }
        let user = User(username: lower, passwordHash: User.hash(password))
        modelContext.insert(user)
        try modelContext.save()
        return user
    }

    func save() throws { try modelContext.save() }
}

enum RepositoryError: Error, LocalizedError {
    case usernameTaken
    case notFound

    var errorDescription: String? {
        switch self {
        case .usernameTaken: return "Username already taken"
        case .notFound: return "User not found"
        }
    }
}
