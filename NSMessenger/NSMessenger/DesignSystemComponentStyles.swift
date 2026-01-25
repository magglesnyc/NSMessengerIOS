//
//  ComponentStyles.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

// MARK: - Button Styles

struct PrimaryButtonStyle: ButtonStyle {
    let isDisabled: Bool
    
    init(isDisabled: Bool = false) {
        self.isDisabled = isDisabled
    }
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.button)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xxs + 1) // 6px
            .background(isDisabled ? Color.disabledGray : Color.primaryPurple)
            .cornerRadius(CornerRadius.standard)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
            .disabled(isDisabled)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.button)
            .foregroundColor(.white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, Spacing.xs)
            .background(Color.disabledGray)
            .cornerRadius(CornerRadius.standard)
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

struct PillButtonStyle: ButtonStyle {
    let isOutline: Bool

    init(isOutline: Bool = false) {
        self.isOutline = isOutline
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.lato(14, weight: .bold))
            .foregroundColor(isOutline ? Color.primaryPurple : .white)
            .padding(.horizontal, Spacing.lg)
            .padding(.vertical, 4)
            .background(isOutline ? .white : Color.primaryPurple)
            .cornerRadius(CornerRadius.pill)
            .floatingButtonShadow()
            .opacity(configuration.isPressed ? 0.8 : 1.0)
    }
}

// MARK: - Text Field Styles

struct AppTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.input)
            .foregroundColor(.textPrimary) // Explicitly set text color
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xxs)
            .frame(height: 30)
            .background(Color.backgroundPrimary)
            .cornerRadius(CornerRadius.standard)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.standard)
                    .stroke(Color.borderColor, lineWidth: BorderWidth.standard)
            )
    }
}

struct SearchBarStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .font(.lato(11.46, weight: .regular))
            .padding(.horizontal, Spacing.sm)
            .frame(height: 30)
            .background(Color.backgroundPrimary)
            .cornerRadius(CornerRadius.standard)
            .overlay(
                RoundedRectangle(cornerRadius: CornerRadius.standard)
                    .stroke(Color.borderColor, lineWidth: BorderWidth.thin)
            )
    }
}

// MARK: - Form Components

struct FormLabel: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.label)
            .foregroundColor(Color.primaryPurple)
    }
}
