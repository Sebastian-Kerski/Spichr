//
//  ItemCategory.swift
//  Spichr
//

import Foundation
import SwiftUI

enum ItemCategory: String, CaseIterable, Codable, Identifiable {
    case dairy      = "dairy"
    case meat       = "meat"
    case vegetables = "vegetables"
    case fruits     = "fruits"
    case beverages  = "beverages"
    case canned     = "canned"
    case eggs       = "eggs"
    case grains     = "grains"
    case bakery     = "bakery"
    case sweets     = "sweets"
    case condiments = "condiments"
    case frozen     = "frozen"
    case medicine   = "medicine"
    case other      = "other"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .dairy:      return "🥛"
        case .meat:       return "🥩"
        case .vegetables: return "🥦"
        case .fruits:     return "🍎"
        case .beverages:  return "🧃"
        case .canned:     return "🥫"
        case .eggs:       return "🥚"
        case .grains:     return "🌾"
        case .bakery:     return "🍞"
        case .sweets:     return "🍫"
        case .condiments: return "🧂"
        case .frozen:     return "🧊"
        case .medicine:   return "💊"
        case .other:      return "📦"
        }
    }

    var localizedName: String {
        NSLocalizedString("category_\(rawValue)", comment: "")
    }

    var displayName: String { "\(emoji) \(localizedName)" }

    var color: Color {
        switch self {
        case .dairy:      return .blue
        case .meat:       return .red
        case .vegetables: return .green
        case .fruits:     return .orange
        case .beverages:  return .cyan
        case .canned:     return .brown
        case .eggs:       return .yellow
        case .grains:     return Color(red: 0.8, green: 0.6, blue: 0.2)
        case .bakery:     return Color(red: 0.9, green: 0.7, blue: 0.4)
        case .sweets:     return .pink
        case .condiments: return Color(red: 0.5, green: 0.4, blue: 0.3)
        case .frozen:     return .teal
        case .medicine:   return .purple
        case .other:      return .gray
        }
    }
}

extension FoodItem {
    var itemCategory: ItemCategory? {
        get {
            guard let cat = category else { return nil }
            return ItemCategory(rawValue: cat)
        }
        set { category = newValue?.rawValue }
    }
}
