//
//  AvatarView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct AvatarView: View {
    let user: SignalRUserDto?
    let size: AvatarSize
    let showStatus: Bool
    
    init(user: SignalRUserDto?, size: AvatarSize = .medium, showStatus: Bool = true) {
        self.user = user
        self.size = size
        self.showStatus = showStatus
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            // Main avatar
            Group {
                if let user = user, let profileImageUrl = user.profileImageUrl, !profileImageUrl.isEmpty {
                    // TODO: Replace with AsyncImage or Kingfisher for production
                    AsyncImage(url: URL(string: profileImageUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        initialsView
                    }
                } else {
                    initialsView
                }
            }
            .frame(width: size.dimension, height: size.dimension)
            .clipShape(Circle())
            .background(
                Circle()
                    .fill(Color.primaryPurple)
            )
            
            // Online status indicator
            if showStatus, let user = user {
                Circle()
                    .fill(user.isOnline ? Color.onlineGreen : Color.offlineGray)
                    .frame(width: size.statusSize, height: size.statusSize)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                    )
                    .offset(x: 2, y: 2)
            }
        }
    }
    
    private var initialsView: some View {
        Circle()
            .fill(Color.primaryPurple)
            .overlay(
                Text(user?.initials ?? "?")
                    .font(.system(size: size.fontSize, weight: .semibold, design: .default))
                    .foregroundColor(.white)
            )
    }
}

enum AvatarSize {
    case small
    case medium
    case large
    case extraLarge
    
    var dimension: CGFloat {
        switch self {
        case .small: return Sizes.avatarSmall
        case .medium: return Sizes.avatarMedium
        case .large: return Sizes.avatarLarge
        case .extraLarge: return Sizes.avatarXLarge
        }
    }
    
    var fontSize: CGFloat {
        switch self {
        case .small: return 12
        case .medium: return 16
        case .large: return 24
        case .extraLarge: return 32
        }
    }
    
    var statusSize: CGFloat {
        switch self {
        case .small: return 8
        case .medium: return 12
        case .large: return 16
        case .extraLarge: return 20
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // Sample user for preview
        let sampleUser = SignalRUserDto(
            id: UUID(),
            userName: "john_doe",
            email: "john@example.com",
            firstName: "John",
            lastName: "Doe",
            companyId: "NOTHINGSOCIAL",
            isOnline: true,
            profileImageUrl: nil
        )
        
        HStack(spacing: 20) {
            AvatarView(user: sampleUser, size: .small)
            AvatarView(user: sampleUser, size: .medium)
            AvatarView(user: sampleUser, size: .large)
            AvatarView(user: sampleUser, size: .extraLarge)
        }
        
        HStack(spacing: 20) {
            AvatarView(user: nil, size: .medium)
            AvatarView(user: sampleUser, size: .medium, showStatus: false)
            
            let offlineUser = SignalRUserDto(
                id: UUID(),
                userName: "jane_smith",
                email: "jane@example.com",
                firstName: "Jane",
                lastName: "Smith",
                companyId: "NOTHINGSOCIAL",
                isOnline: false,
                profileImageUrl: nil
            )
            
            AvatarView(user: offlineUser, size: .medium)
        }
    }
    .padding()
}