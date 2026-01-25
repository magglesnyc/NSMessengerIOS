//
//  CardView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct CardView<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading) {
            content
        }
        .padding(Spacing.xxl)
        .background(Color.backgroundWhite)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.borderColor, lineWidth: BorderWidth.standard)
        )
        .cardShadow()
    }
}

struct FeedBlockCard<Content: View>: View {
    let content: Content
    let hasAccent: Bool

    init(hasAccent: Bool = false, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.hasAccent = hasAccent
    }

    var body: some View {
        HStack(spacing: 0) {
            if hasAccent {
                Rectangle()
                    .fill(Color.primaryPurple)
                    .frame(width: BorderWidth.accent)
            }
            VStack(alignment: .leading) {
                content
            }
            .padding(Spacing.xxl)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Color.backgroundWhite)
        .cornerRadius(CornerRadius.medium)
        .overlay(
            RoundedRectangle(cornerRadius: CornerRadius.medium)
                .stroke(Color.borderColor, lineWidth: BorderWidth.standard)
        )
        .cardShadow()
    }
}

#Preview {
    VStack(spacing: 20) {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Card Title")
                    .font(.h6)
                    .foregroundColor(.textPrimary)
                
                Text("This is some sample content in a card component.")
                    .font(.bodyText)
                    .foregroundColor(.textSecondary)
            }
        }
        
        FeedBlockCard(hasAccent: true) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Feed Block Card")
                    .font(.h6)
                    .foregroundColor(.textPrimary)
                
                Text("This card has a purple accent border on the left.")
                    .font(.bodyText)
                    .foregroundColor(.textSecondary)
            }
        }
        
        FeedBlockCard(hasAccent: false) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Regular Feed Block")
                    .font(.h6)
                    .foregroundColor(.textPrimary)
                
                Text("This card doesn't have an accent border.")
                    .font(.bodyText)
                    .foregroundColor(.textSecondary)
            }
        }
    }
    .padding()
    .background(Color.backgroundPrimary)
}
