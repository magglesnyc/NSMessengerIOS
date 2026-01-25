//
//  LoginView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct LoginView: View {
    @StateObject private var viewModel = AuthViewModel()
    @State private var showPassword = false
    
    // Helper function to get the app icon
    private func getAppIcon() -> UIImage? {
        // Try to get the app icon from bundle
        guard let iconsDictionary = Bundle.main.infoDictionary?["CFBundleIcons"] as? [String: Any],
              let primaryIconsDictionary = iconsDictionary["CFBundlePrimaryIcon"] as? [String: Any],
              let iconFiles = primaryIconsDictionary["CFBundleIconFiles"] as? [String],
              let lastIcon = iconFiles.last else {
            return nil
        }
        
        return UIImage(named: lastIcon)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    Spacer()
                        .frame(height: geometry.size.height * 0.2)
                    
                    CardView {
                        VStack(spacing: Spacing.xl) {
                            // Logo and title
                            VStack(spacing: Spacing.md) {
                                // App logo - use separate asset for display
                                Group {
                                    // First try a separate logo asset
                                    if let _ = UIImage(named: "AppLogo") {
                                        Image("AppLogo")
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .shadow(color: Color.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                                    } else if let appIcon = getAppIcon() {
                                        // Try to get the actual app icon
                                        Image(uiImage: appIcon)
                                            .resizable()
                                            .aspectRatio(contentMode: .fit)
                                            .frame(width: 80, height: 80)
                                            .clipShape(RoundedRectangle(cornerRadius: 16))
                                            .shadow(color: Color.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                                    } else {
                                        // Fallback to enhanced system icon if custom icon not found
                                        ZStack {
                                            Circle()
                                                .fill(Color.primaryPurple)
                                                .frame(width: 80, height: 80)
                                            
                                            Image(systemName: "message.fill")
                                                .font(.system(size: 40, weight: .medium))
                                                .foregroundColor(.white)
                                        }
                                        .shadow(color: Color.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                                    }
                                }
                                
                                Text("NSMessenger")
                                    .font(.h1)
                                    .foregroundColor(Color.textPrimary)
                            }
                            
                            // Login form
                            VStack(spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    FormLabel(text: "EMAIL")
                                    TextField("Enter your email", text: $viewModel.username)
                                        .textFieldStyle(AppTextFieldStyle())
                                        .textContentType(.emailAddress)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
                                }
                                
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    FormLabel(text: "PASSWORD")
                                    HStack {
                                        Group {
                                            if showPassword {
                                                TextField("Enter your password", text: $viewModel.password)
                                            } else {
                                                SecureField("Enter your password", text: $viewModel.password)
                                            }
                                        }
                                        .font(.input) // Use consistent font with username field
                                        .foregroundColor(Color.textPrimary)
                                        .textContentType(.password)
                                        .disableAutocorrection(true)
                                        
                                        Button(action: {
                                            showPassword.toggle()
                                        }) {
                                            Image(systemName: showPassword ? "eye.slash" : "eye")
                                                .foregroundColor(Color.textTertiary)
                                                .font(.system(size: 14))
                                        }
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
                            }
                            
                            // Error message
                            if !viewModel.errorMessage.isEmpty {
                                Text(viewModel.errorMessage)
                                    .font(.bodySmall)
                                    .foregroundColor(Color.errorRed)
                                    .multilineTextAlignment(.center)
                            }
                            
                            // Login button
                            Button(action: {
                                Task {
                                    await viewModel.login()
                                }
                            }) {
                                HStack {
                                    if viewModel.isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                            .tint(.white)
                                    } else {
                                        Text("LOGIN")
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            }
                            .buttonStyle(PrimaryButtonStyle(isDisabled: viewModel.isLoading))
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    
                    Spacer()
                        .frame(height: geometry.size.height * 0.2)
                }
                .frame(minHeight: geometry.size.height)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.backgroundPrimary)
        }
        .onSubmit {
            Task {
                await viewModel.login()
            }
        }
    }
}

#Preview {
    LoginView()
}
