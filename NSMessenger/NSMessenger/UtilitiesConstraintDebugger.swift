//
//  ConstraintDebugger.swift
//  NSMessenger
//
//  Created by Margaret Anderson on 1/20/26.
//

import SwiftUI

/// A view modifier to help debug constraint conflicts by adding a border and logging frame changes
struct ConstraintDebugger: ViewModifier {
    let name: String
    let showBorder: Bool
    
    init(name: String, showBorder: Bool = false) {
        self.name = name
        self.showBorder = showBorder
    }
    
    func body(content: Content) -> some View {
        content
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            print("🔍 [\(name)] Frame: \(geometry.frame(in: .global))")
                        }
                        .onChange(of: geometry.frame(in: .global)) { newFrame in
                            print("🔍 [\(name)] Frame changed to: \(newFrame)")
                        }
                }
            )
            .border(showBorder ? Color.red : Color.clear, width: 1)
    }
}

extension View {
    /// Adds constraint debugging capabilities to any view
    func debugConstraints(_ name: String, showBorder: Bool = false) -> some View {
        #if DEBUG
        return self.modifier(ConstraintDebugger(name: name, showBorder: showBorder))
        #else
        return self
        #endif
    }
}