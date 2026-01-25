//
//  SettingsView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var authViewModel: AuthViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var selectedStatus: UserStatusType = .available
    @State private var notificationsEnabled = true
    @State private var showLastSeen = true
    @State private var isLoading = false
    
    private let authService = AuthService.shared
    @StateObject private var configManager = ConfigurationManager.shared
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: Spacing.xl) {
                    // Profile section
                    ProfileSection(
                        firstName: $firstName,
                        lastName: $lastName,
                        selectedStatus: $selectedStatus,
                        isLoading: $isLoading
                    )
                    
                    // Preferences section
                    PreferencesSection(
                        notificationsEnabled: $notificationsEnabled,
                        showLastSeen: $showLastSeen
                    )
                    
                    // Environment section (Debug/Testing)
                    EnvironmentSection(configManager: configManager)
                    
                    // Logout section
                    LogoutSection {
                        authViewModel.logout()
                        dismiss()
                    }
                }
                .padding(Spacing.xl)
            }
            .background(Color.backgroundPrimary)
            .navigationTitle("Settings")
            .navigationBarItems(
                leading: Button("Cancel") {
                    dismiss()
                },
                trailing: Button("Save") {
                    saveSettings()
                }
                .disabled(isLoading)
            )
        }
        .onAppear {
            loadCurrentSettings()
        }
    }
    
    private func loadCurrentSettings() {
        guard let user = authService.authState.user else { return }
        firstName = user.firstName ?? ""
        lastName = user.lastName ?? ""
        selectedStatus = .available // Default status
        
        // Load preferences from UserDefaults
        notificationsEnabled = UserDefaults.standard.bool(forKey: "notificationsEnabled")
        showLastSeen = UserDefaults.standard.bool(forKey: "showLastSeen")
    }
    
    private func saveSettings() {
        isLoading = true
        
        // Save preferences to UserDefaults
        UserDefaults.standard.set(notificationsEnabled, forKey: "notificationsEnabled")
        UserDefaults.standard.set(showLastSeen, forKey: "showLastSeen")
        
        // Update profile via SignalR would go here
        // For now, just simulate saving
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            isLoading = false
            dismiss()
        }
    }
}

struct ProfileSection: View {
    @Binding var firstName: String
    @Binding var lastName: String
    @Binding var selectedStatus: UserStatusType
    @Binding var isLoading: Bool
    
    private let authService = AuthService.shared
    
    var body: some View {
        CardView {
            VStack(spacing: Spacing.xl) {
                Text("PROFILE")
                    .font(.h5)
                    .foregroundColor(Color.primaryPurple)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Profile photo
                VStack(spacing: Spacing.md) {
                    ZStack {
                        AvatarView(size: 80, showStatus: false)
                        
                        Button(action: {
                            // Photo picker would go here
                        }) {
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.white)
                                .frame(width: 24, height: 24)
                                .background(Color.primaryPurple)
                                .clipShape(Circle())
                        }
                        .offset(x: 25, y: 25)
                    }
                    
                    Text("Tap to change photo")
                        .font(.caption)
                        .foregroundColor(.textTertiary)
                }
                
                // Form fields
                VStack(spacing: Spacing.lg) {
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        FormLabel(text: "FIRST NAME")
                        TextField("First name", text: $firstName)
                            .textFieldStyle(AppTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        FormLabel(text: "LAST NAME")
                        TextField("Last name", text: $lastName)
                            .textFieldStyle(AppTextFieldStyle())
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        FormLabel(text: "EMAIL")
                        Text(authService.authState.user?.email ?? "")
                            .font(.input)
                            .foregroundColor(.textTertiary)
                            .padding(.horizontal, Spacing.sm)
                            .padding(.vertical, Spacing.xxs)
                            .frame(height: 30)
                            .background(Color.backgroundGray)
                            .cornerRadius(CornerRadius.standard)
                    }
                    
                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        FormLabel(text: "STATUS")
                        StatusSelector(selectedStatus: $selectedStatus)
                    }
                }
            }
        }
    }
}

struct StatusSelector: View {
    @Binding var selectedStatus: UserStatusType
    
    var body: some View {
        Menu {
            ForEach(UserStatusType.allCases, id: \.self) { status in
                Button(action: {
                    selectedStatus = status
                }) {
                    HStack {
                        StatusBadge(status: status)
                        Text(status.rawValue)
                        
                        if selectedStatus == status {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack {
                StatusBadge(status: selectedStatus)
                Text(selectedStatus.rawValue)
                    .font(.input)
                    .foregroundColor(.textPrimary)
                
                Spacer()
                
                Image(systemName: "chevron.down")
                    .font(.system(size: 12))
                    .foregroundColor(.textTertiary)
            }
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
        .buttonStyle(PlainButtonStyle())
    }
}

struct PreferencesSection: View {
    @Binding var notificationsEnabled: Bool
    @Binding var showLastSeen: Bool
    
    var body: some View {
        CardView {
            VStack(spacing: Spacing.lg) {
                Text("PREFERENCES")
                    .font(.h5)
                    .foregroundColor(Color.primaryPurple)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: Spacing.lg) {
                    ToggleRow(
                        title: "Notifications",
                        subtitle: "Receive push notifications for new messages",
                        isOn: $notificationsEnabled
                    )
                    
                    Divider()
                    
                    ToggleRow(
                        title: "Show Last Seen",
                        subtitle: "Let others see when you were last active",
                        isOn: $showLastSeen
                    )
                }
            }
        }
    }
}

struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.lato(14, weight: .semibold))
                    .foregroundColor(.textPrimary)
                
                Text(subtitle)
                    .font(.lato(11, weight: .regular))
                    .foregroundColor(.textSecondary)
                    .lineLimit(nil)
            }
            
            Spacer()
            
            Toggle("", isOn: $isOn)
                .tint(Color.primaryPurple)
        }
    }
}

struct LogoutSection: View {
    let onLogout: () -> Void
    
    var body: some View {
        CardView {
            VStack(spacing: Spacing.lg) {
                Text("ACCOUNT")
                    .font(.h5)
                    .foregroundColor(Color.primaryPurple)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                Button(action: onLogout) {
                    HStack {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16))
                            .foregroundColor(.errorRed)
                        
                        Text("Logout")
                            .font(.lato(16, weight: .medium))
                            .foregroundColor(.errorRed)
                        
                        Spacer()
                    }
                    .padding(.vertical, Spacing.md)
                    .padding(.horizontal, Spacing.lg)
                    .background(Color.backgroundPrimary)
                    .cornerRadius(CornerRadius.standard)
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
    }
}

// MARK: - Environment Section
struct EnvironmentSection: View {
    @ObservedObject var configManager: ConfigurationManager
    
    var body: some View {
        CardView {
            VStack(alignment: .leading, spacing: Spacing.md) {
                Text("ENVIRONMENT")
                    .font(.h5)
                    .foregroundColor(Color.primaryPurple)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                VStack(spacing: Spacing.sm) {
                    ForEach(ConfigurationManager.Environment.allCases, id: \.self) { environment in
                        Button(action: {
                            configManager.setEnvironment(environment)
                        }) {
                            HStack {
                                Image(systemName: configManager.environment == environment ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 16))
                                    .foregroundColor(configManager.environment == environment ? Color.primaryPurple : Color.textTertiary)
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(environment.rawValue)
                                        .font(.lato(16, weight: .medium))
                                        .foregroundColor(Color.textPrimary)
                                    
                                    Text(environment.authServerUrl)
                                        .font(.lato(12, weight: .regular))
                                        .foregroundColor(Color.textTertiary)
                                }
                                
                                Spacer()
                            }
                            .padding(.vertical, Spacing.xs)
                            .padding(.horizontal, Spacing.sm)
                            .background(configManager.environment == environment ? Color.primaryPurple.opacity(0.1) : Color.clear)
                            .cornerRadius(CornerRadius.small)
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
                
                if configManager.environment == .qaDirectIP {
                    VStack(alignment: .leading, spacing: Spacing.xs) {
                        Text("⚠️ Using direct IP address")
                            .font(.lato(12, weight: .medium))
                            .foregroundColor(Color.warningOrange)
                        
                        Text("This bypasses DNS resolution and connects directly to the server IP. Use this if you're having DNS issues.")
                            .font(.lato(11, weight: .regular))
                            .foregroundColor(Color.textTertiary)
                    }
                    .padding(.top, Spacing.xs)
                }
            }
        }
    }
}

#Preview {
    SettingsView(authViewModel: AuthViewModel())
}
