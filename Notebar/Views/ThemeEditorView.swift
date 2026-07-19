//
//  ThemeEditorView.swift
//  Notebar
//

import SwiftUI

struct ThemeEditorView: View {
    // With @Observable, a plain reference is enough — SwiftUI tracks the
    // properties this view reads automatically (no @ObservedObject needed).
    var themeManager: ThemeManager

    var body: some View {
        HStack {
            Spacer()
            VStack(spacing: 24) {
                HStack(spacing: 12) {
                    Button {
                        themeManager.setTheme(.system)
                    } label: {
                        Image(systemName: "laptopcomputer")
                            .font(.largeTitle)
                            .frame(width: 48, height: 48)
                            .background((themeManager.currentTheme == .system) ? Color(.selectedControlColor) : Color(.controlColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8).stroke((themeManager.currentTheme == .system) ? Color(.selectedControlColor) : Color(.controlColor), lineWidth: 1)
                            )
                            .help("System default")
                    }
                    .buttonStyle(.plain)

                    Button {
                        themeManager.setTheme(.light)
                    } label: {
                        Image(systemName: "sun.max")
                            .font(.largeTitle)
                            .frame(width: 48, height: 48)
                            .background((themeManager.currentTheme == .light) ? Color(.selectedControlColor) : Color(.controlColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8).stroke((themeManager.currentTheme == .light) ? Color(.selectedControlColor) : Color(.controlColor), lineWidth: 1)
                            )
                            .help("Light mode")
                    }
                    .buttonStyle(.plain)

                    Button {
                        themeManager.setTheme(.dark)
                    } label: {
                        Image(systemName: "moon")
                            .font(.largeTitle)
                            .frame(width: 48, height: 48)
                            .background((themeManager.currentTheme == .dark) ? Color(.selectedControlColor) : Color(.controlColor))
                            .cornerRadius(8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8).stroke((themeManager.currentTheme == .dark) ? Color(.selectedControlColor) : Color(.controlColor), lineWidth: 1)
                            )
                            .help("Dark mode")
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 240, height: 240)
            .padding(12)
            .background(Color(.windowBackgroundColor))
            .cornerRadius(8)
            Spacer()
        }
    }
}

#Preview {
    ThemeEditorView(themeManager: ThemeManager())
}
