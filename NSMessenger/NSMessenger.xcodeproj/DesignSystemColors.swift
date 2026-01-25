//
//  Colors.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

extension Color {
    
    // MARK: - Brand Colors
    
    static let primaryPurple = Color(red: 63/255, green: 24/255, blue: 121/255)     // #3F1879
    static let secondaryPurple = Color(red: 110/255, green: 61/255, blue: 184/255)  // #6E3DB8
    
    // MARK: - Accent Color
    
    static let accent = primaryPurple  // Primary accent color for the app
    
    // MARK: - Background Colors
    
    static let backgroundPrimary = Color.white                                      // #FFFFFF
    static let backgroundWhite = Color.white                                        // #FFFFFF
    static let backgroundSecondary = Color(red: 248/255, green: 249/255, blue: 250/255) // #F8F9FA
    static let backgroundTertiary = Color(red: 241/255, green: 243/255, blue: 244/255)  // #F1F3F4
    
    // MARK: - Card and Surface Colors
    
    static let cardBackground = Color.white                                         // #FFFFFF
    static let inputBackground = Color(red: 245/255, green: 247/255, blue: 249/255) // #F5F7F9
    static let selectedBackground = Color(red: 240/255, green: 235/255, blue: 255/255) // Light purple tint
    
    // MARK: - Text Colors
    
    static let textPrimary = Color(red: 33/255, green: 37/255, blue: 41/255)       // #212529
    static let textSecondary = Color(red: 108/255, green: 117/255, blue: 125/255)  // #6C757D
    static let textTertiary = Color(red: 173/255, green: 181/255, blue: 189/255)   // #ADB5BD
    static let textOnPrimary = Color.white                                         // White text on purple
    
    // MARK: - Border Colors
    
    static let borderPrimary = Color(red: 222/255, green: 226/255, blue: 230/255)  // #DEE2E6
    static let borderSecondary = Color(red: 206/255, green: 212/255, blue: 218/255) // #CED4DA
    static let borderActive = Color.primaryPurple                                  // Purple for active states
    
    // MARK: - Status Colors
    
    static let successGreen = Color(red: 25/255, green: 135/255, blue: 84/255)     // #198754
    static let errorRed = Color(red: 220/255, green: 53/255, blue: 69/255)        // #DC3545
    static let warningOrange = Color(red: 255/255, green: 193/255, blue: 7/255)   // #FFC107
    static let infoBlue = Color(red: 13/255, green: 202/255, blue: 240/255)       // #0DCAF0
    
    // MARK: - Message Colors
    
    static let sentMessageBackground = Color.primaryPurple
    static let receivedMessageBackground = Color(red: 248/255, green: 249/255, blue: 250/255)
    static let sentMessageText = Color.white
    static let receivedMessageText = Color.textPrimary
    
    // MARK: - State Colors
    
    static let disabledBackground = Color(red: 233/255, green: 236/255, blue: 239/255) // #E9ECEF
    static let disabledText = Color(red: 173/255, green: 181/255, blue: 189/255)       // #ADB5BD
    
    // MARK: - Shadow Colors
    
    static let shadowLight = Color.black.opacity(0.1)
    static let shadowMedium = Color.black.opacity(0.15)
    static let shadowDark = Color.black.opacity(0.25)
    
    // MARK: - Online Status Colors
    
    static let onlineGreen = Color(red: 40/255, green: 167/255, blue: 69/255)      // #28A745
    static let awayYellow = Color(red: 255/255, green: 193/255, blue: 7/255)      // #FFC107
    static let busyRed = Color(red: 220/255, green: 53/255, blue: 69/255)         // #DC3545
    static let offlineGray = Color(red: 108/255, green: 117/255, blue: 125/255)    // #6C757D
    
    // MARK: - Accent Colors for Different Message Types
    
    static let systemMessageBackground = Color(red: 255/255, green: 248/255, blue: 220/255) // #FFF8DC
    static let systemMessageText = Color(red: 133/255, green: 77/255, blue: 14/255)         // #854D0E
    
    // MARK: - Tab and Navigation Colors
    
    static let tabSelected = Color.primaryPurple
    static let tabUnselected = Color.textSecondary
    static let navigationBackground = Color.white
    
    // MARK: - Search and Filter Colors
    
    static let searchBackground = Color.inputBackground
    static let searchBorder = Color.borderPrimary
    static let searchText = Color.textPrimary
    static let searchPlaceholder = Color.textSecondary
}

// MARK: - Color Scheme Support

extension Color {
    
    // Colors that adapt to light/dark mode
    static let adaptiveBackground = Color(
        light: Color.white,
        dark: Color(red: 28/255, green: 28/255, blue: 30/255)
    )
    
    static let adaptiveSecondaryBackground = Color(
        light: Color.backgroundSecondary,
        dark: Color(red: 44/255, green: 44/255, blue: 46/255)
    )
    
    static let adaptiveText = Color(
        light: Color.textPrimary,
        dark: Color.white
    )
}

extension Color {
    init(light: Color, dark: Color) {
        self = Color(UIColor { traitCollection in
            switch traitCollection.userInterfaceStyle {
            case .dark:
                return UIColor(dark)
            default:
                return UIColor(light)
            }
        })
    }
}

// MARK: - Gradient Definitions

extension LinearGradient {
    static let primaryPurpleGradient = LinearGradient(
        colors: [Color.primaryPurple, Color.secondaryPurple],
        startPoint: .leading,
        endPoint: .trailing
    )
    
    static let messageGradient = LinearGradient(
        colors: [Color.primaryPurple.opacity(0.8), Color.primaryPurple],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}