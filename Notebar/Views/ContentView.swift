//
//  ContentView.swift
//  Notebar
//

import SwiftUI

struct ContentView: View {
    private let placeholder = "hello there"

    @State private var themeManager = ThemeManager()
    @State private var textManager = TextManager()

    // Native SwiftUI focus (macOS 12+). Replaces the old
    // MbSwiftUIFirstResponder dependency. Driving focus this way lets the
    // system route keystrokes (including Space and Return) into the editor.
    @FocusState private var isEditorFocused: Bool

    var body: some View {
        // A local bindable reference so we can pass a text binding to TextEditor.
        @Bindable var textManager = textManager

        ZStack {
            VStack(alignment: .leading, spacing: 0) {
                HeaderView()
                ZStack(alignment: .topLeading) {
                    TextEditor(text: $textManager.text)
                        .focused($isEditorFocused)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(themeManager.textColor)
                        .scrollContentBackground(.hidden)
                        .tint(.yellow)
                        .padding(.leading, -5)
                    if textManager.text.isEmpty {
                        Text(placeholder)
                            .font(.system(.body, design: .monospaced))
                            .foregroundStyle(themeManager.textColor)
                            .opacity(0.4)
                            .allowsHitTesting(false)
                    }
                }
                .padding(12)
                .background(themeManager.bgColor)
            }

            // Theme editor overlay. Currently hidden (isThemeEditor stays
            // false) — the dimming layer only intercepts taps while shown.
            ZStack {
                Color(.shadowColor)
                    .opacity(themeManager.isThemeEditor ? 0.5 : 0)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(themeManager.isThemeEditor)
                    .onTapGesture {
                        themeManager.hideThemeEditor()
                        isEditorFocused = true
                    }
                ThemeEditorView(themeManager: themeManager)
                    .frame(width: 240, height: 240)
                    .offset(y: themeManager.isThemeEditor ? 0 : 400)
            }
            .animation(.easeOut(duration: 0.25), value: themeManager.isThemeEditor)
        }
        .frame(width: 436, height: 400)
        .background(Color(.windowBackgroundColor))
        .onAppear { isEditorFocused = true }
    }
}

#Preview {
    ContentView()
}
