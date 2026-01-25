//
//  NSMessengerApp.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

@main
struct NSMessengerApp: App {
    
    init() {
        // Configure app-wide settings
        setupFontLoadingIfNeeded()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        #if os(macOS)
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
    
    // MARK: - App-wide Configuration
    
    private func setupFontLoadingIfNeeded() {
        // In a real app, you would load custom Lato fonts here
        // For this example, we'll use system fonts with similar characteristics
        print("App initialized - NSMessenger starting up")
    }
}
