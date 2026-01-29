//
//  SSLDebugView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/24/26.
//

import SwiftUI

struct SSLDebugView: View {
    @ObservedObject private var authService = AuthService.shared
    @State private var isRunningTest = false
    @State private var testResults = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    
                    Text("SSL Certificate Debugging")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text("Use these tools to diagnose SSL connection issues with your development server.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    VStack(spacing: 12) {
                        
                        Button(action: {
                            runSSLDiagnosis()
                        }) {
                            HStack {
                                Image(systemName: "stethoscope")
                                Text("Run SSL Diagnosis")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isRunningTest)
                        
                        Button(action: {
                            runServerExploration()
                        }) {
                            HStack {
                                Image(systemName: "magnifyingglass.circle")
                                Text("Explore Server")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.orange)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isRunningTest)
                        
                        Button(action: {
                            testAllEnvironments()
                        }) {
                            HStack {
                                Image(systemName: "gear")
                                Text("Test All Environments")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                        .disabled(isRunningTest)
                        
                        Button(action: {
                            clearResults()
                        }) {
                            HStack {
                                Image(systemName: "trash")
                                Text("Clear Results")
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.red)
                            .foregroundColor(.white)
                            .cornerRadius(8)
                        }
                    }
                    
                    if isRunningTest {
                        HStack {
                            ProgressView()
                                .scaleEffect(0.8)
                            Text("Running test...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .padding()
                    }
                    
                    if !testResults.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Test Results")
                                .font(.headline)
                            
                            ScrollView {
                                Text(testResults)
                                    .font(.system(.caption, design: .monospaced))
                                    .padding()
                                    .background(Color.gray.opacity(0.1))
                                    .cornerRadius(8)
                            }
                            .frame(maxHeight: 400)
                        }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Troubleshooting Tips")
                            .font(.headline)
                        
                        Group {
                            Label("Check your Info.plist for ATS configuration", systemImage: "doc.text")
                            Label("Ensure your development server certificate is properly configured", systemImage: "checkmark.shield")
                            Label("Try connecting using different URLs (domain vs IP)", systemImage: "network")
                            Label("Check console output for detailed SSL debug information", systemImage: "terminal")
                        }
                        .font(.caption)
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding()
            }
            .navigationTitle("SSL Debug")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
    
    private func runSSLDiagnosis() {
        isRunningTest = true
        testResults = "Starting SSL diagnosis...\n"
        
        Task {
            await authService.diagnoseSSLIssues()
            
            await MainActor.run {
                testResults += "\nSSL diagnosis completed. Check console for detailed output."
                isRunningTest = false
            }
        }
    }
    
    private func runServerExploration() {
        isRunningTest = true
        testResults = "Starting server exploration...\n"
        
        Task {
            await authService.exploreServer()
            
            await MainActor.run {
                testResults += "\nServer exploration completed. Check console for detailed output."
                isRunningTest = false
            }
        }
    }
    
    private func testAllEnvironments() {
        isRunningTest = true
        testResults = "Testing all configured environments...\n"
        
        Task {
            await authService.testAllEnvironments()
            
            await MainActor.run {
                testResults += "\nEnvironment testing completed. Check console for detailed output."
                isRunningTest = false
            }
        }
    }
    
    private func clearResults() {
        testResults = ""
    }
}

#Preview {
    SSLDebugView()
}