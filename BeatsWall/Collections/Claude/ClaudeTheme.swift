//
//  ClaudeTheme.swift
//  BeatsWall
//

import SwiftUI

enum ClaudeTheme {
    /// #D97757
    static let terracotta = Color(red: 0.851, green: 0.467, blue: 0.341)
    /// #C15F3C
    static let clay = Color(red: 0.757, green: 0.373, blue: 0.235)
    /// #F0EEE6
    static let cream = Color(red: 0.941, green: 0.933, blue: 0.902)
    /// #30302E
    static let charcoal = Color(red: 0.188, green: 0.188, blue: 0.180)
    /// #262624
    static let warmDark = Color(red: 0.149, green: 0.149, blue: 0.141)
    /// #141413
    static let ink = Color(red: 0.078, green: 0.078, blue: 0.075)

    /// Static paper grain that keeps flat fills from looking digital.
    static func grain(amount: Float = 0.035) -> Shader {
        ShaderLibrary.claudeGrain(.float(amount))
    }
}
