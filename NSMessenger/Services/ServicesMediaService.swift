//
//  MediaService.swift
//  NSMessenger
//
//  Created by Assistant on 1/27/26.
//

import Foundation
import UIKit

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
    
    // MARK: - Media Upload
    
    func uploadMedia(fileData: Data, fileName: String, fileType: String) async throws -> MediaUploadResponse {
        guard fileData.count <= maxFileSizeBytes else {
            throw MediaServiceError.fileTooLarge
        }
        
        let url = URL(string: "\(mediaServiceBaseUrl)/api/NSMedia/add")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        
        // Get auth token
        let authService = AuthService.shared
        if let token = authService.authState.token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        } else {
            throw MediaServiceError.notAuthenticated
        }
        
        let uploadRequest = MediaUploadRequest(
            id: nil,
            fileName: fileName,
            fileType: fileType,
            fileData: fileData,
            encryptionKey: nil
        )
        
        let encoder = JSONEncoder()
        request.httpBody = try encoder.encode(uploadRequest)
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            guard httpResponse.statusCode == 200 else {
                print("❌ Media upload failed with status: \(httpResponse.statusCode)")
                if let responseString = String(data: data, encoding: .utf8) {
                    print("❌ Error response: \(responseString)")
                }
                throw MediaServiceError.uploadFailed(statusCode: httpResponse.statusCode)
            }
        }
        
        let decoder = JSONDecoder()
        return try decoder.decode(MediaUploadResponse.self, from: data)
    }
    
    // MARK: - Batch Upload
    
    func uploadMultipleMedia(_ mediaItems: [SelectedMedia]) async throws -> [MediaAttachmentDto] {
        var attachments: [MediaAttachmentDto] = []
        
        for media in mediaItems {
            do {
                let response = try await uploadMedia(
                    fileData: media.data,
                    fileName: media.fileName,
                    fileType: media.fileType
                )
                
                let attachment = MediaAttachmentDto(
                    fileName: media.fileName,
                    fileType: media.fileType,
                    storageUrl: response.storageUrl,
                    thumbnailUrl: response.thumbnailUrl
                )
                
                attachments.append(attachment)
                print("✅ Uploaded \(media.fileName)")
                
            } catch {
                print("❌ Failed to upload \(media.fileName): \(error)")
                throw error
            }
        }
        
        return attachments
    }
    
    // MARK: - File Type Detection
    
    func getMediaType(for mimeType: String) -> MediaType {
        if MediaType.image.fileTypes.contains(mimeType) {
            return .image
        } else if MediaType.video.fileTypes.contains(mimeType) {
            return .video
        } else if MediaType.audio.fileTypes.contains(mimeType) {
            return .audio
        } else if MediaType.document.fileTypes.contains(mimeType) {
            return .document
        } else {
            return .document // Default fallback
        }
    }
    
    // MARK: - File Name Generation
    
    func generateFileName(for mediaType: MediaType) -> String {
        let timestamp = Int(Date().timeIntervalSince1970)
        
        switch mediaType {
        case .image:
            return "image_\(timestamp).jpg"
        case .video:
            return "video_\(timestamp).mp4"
        case .audio:
            return "audio_\(timestamp).mp3"
        case .document:
            return "document_\(timestamp).pdf"
        }
    }
}

// MARK: - Errors

enum MediaServiceError: LocalizedError {
    case fileTooLarge
    case notAuthenticated
    case uploadFailed(statusCode: Int)
    case invalidFileType
    case compressionFailed
    
    var errorDescription: String? {
        switch self {
        case .fileTooLarge:
            return "File is too large. Maximum size is 10 MB."
        case .notAuthenticated:
            return "User is not authenticated."
        case .uploadFailed(let statusCode):
            return "Upload failed with status code: \(statusCode)"
        case .invalidFileType:
            return "Invalid file type."
        case .compressionFailed:
            return "Failed to compress image."
        }
    }
}