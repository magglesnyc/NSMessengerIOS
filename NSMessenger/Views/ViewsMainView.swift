//
//  MainView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct MainView: View {
    @StateObject private var chatViewModel = ChatViewModel()
    @StateObject private var configManager = ServicesConfigurationManager.shared
    @StateObject private var authViewModel = AuthViewModel()
    @State private var selectedTab = 0
    @State private var showingSettings = false
    @State private var showingEnvironmentSelector = false
    
    private let tabs = ["Chats", "Contacts"]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                HeaderView(
                    selectedTab: $selectedTab,
                    tabs: tabs,
                    onProfileTap: { showingSettings = true },
                    onEnvironmentTap: { showingEnvironmentSelector = true }
                )
                
                // Tab content
                Group {
                    if selectedTab == 0 {
                        HStack(spacing: 0) {
                            ChatListView(viewModel: chatViewModel)
                                .frame(minWidth: 300, maxWidth: 400)
                            
                            ChatView(viewModel: chatViewModel)
                                .frame(minWidth: 400)
                        }
                    } else {
                        ContactsView { conversationId in
                            // Switch to chats tab and select the conversation
                            selectedTab = 0
                            chatViewModel.selectChat(conversationId)
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView(authViewModel: authViewModel)
        }
        .sheet(isPresented: $showingEnvironmentSelector) {
            EnvironmentSelectorSheet()
        }
    }
}

struct HeaderView: View {
    @Binding var selectedTab: Int
    let tabs: [String]
    let onProfileTap: () -> Void
    let onEnvironmentTap: () -> Void
    
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        HStack(spacing: Spacing.xl) {
            // Logo
            HStack(spacing: Spacing.md) {
                Image(systemName: "message.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.primaryPurple)
                
                Text("NSMessenger")
                    .font(.lato(18, weight: .bold))
                    .foregroundColor(.textPrimary)
            }
            
            Spacer()
            
            // Tab selector
            TabSelector(selectedTab: $selectedTab, tabs: tabs)
            
            Spacer()
            
            // Actions
            HStack(spacing: Spacing.lg) {
                // Environment selector button
                Button(action: onEnvironmentTap) {
                    Image(systemName: "gear")
                        .font(.system(size: 16))
                        .foregroundColor(.primaryPurple)
                }
                
                // Profile button
                Button(action: onProfileTap) {
                    HStack(spacing: Spacing.xs) {
                        Text(authService.authState.user?.displayName ?? "User")
                            .font(.bodyText)
                            .foregroundColor(.textPrimary)
                        
                        AvatarView(size: 24, showStatus: true, status: .available)
                    }
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.horizontal, Spacing.xl)
        .padding(.vertical, Spacing.lg)
        .background(Color.backgroundWhite)
        .headerShadow()
    }
}

struct EnvironmentSelectorSheet: View {
    @StateObject private var configManager = ServicesConfigurationManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.xl) {
                VStack(alignment: .leading, spacing: Spacing.md) {
                    Text("ENVIRONMENT")
                        .font(.lato(12, weight: .bold))
                        .foregroundColor(.primaryPurple)
                        .textCase(.uppercase)
                    
                    VStack(spacing: 0) {
                        ForEach(ServicesConfigurationManager.Environment.allCases, id: \.self) { environment in
                            EnvironmentRow(
                                environment: environment,
                                isSelected: configManager.environment == environment,
                                onSelect: {
                                    configManager.setEnvironment(environment)
                                }
                            )
                            
                            if environment != ServicesConfigurationManager.Environment.allCases.last {
                                Divider()
                            }
                        }
                    }
                    .background(Color.backgroundWhite)
                    .cornerRadius(CornerRadius.medium)
                    .cardShadow()
                }
                
                VStack(alignment: .leading, spacing: Spacing.sm) {
                    Text("CURRENT CONFIGURATION")
                        .font(.lato(12, weight: .bold))
                        .foregroundColor(.primaryPurple)
                        .textCase(.uppercase)
                    
                    VStack(spacing: Spacing.xs) {
                        ConfigurationRow(title: "Auth Server", value: configManager.environment.authServerUrl)
                        ConfigurationRow(title: "SignalR Hub", value: configManager.environment.signalRHubUrl)
                        ConfigurationRow(title: "Company ID", value: configManager.environment.companyId)
                    }
                    .padding(Spacing.lg)
                    .background(Color.backgroundGray)
                    .cornerRadius(CornerRadius.medium)
                }
                
                Spacer()
            }
            .padding(Spacing.xl)
            .navigationTitle("Configuration")
            .navigationBarItems(
                trailing: Button("Done") {
                    dismiss()
                }
            )
        }
    }
}

struct EnvironmentRow: View {
    let environment: ServicesConfigurationManager.Environment
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(environment.rawValue)
                        .font(.lato(14, weight: .semibold))
                        .foregroundColor(.textPrimary)
                    
                    Text(environment.authServerUrl)
                        .font(.lato(11, weight: .regular))
                        .foregroundColor(.textTertiary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.successGreen)
                        .font(.system(size: 20))
                }
            }
            .padding(Spacing.lg)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ConfigurationRow: View {
    let title: String
    let value: String
    
    var body: some View {
        HStack {
            Text(title)
                .font(.lato(12, weight: .bold))
                .foregroundColor(.textSecondary)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.lato(11, weight: .regular))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
            
            Spacer()
        }
    }
}

#Preview {
    MainView()
}