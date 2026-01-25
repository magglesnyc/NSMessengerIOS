//
//  TabSelector.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct TabSelector: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    
    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs.indices, id: \.self) { index in
                VStack(spacing: Spacing.xxs) {
                    Text(tabs[index])
                        .font(.lato(10, weight: .semibold))
                        .foregroundColor(selectedTab == index ? Color.primaryPurple : Color.textMuted)
                    
                    Rectangle()
                        .fill(selectedTab == index ? Color.primaryPurple : Color.textMuted)
                        .frame(height: selectedTab == index ? BorderWidth.thick : BorderWidth.standard)
                }
                .padding(.horizontal, 26)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                    }
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        TabSelector(selectedTab: .constant(0), tabs: ["Chats", "Contacts"])
        TabSelector(selectedTab: .constant(1), tabs: ["All", "Unread", "Groups"])
        TabSelector(selectedTab: .constant(2), tabs: ["Online", "Away", "Offline"])
    }
    .padding()
    .background(Color.backgroundPrimary)
}