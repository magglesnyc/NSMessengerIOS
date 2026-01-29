//
//  AppTypes.swift
//  NSMessenger
//
//  Created by Assistant on 1/27/26.
//

import Foundation
import SwiftUI
import UIKit
import Combine

// MARK: - This file consolidates all type definitions to resolve compilation issues
// This is a temporary solution until proper Xcode project organization is set up

// MARK: - Media Models

enum MediaType {
    case image
    case video
    case document
    case audio
    
    var fileTypes: [String] {
        switch self {
        case .image:
            return ["image/jpeg", "image/png", "image/gif", "image/webp", "image/bmp"]
        case .video:
            return ["video/mp4", "video/webm"]
        case .audio:
            return ["audio/mpeg", "audio/ogg"]
        case .document:
            return ["application/pdf"]
        }
    }
}

struct SelectedMedia: Identifiable {
    let id = UUID()
    let data: Data
    let fileName: String
    let fileType: String
    let mediaType: MediaType
}

struct MediaAttachmentDto: Codable, Identifiable {
    let id = UUID()
    let fileName: String
    let fileType: String
    let storageUrl: String
    let thumbnailUrl: String?
    
    private enum CodingKeys: String, CodingKey {
        case fileName, fileType, storageUrl, thumbnailUrl
    }
}

// MARK: - Media Service

@MainActor
class MediaService: ObservableObject {
    static let shared = MediaService()
    
    private let mediaServiceBaseUrl = "https://nsmessageserviceqa.axminc.com"
    private let maxFileSizeBytes = 10 * 1024 * 1024 // 10 MB
    private let targetImageSizeKB = 200
    
    private init() {}
    
    // MARK: - Image Compression
    
    func compressImage(_ image: UIImage, maxSizeKB: Int = 200) -> Data? {
        var compression: CGFloat = 1.0
        var imageData = image.jpegData(compressionQuality: compression)
        
        // Reduce quality first
        while let data = imageData, data.count > maxSizeKB * 1024, compression > 0.1 {
            compression -= 0.1
            imageData = image.jpegData(compressionQuality: compression)
        }
        
        // If still too large, resize
        if let data = imageData, data.count > maxSizeKB * 1024 {
            let scale = sqrt(Double(maxSizeKB * 1024) / Double(data.count))
            let newSize = CGSize(
                width: image.size.width * scale,
                height: image.size.height * scale
            )
            
            UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
            image.draw(in: CGRect(origin: .zero, size: newSize))
            let resizedImage = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()
            
            imageData = resizedImage?.jpegData(compressionQuality: 0.8)
        }
        
        return imageData
    }
    
    // MARK: - Video Compression
    
    func compressVideo(url: URL, maxSizeMB: Double = 10) async throws -> Data {
        // Placeholder for video compression
        return try Data(contentsOf: url)
    }
    
    // MARK: - Media Upload
    
    func uploadMultipleMedia(_ selectedMedia: [SelectedMedia]) async throws -> [MediaAttachmentDto] {
        var attachments: [MediaAttachmentDto] = []
        
        for media in selectedMedia {
            let attachment = try await uploadSingleMedia(media)
            attachments.append(attachment)
        }
        
        return attachments
    }
    
    private func uploadSingleMedia(_ media: SelectedMedia) async throws -> MediaAttachmentDto {
        // Create the upload request
        let uploadRequest = MediaUploadRequest(
            id: nil,
            fileName: media.fileName,
            fileType: media.fileType,
            fileData: media.data,
            encryptionKey: nil
        )
        
        // Simulate upload for now - replace with actual API call
        return MediaAttachmentDto(
            fileName: media.fileName,
            fileType: media.fileType,
            storageUrl: "https://example.com/files/\(media.id)",
            thumbnailUrl: media.mediaType == .image ? "https://example.com/thumbnails/\(media.id)" : nil
        )
    }
}

// MARK: - Media Upload Models

struct MediaUploadRequest: Codable {
    let id: String?
    let fileName: String
    let fileType: String
    let fileData: Data
    let encryptionKey: String?
}

struct MediaUploadResponse: Codable {
    let mediaId: String
    let hash: String
    let alreadyExists: Bool
    let storageUrl: String
    let thumbnailUrl: String?
}

// MARK: - Keyboard Manager

class KeyboardManager: ObservableObject {
    @Published var keyboardHeight: CGFloat = 0
    @Published var isKeyboardVisible: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    
    init() {
        setupKeyboardObservers()
    }
    
    private func setupKeyboardObservers() {
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)
            .map { notification in
                (notification.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect)?.height ?? 0
            }
            .sink { [weak self] height in
                DispatchQueue.main.async {
                    self?.keyboardHeight = height
                    self?.isKeyboardVisible = height > 0
                }
            }
            .store(in: &cancellables)
        
        NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)
            .sink { [weak self] _ in
                DispatchQueue.main.async {
                    self?.keyboardHeight = 0
                    self?.isKeyboardVisible = false
                }
            }
            .store(in: &cancellables)
    }
    
    static func dismissKeyboard() {
        DispatchQueue.main.async {
            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        }
    }
    
    static func showKeyboard(delay: Double = 0.1, action: @escaping () -> Void) {
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            action()
        }
    }
}

// MARK: - Keyboard View Modifiers

struct KeyboardAware: ViewModifier {
    @StateObject private var keyboardManager = KeyboardManager()
    let offsetWhenVisible: CGFloat
    
    init(offsetWhenVisible: CGFloat = 0) {
        self.offsetWhenVisible = offsetWhenVisible
    }
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: keyboardManager.isKeyboardVisible ? max(offsetWhenVisible, 0) : 0)
                    .animation(.easeInOut(duration: 0.25), value: keyboardManager.isKeyboardVisible)
            }
            .environmentObject(keyboardManager)
    }
}

struct KeyboardSafePadding: ViewModifier {
    @StateObject private var keyboardManager = KeyboardManager()
    
    func body(content: Content) -> some View {
        content
            .safeAreaInset(edge: .bottom) {
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: keyboardManager.isKeyboardVisible ? 20 : 0)
                    .animation(.easeInOut(duration: 0.25), value: keyboardManager.isKeyboardVisible)
            }
            .environmentObject(keyboardManager)
    }
}

extension View {
    func keyboardAware(offsetWhenVisible: CGFloat = 0) -> some View {
        self.modifier(KeyboardAware(offsetWhenVisible: offsetWhenVisible))
    }
    
    func keyboardSafe() -> some View {
        self.modifier(KeyboardSafePadding())
    }
}

// MARK: - Chat Models & ViewModels

// Placeholder types - replace with actual implementations when available
struct ChatItemDto: Identifiable {
    let id = UUID()
    let conversationId: UUID
    let name: String
    let photoUrl: String
    let lastMessage: String
    let lastMessageTime: String
    let unreadCount: Int
    let isPinned: Bool
    let isGroup: Bool
    let status: String
    let otherUserId: UUID?
    
    var displayMessage: String {
        return lastMessage
    }
}

struct ChatMessage: Identifiable, Equatable {
    let id: String
    let senderId: String
    let senderName: String
    let content: String
    let timestamp: Date
    let isFromCurrentUser: Bool
    let isRead: Bool
}

struct MessageGroup: Identifiable, Equatable {
    var id: String { dateLabel }
    let dateLabel: String
    var messages: [ChatMessage]
}

struct UserInfo {
    let id: UUID
    let username: String
    let email: String
}

struct MessageDto: Identifiable {
    let id: String
    let conversationId: String
    let senderId: String
    let senderDisplayName: String
    let content: String
    let sentDate: Date
    let messageType: String
}

// Basic ChatViewModel placeholder
@MainActor
class ChatViewModel: ObservableObject {
    @Published var searchText = ""
    @Published var chats: [ChatItemDto] = []
    @Published var selectedChatId: UUID?
    @Published var currentMessages: [MessageDto] = []
    @Published var messageText = ""
    @Published var isTyping = false
    @Published var typingUsers: Set<UUID> = []
    @Published var messageGroups: [MessageGroup] = []
    @Published var shouldScrollToBottom = false
    
    func scrollToBottom() {
        print("📜 ChatViewModel: Triggering scroll to bottom")
        shouldScrollToBottom = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.shouldScrollToBottom = false
        }
    }
    
    func refreshMessages() async {
        // Placeholder implementation
        print("Refreshing messages...")
    }
    
    func sendMessage() {
        guard !messageText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        
        // Create new message
        let newMessage = ChatMessage(
            id: UUID().uuidString,
            senderId: "current-user",
            senderName: "You",
            content: messageText,
            timestamp: Date(),
            isFromCurrentUser: true,
            isRead: true
        )
        
        // Add to current group or create new one
        let today = DateFormatter().string(from: Date())
        if let lastGroup = messageGroups.last, lastGroup.dateLabel == today {
            messageGroups[messageGroups.count - 1].messages.append(newMessage)
        } else {
            let newGroup = MessageGroup(dateLabel: today, messages: [newMessage])
            messageGroups.append(newGroup)
        }
        
        messageText = ""
        scrollToBottom()
    }
    
    func sendMessageWithMedia(attachments: [MediaAttachmentDto]) {
        // Placeholder for media messages
        print("Sending message with \(attachments.count) attachments")
        sendMessage() // For now, just send as regular message
    }
    
    func onMessageTextChanged(_ text: String) {
        // Handle typing indicator
        print("Text changed: \(text)")
    }
    
    func debugConnection() {
        print("🐛 Debug: Connection status")
    }
    
    func testMessageLoading() {
        print("🐛 Debug: Test message loading")
    }
    
    func debugChatSelection(_ chatId: UUID) {
        print("🐛 Debug: Chat selection \(chatId)")
    }
    
    func debugSpecificMessage() {
        print("🐛 Debug: Specific message")
    }
    
    func forceReload() {
        print("🐛 Debug: Force reload")
    }
}

// MARK: - Design System

enum Spacing {
    static let xxs: CGFloat = 5
    static let xs: CGFloat = 8
    static let sm: CGFloat = 10
    static let md: CGFloat = 12
    static let lg: CGFloat = 15
    static let xl: CGFloat = 20
    static let xxl: CGFloat = 24
    static let xxxl: CGFloat = 30
}

// MARK: - Media Selection Sheet

import PhotosUI
import UniformTypeIdentifiers
import Combine

struct MediaSelectionSheet: View {
    @Binding var isPresented: Bool
    let onMediaSelected: ([SelectedMedia]) -> Void
    
    @State private var showingPhotoPicker = false
    @State private var showingDocumentPicker = false
    @State private var selectedMedia: [SelectedMedia] = []
    
    var body: some View {
        NavigationView {
            VStack(spacing: Spacing.lg) {
                Text("Add Media")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)
                
                VStack(spacing: Spacing.md) {
                    Button(action: {
                        showingPhotoPicker = true
                    }) {
                        HStack {
                            Image(systemName: "photo.on.rectangle")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading) {
                                Text("Photos & Videos")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Choose from your photo library")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Button(action: {
                        showingDocumentPicker = true
                    }) {
                        HStack {
                            Image(systemName: "doc")
                                .font(.title2)
                                .foregroundColor(.accentColor)
                            
                            VStack(alignment: .leading) {
                                Text("Documents")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                Text("Choose files from your device")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
                .padding(.horizontal)
                
                if !selectedMedia.isEmpty {
                    Text("Selected: \(selectedMedia.count) item(s)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                if !selectedMedia.isEmpty {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            onMediaSelected(selectedMedia)
                            isPresented = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .sheet(isPresented: $showingPhotoPicker) {
            MediaPickerView { media in
                selectedMedia.append(contentsOf: media)
            }
        }
        .sheet(isPresented: $showingDocumentPicker) {
            DocumentPickerView { media in
                selectedMedia.append(contentsOf: media)
            }
        }
    }
}

// MARK: - Media Picker Views

struct MediaPickerView: UIViewControllerRepresentable {
    let onMediaSelected: ([SelectedMedia]) -> Void
    
    func makeUIViewController(context: Context) -> PHPickerViewController {
        var configuration = PHPickerConfiguration()
        configuration.selectionLimit = 5
        configuration.filter = .any(of: [.images, .videos])
        
        let picker = PHPickerViewController(configuration: configuration)
        picker.delegate = context.coordinator
        return picker
    }
    
    func updateUIViewController(_ uiViewController: PHPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, PHPickerViewControllerDelegate {
        private let parent: MediaPickerView
        
        init(_ parent: MediaPickerView) {
            self.parent = parent
        }
        
        func picker(_ picker: PHPickerViewController, didFinishPicking results: [PHPickerResult]) {
            picker.dismiss(animated: true)
            
            Task {
                var selectedMedia: [SelectedMedia] = []
                
                for result in results {
                    if let data = try? await loadData(from: result) {
                        selectedMedia.append(data)
                    }
                }
                
                await MainActor.run {
                    parent.onMediaSelected(selectedMedia)
                }
            }
        }
        
        private func loadData(from result: PHPickerResult) async throws -> SelectedMedia? {
            // Simplified data loading - in a real app you'd handle different types
            return try await withCheckedThrowingContinuation { continuation in
                result.itemProvider.loadDataRepresentation(forTypeIdentifier: UTType.image.identifier) { data, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    guard let data = data else {
                        continuation.resume(returning: nil)
                        return
                    }
                    
                    let media = SelectedMedia(
                        data: data,
                        fileName: "image.jpg",
                        fileType: "image/jpeg",
                        mediaType: .image
                    )
                    
                    continuation.resume(returning: media)
                }
            }
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    let onMediaSelected: ([SelectedMedia]) -> Void
    
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .text, .data])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = true
        return picker
    }
    
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UIDocumentPickerDelegate {
        private let parent: DocumentPickerView
        
        init(_ parent: DocumentPickerView) {
            self.parent = parent
        }
        
        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            var selectedMedia: [SelectedMedia] = []
            
            for url in urls {
                if let data = try? Data(contentsOf: url) {
                    let media = SelectedMedia(
                        data: data,
                        fileName: url.lastPathComponent,
                        fileType: "application/octet-stream",
                        mediaType: .document
                    )
                    selectedMedia.append(media)
                }
            }
            
            parent.onMediaSelected(selectedMedia)
        }
    }
}