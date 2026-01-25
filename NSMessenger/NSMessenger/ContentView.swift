//
//  ContentView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

struct ContentView: View {
    @StateObject private var authService = AuthService.shared
    
    var body: some View {
        Group {
            if authService.authState.isAuthenticated {
                #if os(iOS)
                MobileChatListView(viewModel: ChatViewModel())
                    .onAppear {
                        print("✅ MobileChatListView loaded successfully")
                    }
                #else
                MainView()
                #endif
            } else {
                LoginView()
            }
        }
        .onAppear {
            print("🚀 ContentView appeared")
            // Check for existing authentication when the app starts
            authService.checkExistingAuthentication()
        }
    }
}

#Preview {
    ContentView()
}
