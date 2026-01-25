//
//  Typography.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/17/26.
//

import SwiftUI

extension Font {
    static func lato(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        return .system(size: size, weight: weight, design: .default)
    }
    
    // MARK: - Typography Scale
    
    // Headers
    static let h1 = Font.system(size: 28, weight: .bold, design: .default)          // Large Headers
    static let h2 = Font.system(size: 16, weight: .black, design: .default)         // Section Headers
    static let h4 = Font.system(size: 21, weight: .bold, design: .default)          // Card Titles (average of 18-24px)
    static let h5 = Font.system(size: 13.5, weight: .bold, design: .default)        // Subheaders (average of 11-16px)
    static let h6 = Font.system(size: 14, weight: .bold, design: .default)          // Small Headers
    
    // Body Text
    static let bodyText = Font.system(size: 13, weight: .regular, design: .default) // Average of 12-14px
    static let bodySmall = Font.system(size: 12, weight: .regular, design: .default)
    static let bodyLarge = Font.system(size: 14, weight: .regular, design: .default)
    
    // UI Elements
    static let caption = Font.system(size: 10.5, weight: .regular, design: .default) // Average of 9-12px
    static let label = Font.system(size: 12, weight: .bold, design: .default)        // Average of 10-14px
    static let button = Font.system(size: 12, weight: .bold, design: .default)
    static let input = Font.system(size: 12.5, weight: .regular, design: .default)   // Average of 11-14px
    
    // Chat-specific
    static let chatMessage = Font.system(size: 14, weight: .regular, design: .default)
    static let chatSenderName = Font.system(size: 10, weight: .bold, design: .default)
    static let chatTimestamp = Font.system(size: 9, weight: .regular, design: .default)
}
