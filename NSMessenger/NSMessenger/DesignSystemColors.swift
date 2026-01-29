//
//  Colors.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

extension Color {
    // MARK: - Brand Colors
    static let primaryPurple = Color(hex: "3F1879")      // Primary brand, buttons, active states
    static let secondaryPurple = Color(hex: "6E3DB8")   // Accents, sent message bubbles
    static let lightPurple = Color(hex: "E5E4EC")       // Sidebar background, light components
    static let darkPurple = Color(hex: "352648")        // Dark purple variant
    static let purpleVariant1 = Color(hex: "564685")    // Alternative purple
    static let purpleVariant2 = Color(hex: "57466C")    // Timeline months background

    // MARK: - Backgrounds
    static let backgroundPrimary = Color(hex: "F3F4F7") // Main background, input backgrounds
    static let backgroundWhite = Color.white            // Cards, modals, header
    static let backgroundGray = Color(hex: "E5E4EC")    // Secondary background
    static let backgroundSecondary = Color(hex: "EFF2F5") // Secondary background, input fields
    
    // MARK: - UI Aliases
    static let accent = primaryPurple                   // Accent color alias

    // MARK: - Text Colors
    static let textPrimary = Color(hex: "212126")       // Primary text
    static let textSecondary = Color(hex: "504F62")     // Secondary text
    static let textTertiary = Color(hex: "88888F")      // Placeholder, disabled text
    static let textMuted = Color(hex: "7B7A8C")         // Muted text, inactive tabs

    // MARK: - UI Elements
    static let borderColor = Color(hex: "D6D5D9")       // Input borders, dividers
    static let disabledGray = Color(hex: "949494")      // Disabled states, timeline lines

    // MARK: - Semantic Colors
    static let accentCyan = Color(hex: "0D88AE")        // Links, secondary actions
    static let successGreen = Color(hex: "689F38")      // Online status, checkbox checked
    static let errorRed = Color(hex: "D75E5E")          // Error states
    static let warningOrange = Color(hex: "F5A623")     // Warning states

    // MARK: - Message Bubbles
    static let sentMessageBubble = Color(hex: "6E3DB8") // Sent messages
    static let receivedMessageBubble = Color(hex: "D6D6DB") // Received messages (darker grey)
}

// MARK: - Hex Color Extension
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (1, 1, 1, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
