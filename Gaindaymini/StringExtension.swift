//
//  StringExtension.swift
//  Gaindaymini
//
//  Widget 使用的简化版本，重定向到 widgetLocalized
//

import Foundation

extension String {
    var localized: String {
        return self.widgetLocalized
    }
}
