//
//  Spacing.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

// MARK: - Spacing Constants

struct Spacing {
    // Base spacing values
    static let xxs: CGFloat = 5
    static let xs: CGFloat = 8
    static let sm: CGFloat = 10
    static let md: CGFloat = 15
    static let lg: CGFloat = 20
    static let xl: CGFloat = 25
    static let xxl: CGFloat = 30
    static let xxxl: CGFloat = 40
    
    // Component-specific spacing
    static let cardPadding: CGFloat = 24
    static let buttonPadding: CGFloat = 15
    static let inputPadding: CGFloat = 12
    static let messagePadding: CGFloat = 12
    static let sectionSpacing: CGFloat = 30
    
    // Layout spacing
    static let screenPadding: CGFloat = 20
    static let listItemSpacing: CGFloat = 8
    static let formSpacing: CGFloat = 20
    static let buttonSpacing: CGFloat = 15
    
    // Message-specific spacing
    static let messageGroupSpacing: CGFloat = 20
    static let messageBubbleSpacing: CGFloat = 8
    static let messageContentSpacing: CGFloat = 4
    static let messageHeaderSpacing: CGFloat = 2
    
    // Avatar and profile spacing
    static let avatarSpacing: CGFloat = 8
    static let profileSpacing: CGFloat = 15
    
    // Tab and navigation spacing
    static let tabPadding: CGFloat = 12
    static let navigationPadding: CGFloat = 16
    
    // Chat-specific spacing
    static let chatInputPadding: CGFloat = 10
    static let chatMessageMaxWidth: CGFloat = 280
    static let chatSideMargin: CGFloat = 50
}

// MARK: - Size Constants

struct Sizes {
    // Avatar sizes
    static let avatarSmall: CGFloat = 32
    static let avatarMedium: CGFloat = 40
    static let avatarLarge: CGFloat = 60
    static let avatarXLarge: CGFloat = 80
    
    // Button sizes
    static let buttonHeight: CGFloat = 44
    static let buttonHeightSmall: CGFloat = 36
    static let buttonHeightLarge: CGFloat = 52
    
    // Input sizes
    static let inputHeight: CGFloat = 44
    static let textInputHeight: CGFloat = 36
    static let searchBarHeight: CGFloat = 36
    
    // Icon sizes
    static let iconSmall: CGFloat = 16
    static let iconMedium: CGFloat = 20
    static let iconLarge: CGFloat = 24
    static let iconXLarge: CGFloat = 32
    
    // Card and container sizes
    static let cardMinHeight: CGFloat = 60
    static let cardRadius: CGFloat = 5
    static let inputRadius: CGFloat = 8
    static let buttonRadius: CGFloat = 8
    static let messageRadius: CGFloat = 12
    static let avatarRadius: CGFloat = 20 // Half of medium avatar size
    
    // Status indicator sizes
    static let statusIndicator: CGFloat = 12
    static let typingIndicator: CGFloat = 8
    
    // Layout constraints
    static let maxContentWidth: CGFloat = 600
    static let sidebarWidth: CGFloat = 300
    static let chatListWidth: CGFloat = 320
    
    // Minimum touch targets
    static let minTouchTarget: CGFloat = 44
    
    // Tab bar
    static let tabBarHeight: CGFloat = 50
    
    // Navigation
    static let navigationBarHeight: CGFloat = 44
    static let toolbarHeight: CGFloat = 44
}

// MARK: - Radius Constants

struct CornerRadius {
    static let none: CGFloat = 0
    static let small: CGFloat = 4
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let extraLarge: CGFloat = 16
    static let round: CGFloat = 50 // For circular elements
    
    // Component-specific
    static let card: CGFloat = 5
    static let input: CGFloat = 8
    static let button: CGFloat = 8
    static let message: CGFloat = 12
    static let avatar: CGFloat = 20
    static let pill: CGFloat = 20
}

// MARK: - Shadow Constants

struct Shadow {
    static let light = (
        color: Color.black.opacity(0.1),
        radius: CGFloat(2),
        x: CGFloat(0),
        y: CGFloat(1)
    )
    
    static let medium = (
        color: Color.black.opacity(0.15),
        radius: CGFloat(4),
        x: CGFloat(0),
        y: CGFloat(2)
    )
    
    static let strong = (
        color: Color.black.opacity(0.25),
        radius: CGFloat(8),
        x: CGFloat(0),
        y: CGFloat(4)
    )
    
    static let card = medium
    static let button = light
    static let modal = strong
}

// MARK: - Animation Constants

struct AnimationDuration {
    static let fast: Double = 0.2
    static let normal: Double = 0.3
    static let slow: Double = 0.5
    static let verySlow: Double = 0.8
    
    // Component-specific
    static let buttonPress: Double = 0.1
    static let transition: Double = 0.3
    static let modal: Double = 0.4
    static let typing: Double = 0.5
}

// MARK: - Z-Index Constants

struct ZIndex {
    static let background: Double = 0
    static let content: Double = 1
    static let overlay: Double = 10
    static let modal: Double = 100
    static let tooltip: Double = 200
    static let dropdown: Double = 300
    static let alert: Double = 400
    static let loading: Double = 500
}

// MARK: - Opacity Constants

struct Opacity {
    static let disabled: Double = 0.5
    static let pressed: Double = 0.8
    static let overlay: Double = 0.6
    static let placeholder: Double = 0.7
    static let shadow: Double = 0.15
    static let divider: Double = 0.2
}