//
//  ThemeManager.swift
//  Notebar
//

import SwiftUI
import Observation

enum Theme: String {
    case system
    case light
    case dark
}

/// Tracks the current theme and the derived text/background colors, and
/// persists the chosen theme to UserDefaults. Uses the @Observable macro
/// (macOS 14+).
@Observable
class ThemeManager {
    var isThemeEditor: Bool = false
    var currentTheme: Theme {
        didSet {
            UserDefaults.standard.set(currentTheme.rawValue, forKey: "theme")
        }
    }
    var bgColor = Color(.textBackgroundColor)
    var textColor = Color(.textColor)

    init() {
        let saved = UserDefaults.standard.string(forKey: "theme")
        currentTheme = saved.flatMap(Theme.init(rawValue:)) ?? .system
        setTextColor(currentTheme)
        setBgColor(currentTheme)
    }

    func showThemeEditor() {
        isThemeEditor = true
    }

    func hideThemeEditor() {
        isThemeEditor = false
    }

    func setTheme(_ t: Theme) {
        currentTheme = t
        setTextColor(t)
        setBgColor(t)
    }

    func setTextColor(_ t: Theme) {
        switch t {
        case .dark:
            textColor = Color(.sRGB, red: 255/255, green: 255/255, blue: 255/255)
        case .light:
            textColor = Color(.sRGB, red: 7/255, green: 7/255, blue: 7/255)
        case .system:
            textColor = Color(.textColor)
        }
    }

    func setBgColor(_ t: Theme) {
        switch t {
        case .dark:
            bgColor = Color(.sRGB, red: 30/255, green: 30/255, blue: 30/255)
        case .light:
            bgColor = Color(.sRGB, red: 255/255, green: 255/255, blue: 255/255)
        case .system:
            bgColor = Color(.textBackgroundColor)
        }
    }
}
