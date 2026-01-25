//
//  DebugNetworkHelper.swift
//  NSMessenger
//
//  Created by Assistant on 1/21/26.
//

import Foundation
import SwiftUI

/// A debug helper view you can temporarily add to your app to diagnose server issues
struct NetworkDebugView: View {
    @StateObject private var authService = AuthService.shared
    @State private var isExploring = false
    @State private var isTesting = false
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Network Debug Tools")
                .font(.title2)
                .bold()
            
            VStack(spacing: 16) {
                Button(action: {
                    Task {
                        isTesting = true
                        await authService.testAllEnvironments()
                        isTesting = false
                    }
                }) {
                    HStack {
                        Image(systemName: "network")
                        Text("Test All Environments")
                        if isTesting {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.blue)
                    .cornerRadius(8)
                }
                .disabled(isTesting)
                
                Button(action: {
                    Task {
                        isExploring = true
                        await authService.exploreServer()
                        isExploring = false
                    }
                }) {
                    HStack {
                        Image(systemName: "magnifyingglass")
                        Text("Explore Server (10.10.60.70)")
                        if isExploring {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.green)
                    .cornerRadius(8)
                }
                .disabled(isExploring)
                
                Button(action: {
                    Task {
                        // Quick test of HTTP version
                        print("🧪 Quick test: Trying HTTP version...")
                        let configManager = ConfigurationManager.shared
                        await configManager.setEnvironment(.qaInsecure) // HTTP version
                        
                        do {
                            let success = try await authService.login(username: "maggie@axmca.com", password: "Ha3lenut")
                            print(success ? "✅ HTTP login worked!" : "❌ HTTP login failed")
                        } catch {
                            print("❌ HTTP login error: \(error)")
                        }
                    }
                }) {
                    HStack {
                        Image(systemName: "lock.open")
                        Text("Try HTTP (Insecure)")
                    }
                    .foregroundColor(.white)
                    .padding()
                    .background(Color.orange)
                    .cornerRadius(8)
                }
            }
            
            Text("Check the Xcode console for detailed output")
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.top)
        }
        .padding()
    }
}

#Preview {
    NetworkDebugView()
}

/// Extension to make it easy to add debug methods to your existing views
extension View {
    /// Add this to any view for quick debugging
    func withNetworkDebug() -> some View {
        VStack {
            self
            
            Divider()
            
            NetworkDebugView()
                .background(Color(.systemGray6))
        }
    }
}