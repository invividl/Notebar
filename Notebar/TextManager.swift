//
//  TextManager.swift
//  Notebar
//

import SwiftUI
import Observation

/// Holds the note text and persists it to UserDefaults automatically.
/// Uses the @Observable macro (macOS 14+) instead of the older
/// ObservableObject / @Published pattern.
@Observable
class TextManager {
    var text: String {
        didSet {
            UserDefaults.standard.set(text, forKey: "text")
        }
    }

    init() {
        text = UserDefaults.standard.string(forKey: "text") ?? ""
    }
}
