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
    
    // Debug connection testing
    func testConnection(_ urlString: String) async {
        print("🧪 Testing connection to: \(urlString)")
        
        guard let url = URL(string: urlString) else {
            print("❌ Invalid URL")
            return
        }
        
        do {
            let (_, response) = try await URLSession.shared.data(from: url)
            if let httpResponse = response as? HTTPURLResponse {
                print("✅ Connection successful! Status: \(httpResponse.statusCode)")
            } else {
                print("🤔 Unexpected response type")
            }
        } catch {
            print("❌ Connection failed: \(error)")
        }
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
                                // App logo - enhanced system icon
                                ZStack {
                                    Circle()
                                        .fill(Color.primaryPurple)
                                        .frame(width: 80, height: 80)
                                    
                                    Image(systemName: "message.fill")
                                        .font(.system(size: 40, weight: .medium))
                                        .foregroundColor(.white)
                                }
                                .shadow(color: Color.primaryPurple.opacity(0.3), radius: 8, x: 0, y: 4)
                                
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
                                        .foregroundColor(Color.textPrimary) // Ensure visible text
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
                                
                                // Company ID field - optional to match web behavior
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    FormLabel(text: "COMPANY ID (OPTIONAL)")
                                    TextField("Leave blank if unsure", text: $viewModel.companyId)
                                        .textFieldStyle(AppTextFieldStyle())
                                        .autocapitalization(.none)
                                        .disableAutocorrection(true)
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
                            
                            // Debug/Network Testing Section
                            VStack(spacing: Spacing.sm) {
                                Text("Connection Debug")
                                    .font(.h5)
                                    .foregroundColor(Color.textTertiary)
                                
                                VStack(spacing: Spacing.xs) {
                                    HStack(spacing: Spacing.xs) {
                                        Button("Test Domain") {
                                            Task {
                                                await testConnection("https://authqa.axminc.com/api/Auth/Login")
                                            }
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .font(.caption)
                                        
                                        Button("Test IP") {
                                            Task {
                                                await testConnection("https://10.10.60.70/api/Auth/Login")
                                            }
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .font(.caption)
                                        
                                        Button("Test HTTP") {
                                            Task {
                                                await testConnection("http://10.10.60.70/api/Auth/Login")
                                            }
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .font(.caption)
                                    }
                                    
                                    HStack(spacing: Spacing.xs) {
                                        Button("Debug Token") {
                                            viewModel.debugToken()
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .font(.caption)
                                        
                                        Button("Refresh Auth") {
                                            viewModel.debugRefreshAuth()
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .font(.caption)
                                        
                                        Button("Full Debug") {
                                            Task {
                                                await viewModel.debugConnections()
                                            }
                                        }
                                        .buttonStyle(SecondaryButtonStyle())
                                        .font(.caption)
                                    }
                                }
                                
                                Text("💡 Connection working! Check credentials if login fails.")
                                    .font(.caption2)
                                    .foregroundColor(Color.textTertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.top, Spacing.md)
                        }
                    }
                    .padding(.horizontal, Spacing.xl)
                    
                    Spacer()
                        .frame(height: geometry.size.height * 0.2)
                }
                .frame(minHeight: geometry.size.height)
            }
            .background(Color.backgroundPrimary)
            .ignoresSafeArea(.keyboard, edges: .bottom)
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