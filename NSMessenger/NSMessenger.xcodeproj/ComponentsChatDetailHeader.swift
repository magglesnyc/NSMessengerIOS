//
//  ChatDetailHeader.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct ChatDetailHeader: View {
    let chatName: String
    let onBackTap: () -> Void
    let onRefreshTap: () -> Void
    let onDebugTap: () -> Void
    
    var body: some View {
        HStack {
            // Back button
            Button(action: onBackTap) {
                Image(systemName: "chevron.left")
                    .font(.system(size: Sizes.iconLarge, weight: .semibold))
                    .foregroundColor(.primaryPurple)
            }
            
            // Chat name
            Text(chatName)
                .font(.h2)
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            
            Spacer()
            
            // Actions
            HStack(spacing: Spacing.md) {
                Button(action: onRefreshTap) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: Sizes.iconMedium))
                        .foregroundColor(.textSecondary)
                }
                
                Button(action: onDebugTap) {
                    Image(systemName: "info.circle")
                        .font(.system(size: Sizes.iconMedium))
                        .foregroundColor(.textSecondary)
                }
            }
        }
        .padding(.horizontal, Spacing.screenPadding)
        .padding(.vertical, Spacing.md)
        .background(Color.navigationBackground)
        .overlay(
            Rectangle()
                .frame(height: 1)
                .foregroundColor(.borderPrimary),
            alignment: .bottom
        )
    }
}

// MARK: - Preview

#Preview {
    ChatDetailHeader(
        chatName: "John Doe",
        onBackTap: {},
        onRefreshTap: {},
        onDebugTap: {}
    )
}