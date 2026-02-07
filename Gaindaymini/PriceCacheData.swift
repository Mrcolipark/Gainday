//
//  PriceCacheData.swift
//  Gaindaymini
//

import Foundation

struct PriceCacheData {
    let symbol: String
    let date: Date
    let open: Double
    let high: Double
    let low: Double
    let close: Double
    let currency: String
    var preMarketPrice: Double?
    var postMarketPrice: Double?
    var marketState: String?
}
