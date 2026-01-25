//
//  ComponentStyles.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.button)
            .foregroundColor(.textOnPrimary)
            .padding(.horizontal, Spacing.buttonPadding)
            .frame(height: Sizes.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .fill(isEnabled ? Color.primaryPurple : Color.disabledBackground)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    let isEnabled: Bool
    
    init(isEnabled: Bool = true) {
        self.isEnabled = isEnabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.button)
            .foregroundColor(isEnabled ? .primaryPurple : .disabledText)
            .padding(.horizontal, Spacing.buttonPadding)
            .frame(height: Sizes.buttonHeight)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.button)
                    .stroke(isEnabled ? Color.primaryPurple : Color.disabledBackground, lineWidth: 1)
                    .background(Color.clear)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct PillButtonStyle: ButtonStyle {
    let isSelected: Bool
    
    init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.caption)
            .foregroundColor(isSelected ? .textOnPrimary : .textSecondary)
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.pill)
                    .fill(isSelected ? Color.primaryPurple : Color.backgroundSecondary)
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Card Styles

struct CardStyle: ViewModifier {
    let hasAccent: Bool
    
    init(hasAccent: Bool = false) {
        self.hasAccent = hasAccent
    }
    
    func body(content: Content) -> some View {
        content
            .background(Color.cardBackground)
            .cornerRadius(Sizes.cardRadius)
            .overlay(
                RoundedRectangle(cornerRadius: Sizes.cardRadius)
                    .stroke(hasAccent ? Color.borderActive : Color.borderPrimary, lineWidth: hasAccent ? 2 : 1)
            )
            .shadow(
                color: Shadow.card.color,
                radius: Shadow.card.radius,
                x: Shadow.card.x,
                y: Shadow.card.y
            )
    }
}

// MARK: - Input Styles

struct InputFieldStyle: ViewModifier {
    let isFocused: Bool
    
    init(isFocused: Bool = false) {
        self.isFocused = isFocused
    }
    
    func body(content: Content) -> some View {
        content
            .font(.input)
            .padding(Spacing.inputPadding)
            .background(Color.inputBackground)
            .cornerRadius(CornerRadius.input)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.input)
                    .stroke(isFocused ? Color.borderActive : Color.borderSecondary, lineWidth: 1)
            )
    }
}

// MARK: - Message Styles

struct MessageBubbleStyle: ViewModifier {
    let isSent: Bool
    let showTail: Bool
    
    init(isSent: Bool, showTail: Bool = true) {
        self.isSent = isSent
        self.showTail = showTail
    }
    
    func body(content: Content) -> some View {
        content
            .padding(Spacing.messagePadding)
            .background(
                RoundedRectangle(cornerRadius: CornerRadius.message)
                    .fill(isSent ? Color.sentMessageBackground : Color.receivedMessageBackground)
            )
            .foregroundColor(isSent ? Color.sentMessageText : Color.receivedMessageText)
    }
}

// MARK: - List Item Styles

struct ListItemStyle: ViewModifier {
    let isSelected: Bool
    
    init(isSelected: Bool = false) {
        self.isSelected = isSelected
    }
    
    func body(content: Content) -> some View {
        content
            .padding(Spacing.cardPadding)
            .background(isSelected ? Color.selectedBackground : Color.clear)
            .cornerRadius(CornerRadius.medium)
    }
}

// MARK: - Status Indicator Styles

struct StatusIndicatorStyle: ViewModifier {
    let status: OnlineStatus
    
    func body(content: Content) -> some View {
        content
            .frame(width: Sizes.statusIndicator, height: Sizes.statusIndicator)
            .background(
                Circle()
                    .fill(status.color)
            )
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }
}

enum OnlineStatus {
    case online
    case away
    case busy
    case offline
    
    var color: Color {
        switch self {
        case .online: return .onlineGreen
        case .away: return .awayYellow
        case .busy: return .busyRed
        case .offline: return .offlineGray
        }
    }
}

// MARK: - Extension for Easy Access

extension View {
    func primaryButtonStyle(isEnabled: Bool = true) -> some View {
        self.buttonStyle(PrimaryButtonStyle(isEnabled: isEnabled))
    }
    
    func secondaryButtonStyle(isEnabled: Bool = true) -> some View {
        self.buttonStyle(SecondaryButtonStyle(isEnabled: isEnabled))
    }
    
    func pillButtonStyle(isSelected: Bool = false) -> some View {
        self.buttonStyle(PillButtonStyle(isSelected: isSelected))
    }
    
    func cardStyle(hasAccent: Bool = false) -> some View {
        self.modifier(CardStyle(hasAccent: hasAccent))
    }
    
    func inputFieldStyle(isFocused: Bool = false) -> some View {
        self.modifier(InputFieldStyle(isFocused: isFocused))
    }
    
    func messageBubbleStyle(isSent: Bool, showTail: Bool = true) -> some View {
        self.modifier(MessageBubbleStyle(isSent: isSent, showTail: showTail))
    }
    
    func listItemStyle(isSelected: Bool = false) -> some View {
        self.modifier(ListItemStyle(isSelected: isSelected))
    }
    
    func statusIndicator(_ status: OnlineStatus) -> some View {
        self.modifier(StatusIndicatorStyle(status: status))
    }
}