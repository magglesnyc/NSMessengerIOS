//
//  MediaUploadService.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/25/26.
//

import Foundation
import UIKit

@MainActor
class MediaUploadService: ObservableObject {
    static let shared = MediaUploadService()
    
    private let baseURL = AppConfig.baseURL
    private let authService = AuthService.shared
    
    private init() {}
    
    // MARK: - Public Methods
    
    /// Upload a single media file
    func uploadMedia(_ media: PendingMedia) async -> Result<MediaUploadResponse, MediaUploadError> {
        guard let accessToken = authService.accessToken else {
            print("❌ MediaUploadService: No access token available")
            return .failure(.networkError("No access token"))
        }
        
        guard let url = URL(string: "\(baseURL)/api/media/upload") else {
            print("❌ MediaUploadService: Invalid upload URL")
            return .failure(.networkError("Invalid URL"))
        }
        
        print("🔄 MediaUploadService: Uploading media file: \(media.fileName)")
        
        do {
            var request = URLRequest(url: url)
            request.httpMethod = "POST"
            request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
            
            // Create multipart form data
            let boundary = UUID().uuidString
            request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            let httpBody = createMultipartBody(media: media, boundary: boundary)
            request.httpBody = httpBody
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse else {
                print("❌ MediaUploadService: Invalid response type")
                return .failure(.unknownError)
            }
            
            print("📡 MediaUploadService: Upload response status: \(httpResponse.statusCode)")
            
            if httpResponse.statusCode == 200 {
                let uploadResponse = try JSONDecoder().decode(MediaUploadResponse.self, from: data)
                print("✅ MediaUploadService: Upload successful - Media ID: \(uploadResponse.mediaId)")
                return .success(uploadResponse)
            } else {
                let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
                print("❌ MediaUploadService: Upload failed with status \(httpResponse.statusCode): \(errorMessage)")
                return .failure(.serverError(errorMessage))
            }
            
        } catch {
            print("❌ MediaUploadService: Upload error: \(error)")
            return .failure(.networkError(error.localizedDescription))
        }
    }
    
    /// Upload multiple media files
    func uploadMultipleMedia(_ mediaFiles: [PendingMedia]) async -> [Result<MediaUploadResponse, MediaUploadError>] {
        print("🔄 MediaUploadService: Starting upload of \(mediaFiles.count) media files")
        
        var results: [Result<MediaUploadResponse, MediaUploadError>] = []
        
        // Upload files sequentially to avoid overwhelming the server
        for media in mediaFiles {
            let result = await uploadMedia(media)
            results.append(result)
            
            // Small delay between uploads
            try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 second
        }
        
        let successCount = results.compactMap { try? $0.get() }.count
        print("✅ MediaUploadService: Completed upload batch - \(successCount)/\(mediaFiles.count) successful")
        
        return results
    }
    
    // MARK: - Private Methods
    
    private func createMultipartBody(media: PendingMedia, boundary: String) -> Data {
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(media.fileName)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: \(media.fileType)\r\n\r\n".data(using: .utf8)!)
        body.append(media.data)
        body.append("\r\n".data(using: .utf8)!)
        
        // Add closing boundary
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        return body
    }
}

// MARK: - Extensions

private extension Data {
    mutating func append(_ string: String) {
        if let data = string.data(using: .utf8) {
            append(data)
        }
    }
}