//
//  AvatarView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct AvatarView: View {
    let imageURL: String?
    let size: CGFloat
    let showStatus: Bool
    let status: UserStatusType
    
    init(imageURL: String? = nil, size: CGFloat = 40, showStatus: Bool = false, status: UserStatusType = .offline) {
        self.imageURL = imageURL
        self.size = size
        self.showStatus = showStatus
        self.status = status
    }
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let url = imageURL, !url.isEmpty, let imageUrl = URL(string: url) {
                AsyncImage(url: imageUrl) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    defaultAvatar
                }
                .frame(width: size, height: size)
                .clipShape(Circle())
            } else {
                defaultAvatar
            }

            if showStatus {
                StatusBadge(status: status, size: size * 0.25)
                    .offset(x: 2, y: 2)
            }
        }
    }

    private var defaultAvatar: some View {
        Circle()
            .fill(Color.lightPurple)
            .frame(width: size, height: size)
            .overlay(
                Image(systemName: "person.fill")
                    .foregroundColor(Color.textTertiary)
                    .font(.system(size: size * 0.5))
            )
    }
}

struct StatusBadge: View {
    let status: UserStatusType
    let size: CGFloat
    
    init(status: UserStatusType, size: CGFloat = 10) {
        self.status = status
        self.size = size
    }

    var body: some View {
        Circle()
            .fill(statusColor)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(Color.white, lineWidth: 2)
            )
    }

    private var statusColor: Color {
        switch status {
        case .available:
            return Color.successGreen
        case .away:
            return Color.warningOrange
        case .busy:
            return Color.errorRed
        case .offline:
            return Color.disabledGray
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        HStack(spacing: 20) {
            AvatarView(size: 80, showStatus: true, status: .available)
            AvatarView(size: 60, showStatus: true, status: .away)
            AvatarView(size: 40, showStatus: true, status: .busy)
            AvatarView(size: 30, showStatus: true, status: .offline)
        }
        
        HStack(spacing: 20) {
            AvatarView(imageURL: "https://via.placeholder.com/100", size: 80)
            AvatarView(imageURL: nil, size: 60)
        }
    }
    .padding()
}