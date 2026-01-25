//
//  Spacing.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

enum Spacing {
    static let xxs: CGFloat = 5
    static let xs: CGFloat = 8
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 15
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 30
}

enum CornerRadius {
    static let small: CGFloat = 3      // Tooltips, small elements
    static let medium: CGFloat = 5     // Cards, containers
    static let standard: CGFloat = 6   // Buttons, inputs
    static let large: CGFloat = 10     // Modals, large cards
    static let pill: CGFloat = 16      // Pill-shaped buttons
    static let circular: CGFloat = 50  // Avatars (use .clipShape(Circle()))
}

enum BorderWidth {
    static let thin: CGFloat = 0.6
    static let standard: CGFloat = 1
    static let thick: CGFloat = 2      // Active tabs
    static let accent: CGFloat = 9     // Left border highlight on cards
}

// MARK: - View Extensions for Shadows
extension View {
    func cardShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
    }

    func headerShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.15), radius: 10, x: 0, y: 4)
    }

    func buttonShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.25), radius: 6, x: 0, y: 2)
    }
    
    func floatingButtonShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.20), radius: 10, x: 0, y: 2)
    }
    
    func dropdownShadow() -> some View {
        self.shadow(color: Color.black.opacity(0.08), radius: 4, x: 0, y: 4)
    }
}