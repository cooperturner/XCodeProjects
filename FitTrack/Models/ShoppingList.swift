import Foundation

struct ShoppingItem: Codable, Identifiable {
    var id: String { name }
    let name: String
    let estimatedPrice: Double
}

struct ShoppingCategory: Codable, Identifiable {
    var id: String { category }
    let category: String
    let items: [ShoppingItem]
}

struct ShoppingList: Codable {
    let categories: [ShoppingCategory]

    var estimatedTotal: Double {
        categories.flatMap { $0.items }.reduce(0) { $0 + $1.estimatedPrice }
    }
}
