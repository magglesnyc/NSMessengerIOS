//
//  MediaModels.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/25/26.
//

import Foundation
import UIKit

// MARK: - Media Upload Models

public struct PendingMedia: Identifiable, Codable {
    public let id = UUID()
    public let data: Data
    public let fileName: String
    public let fileType: String
    public let originalImage: UIImage? // For display purposes, not stored
    
    public var isImage: Bool {
        return fileType.hasPrefix("image/")
    }
    
    public var isVideo: Bool {
        return fileType.hasPrefix("video/")
    }
    
    public var displaySize: String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(data.count))
    }
    
    public init(data: Data, fileName: String, fileType: String, originalImage: UIImage? = nil) {
        self.data = data
        self.fileName = fileName
        self.fileType = fileType
        self.originalImage = originalImage
    }
    
    // Custom Codable implementation since UIImage is not Codable
    private enum CodingKeys: String, CodingKey {
        case data, fileName, fileType
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.data = try container.decode(Data.self, forKey: .data)
        self.fileName = try container.decode(String.self, forKey: .fileName)
        self.fileType = try container.decode(String.self, forKey: .fileType)
        self.originalImage = nil // Can't decode UIImage
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(data, forKey: .data)
        try container.encode(fileName, forKey: .fileName)
        try container.encode(fileType, forKey: .fileType)
        // Don't encode originalImage since UIImage is not Codable
    }
}

// MARK: - Media Upload Response Models

public struct MediaUploadResponse: Codable {
    public let mediaId: String
    public let storageUrl: String
    public let thumbnailUrl: String?
    
    public init(mediaId: String, storageUrl: String, thumbnailUrl: String? = nil) {
        self.mediaId = mediaId
        self.storageUrl = storageUrl
        self.thumbnailUrl = thumbnailUrl
    }
}

public struct MediaUploadResult {
    public let success: Bool
    public let response: MediaUploadResponse?
    public let error: Error?
    
    public init(success: Bool, response: MediaUploadResponse? = nil, error: Error? = nil) {
        self.success = success
        self.response = response
        self.error = error
    }
}

// MARK: - Media Upload Error

public enum MediaUploadError: LocalizedError {
    case invalidData
    case networkError(String)
    case serverError(String)
    case unknownError
    
    public var errorDescription: String? {
        switch self {
        case .invalidData:
            return "Invalid media data"
        case .networkError(let message):
            return "Network error: \(message)"
        case .serverError(let message):
            return "Server error: \(message)"
        case .unknownError:
            return "Unknown error occurred"
        }
    }
}