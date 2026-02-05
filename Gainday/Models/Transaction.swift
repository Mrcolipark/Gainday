import Foundation
import SwiftData

@Model
class Transaction {
    var id: UUID
    var type: String
    var date: Date
    var quantity: Double
    var price: Double
    var fee: Double
    var currency: String
    var note: String
    var holding: Holding?

    init(
        id: UUID = UUID(),
        type: String = TransactionType.buy.rawValue,
        date: Date = Date(),
        quantity: Double = 0,
        price: Double = 0,
        fee: Double = 0,
        currency: String = "JPY",
        note: String = "",
        holding: Holding? = nil
    ) {
        self.id = id
        self.type = type
        self.date = date
        self.quantity = quantity
        self.price = price
        self.fee = fee
        self.currency = currency
        self.note = note
        self.holding = holding
    }

    var transactionType: TransactionType {
        TransactionType(rawValue: type) ?? .buy
    }

    var totalAmount: Double {
        quantity * price + fee
    }
}
