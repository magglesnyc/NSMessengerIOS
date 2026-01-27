//
//  MediaPickerView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/25/26.
//

import SwiftUI
import PhotosUI
import UIKit

struct MediaPickerView: View {
    @Binding var selectedMedia: [PendingMedia]
    @Binding var isPresented: Bool
    let maxSelections: Int
    
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isProcessing = false
    
    var body: some View {
        NavigationView {
            VStack {
                if isProcessing {
                    VStack(spacing: Spacing.lg) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Processing media...")
                            .font(.lato(16, weight: .medium))
                            .foregroundColor(.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    PhotosPicker(
                        selection: $photoItems,
                        maxSelectionCount: maxSelections,
                        matching: .any(of: [.images, .videos]),
                        photoLibrary: .shared()
                    ) {
                        VStack(spacing: Spacing.lg) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 60))
                                .foregroundColor(.accent)
                            
                            VStack(spacing: Spacing.sm) {
                                Text("Select Media")
                                    .font(.lato(20, weight: .bold))
                                    .foregroundColor(.textPrimary)
                                
                                Text("Choose photos or videos to send")
                                    .font(.lato(14, weight: .regular))
                                    .foregroundColor(.textSecondary)
                                
                                Text("Up to \(maxSelections) items")
                                    .font(.lato(12, weight: .regular))
                                    .foregroundColor(.textTertiary)
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.backgroundPrimary)
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .navigationTitle("Select Media")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                
                if !selectedMedia.isEmpty && !isProcessing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") {
                            isPresented = false
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
        }
        .onChange(of: photoItems) { items in
            Task {
                await processSelectedItems(items)
            }
        }
    }
    
    @MainActor
    private func processSelectedItems(_ items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        isProcessing = true
        var newMedia: [PendingMedia] = []
        
        for item in items {
            do {
                if let data = try await item.loadTransferable(type: Data.self) {
                    // Determine file type and name
                    let (fileName, fileType) = await getFileInfo(for: item)
                    
                    // Get original image for preview if it's an image
                    var originalImage: UIImage? = nil
                    if fileType.hasPrefix("image/"), let image = UIImage(data: data) {
                        originalImage = image
                    }
                    
                    let pendingMedia = PendingMedia(
                        data: data,
                        fileName: fileName,
                        fileType: fileType,
                        originalImage: originalImage
                    )
                    
                    newMedia.append(pendingMedia)
                    print("✅ MediaPickerView: Processed \(fileName) (\(fileType))")
                }
            } catch {
                print("❌ MediaPickerView: Failed to process item: \(error)")
            }
        }
        
        selectedMedia = newMedia
        isProcessing = false
        
        // Auto-close if we have media
        if !newMedia.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                isPresented = false
            }
        }
    }
    
    private func getFileInfo(for item: PhotosPickerItem) async -> (fileName: String, fileType: String) {
        // Try to get the original filename and type
        if let identifier = item.itemIdentifier {
            // Create a default filename based on type
            let fileExtension: String
            let mimeType: String
            
            if item.supportedContentTypes.contains(.jpeg) {
                fileExtension = "jpg"
                mimeType = "image/jpeg"
            } else if item.supportedContentTypes.contains(.png) {
                fileExtension = "png"
                mimeType = "image/png"
            } else if item.supportedContentTypes.contains(.heic) {
                fileExtension = "heic"
                mimeType = "image/heic"
            } else if item.supportedContentTypes.contains(.mpeg4Movie) {
                fileExtension = "mp4"
                mimeType = "video/mp4"
            } else if item.supportedContentTypes.contains(.quickTimeMovie) {
                fileExtension = "mov"
                mimeType = "video/quicktime"
            } else {
                fileExtension = "bin"
                mimeType = "application/octet-stream"
            }
            
            let fileName = "media_\(UUID().uuidString.prefix(8)).\(fileExtension)"
            return (fileName, mimeType)
        }
        
        // Fallback
        return ("media_\(UUID().uuidString.prefix(8)).jpg", "image/jpeg")
    }
}

#Preview {
    MediaPickerView(
        selectedMedia: .constant([]),
        isPresented: .constant(true),
        maxSelections: 5
    )
}