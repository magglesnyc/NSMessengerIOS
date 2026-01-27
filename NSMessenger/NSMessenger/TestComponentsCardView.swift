//
//  TestComponentsCardView.swift
//  NSMessenger
//
//  Created by Assistant on 1/25/26.
//

import SwiftUI

// Simple test to verify the design system is working
struct TestComponentsCardView: View {
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: 10) {
                Text("Test Card")
                    .font(.h6)
                    .foregroundColor(.textPrimary)
                
                Text("This tests the font issue is resolved.")
                    .font(.bodyText)
                    .foregroundColor(.textSecondary)
            }
        }
        .padding()
        .background(Color.backgroundPrimary)
    }
}

#Preview {
    TestComponentsCardView()
}