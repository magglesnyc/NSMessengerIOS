//
//  LoadingView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct LoadingView: View {
    let message: String
    
    init(message: String = "Loading...") {
        self.message = message
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            ProgressView()
                .scaleEffect(1.2)
                .tint(.primaryPurple)
            
            Text(message)
                .font(.bodyText)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

struct ErrorView: View {
    let message: String
    let onRetry: (() -> Void)?
    
    init(message: String, onRetry: (() -> Void)? = nil) {
        self.message = message
        self.onRetry = onRetry
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 50))
                .foregroundColor(.errorRed)
            
            Text("Error")
                .font(.h6)
                .foregroundColor(.textPrimary)
            
            Text(message)
                .font(.bodyText)
                .foregroundColor(.textSecondary)
                .multilineTextAlignment(.center)
            
            if let onRetry = onRetry {
                Button("Retry", action: onRetry)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionText: String?
    let action: (() -> Void)?
    
    init(
        icon: String,
        title: String,
        subtitle: String,
        actionText: String? = nil,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.actionText = actionText
        self.action = action
    }
    
    var body: some View {
        VStack(spacing: Spacing.lg) {
            Image(systemName: icon)
                .font(.system(size: 50))
                .foregroundColor(.textTertiary)
            
            Text(title)
                .font(.h6)
                .foregroundColor(.textSecondary)
            
            Text(subtitle)
                .font(.bodyText)
                .foregroundColor(.textTertiary)
                .multilineTextAlignment(.center)
            
            if let actionText = actionText, let action = action {
                Button(actionText, action: action)
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(Spacing.xxl)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.backgroundPrimary)
    }
}

#Preview {
    VStack(spacing: 20) {
        LoadingView()
            .frame(height: 200)
        
        ErrorView(message: "Failed to connect to server") {
            print("Retry tapped")
        }
        .frame(height: 200)
        
        EmptyStateView(
            icon: "message",
            title: "No Messages",
            subtitle: "Start a conversation to see messages here",
            actionText: "New Message"
        ) {
            print("New message tapped")
        }
        .frame(height: 200)
    }
}