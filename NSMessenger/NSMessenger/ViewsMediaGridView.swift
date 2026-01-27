//
//  MediaGridView.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/25/26.
//

import SwiftUI

struct MediaGridView: View {
    let attachments: [MediaAttachmentDto]
    let maxWidth: CGFloat
    
    private let spacing: CGFloat = 4
    private let cornerRadius: CGFloat = 8
    
    var body: some View {
        if attachments.count == 1 {
            // Single media item
            SingleMediaView(attachment: attachments[0], maxWidth: maxWidth)
        } else if attachments.count == 2 {
            // Two items side by side
            HStack(spacing: spacing) {
                ForEach(attachments, id: \.id) { attachment in
                    SingleMediaView(
                        attachment: attachment,
                        maxWidth: (maxWidth - spacing) / 2
                    )
                }
            }
        } else if attachments.count == 3 {
            // Three items: one on top, two on bottom
            VStack(spacing: spacing) {
                SingleMediaView(
                    attachment: attachments[0],
                    maxWidth: maxWidth
                )
                
                HStack(spacing: spacing) {
                    SingleMediaView(
                        attachment: attachments[1],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                    SingleMediaView(
                        attachment: attachments[2],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                }
            }
        } else if attachments.count == 4 {
            // Four items in a 2x2 grid
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    SingleMediaView(
                        attachment: attachments[0],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                    SingleMediaView(
                        attachment: attachments[1],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                }
                
                HStack(spacing: spacing) {
                    SingleMediaView(
                        attachment: attachments[2],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                    SingleMediaView(
                        attachment: attachments[3],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                }
            }
        } else {
            // More than 4 items: 2x2 grid with "+X more" overlay on last item
            VStack(spacing: spacing) {
                HStack(spacing: spacing) {
                    SingleMediaView(
                        attachment: attachments[0],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                    SingleMediaView(
                        attachment: attachments[1],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                }
                
                HStack(spacing: spacing) {
                    SingleMediaView(
                        attachment: attachments[2],
                        maxWidth: (maxWidth - spacing) / 2
                    )
                    
                    ZStack {
                        SingleMediaView(
                            attachment: attachments[3],
                            maxWidth: (maxWidth - spacing) / 2
                        )
                        
                        // Overlay showing additional count
                        Rectangle()
                            .fill(Color.black.opacity(0.6))
                            .overlay {
                                Text("+\(attachments.count - 4)")
                                    .font(.lato(16, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .cornerRadius(cornerRadius)
                    }
                }
            }
        }
    }
}

struct SingleMediaView: View {
    let attachment: MediaAttachmentDto
    let maxWidth: CGFloat
    
    @State private var loadedImage: UIImage?
    @State private var isLoading = true
    @State private var loadError = false
    
    private let aspectRatio: CGFloat = 1.0 // Square aspect ratio for grid
    
    var body: some View {
        ZStack {
            if loadError {
                // Error state
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.backgroundSecondary)
                    .frame(width: maxWidth, height: maxWidth * aspectRatio)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: errorIcon)
                                .font(.title2)
                                .foregroundColor(.textSecondary)
                            
                            Text("Failed to load")
                                .font(.lato(10, weight: .regular))
                                .foregroundColor(.textSecondary)
                        }
                    }
            } else if isLoading {
                // Loading state
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.backgroundSecondary)
                    .frame(width: maxWidth, height: maxWidth * aspectRatio)
                    .overlay {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .accent))
                    }
            } else if let image = loadedImage {
                // Loaded image
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: maxWidth, height: maxWidth * aspectRatio)
                    .clipped()
                    .cornerRadius(8)
                    .overlay(alignment: .bottomTrailing) {
                        if attachment.isVideo {
                            Image(systemName: "play.circle.fill")
                                .foregroundColor(.white)
                                .background(Color.black.opacity(0.6))
                                .clipShape(Circle())
                                .font(.title3)
                                .padding(4)
                        }
                    }
            } else {
                // Placeholder for non-image files
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.backgroundSecondary)
                    .frame(width: maxWidth, height: maxWidth * aspectRatio)
                    .overlay {
                        VStack(spacing: 4) {
                            Image(systemName: fileIcon)
                                .font(.title2)
                                .foregroundColor(.accent)
                            
                            Text(attachment.fileName)
                                .font(.lato(10, weight: .regular))
                                .foregroundColor(.textPrimary)
                                .lineLimit(2)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 4)
                        }
                    }
            }
        }
        .onAppear {
            loadMedia()
        }
    }
    
    private var fileIcon: String {
        if attachment.isImage {
            return "photo"
        } else if attachment.isVideo {
            return "video"
        } else if attachment.isAudio {
            return "music.note"
        } else if attachment.isPDF {
            return "doc.text"
        } else {
            return "doc"
        }
    }
    
    private var errorIcon: String {
        if attachment.isImage || attachment.isVideo {
            return "photo.badge.exclamationmark"
        } else {
            return "doc.badge.exclamationmark"
        }
    }
    
    private func loadMedia() {
        guard attachment.isImage else {
            // For non-images, don't try to load
            isLoading = false
            return
        }
        
        Task {
            do {
                // Try thumbnail first, fall back to main URL
                let urlString = attachment.thumbnailUrl ?? attachment.url
                guard let url = URL(string: urlString) else {
                    await MainActor.run {
                        loadError = true
                        isLoading = false
                    }
                    return
                }
                
                let (data, _) = try await URLSession.shared.data(from: url)
                
                if let image = UIImage(data: data) {
                    await MainActor.run {
                        loadedImage = image
                        isLoading = false
                    }
                } else {
                    await MainActor.run {
                        loadError = true
                        isLoading = false
                    }
                }
                
            } catch {
                print("❌ MediaGridView: Failed to load image from \(attachment.url): \(error)")
                await MainActor.run {
                    loadError = true
                    isLoading = false
                }
            }
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        // Single image
        MediaGridView(
            attachments: [
                MediaAttachmentDto(
                    id: "1",
                    fileName: "test1.jpg",
                    fileSize: 1000,
                    mimeType: "image/jpeg",
                    url: "https://via.placeholder.com/300"
                )
            ],
            maxWidth: 250
        )
        
        // Multiple images
        MediaGridView(
            attachments: [
                MediaAttachmentDto(
                    id: "1",
                    fileName: "test1.jpg",
                    fileSize: 1000,
                    mimeType: "image/jpeg",
                    url: "https://via.placeholder.com/300"
                ),
                MediaAttachmentDto(
                    id: "2",
                    fileName: "test2.jpg",
                    fileSize: 1000,
                    mimeType: "image/jpeg",
                    url: "https://via.placeholder.com/300"
                ),
                MediaAttachmentDto(
                    id: "3",
                    fileName: "test3.jpg",
                    fileSize: 1000,
                    mimeType: "image/jpeg",
                    url: "https://via.placeholder.com/300"
                )
            ],
            maxWidth: 250
        )
    }
    .padding()
}