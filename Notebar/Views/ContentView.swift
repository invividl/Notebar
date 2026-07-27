//
//  ContentView.swift
//  Notebar
//

import SwiftUI
import AppKit

struct ContentView: View {
    private let placeholder = "hello there"

    // The character macOS delivers for Shift+Tab ("back tab", U+0019). SwiftUI
    // routes it here rather than as Tab with a Shift modifier.
    private let backTab = KeyEquivalent("\u{19}")

    // The text system swallows the Backspace key before SwiftUI's onKeyPress
    // sees it, so we intercept it with a local key-down monitor instead.
    @State private var backspaceMonitor: Any?

    @State private var themeManager = ThemeManager()
    @State private var textManager = TextManager()

    // Tracks the current cursor / selection in the editor. Needed so we can
    // insert bullet continuations at the caret (macOS 15+).
    @State private var selection: TextSelection?

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
                    TextEditor(text: $textManager.text, selection: $selection)
                        .focused($isEditorFocused)
                        .font(.system(.body, design: .monospaced))
                        .foregroundStyle(themeManager.textColor)
                        .scrollContentBackground(.hidden)
                        .tint(.yellow)
                        .padding(.leading, -5)
                        .onKeyPress(.return) { continueListOnReturn() }
                        .onKeyPress(.space) { convertMarkerOnSpace() }
                        .onKeyPress(keys: [.tab, backTab]) { press in
                            // Shift+Tab arrives either as Tab with a Shift
                            // modifier or as the back-tab character.
                            let outdent = press.key == backTab || press.modifiers.contains(.shift)
                            return indentListItem(outdent: outdent)
                        }
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
        .onAppear {
            isEditorFocused = true
            installBackspaceMonitor()
        }
        .onDisappear { removeBackspaceMonitor() }
    }

    // MARK: - List editing

    /// The caret position, or `nil` when there's a ranged (non-empty) selection.
    private var caretIndex: String.Index? {
        guard let current = selection,
              current.isInsertion,
              case .selection(let range) = current.indices else {
            return nil
        }
        return range.lowerBound
    }

    /// Applies an edit produced by `ListContinuation` and moves the caret.
    ///
    /// The selection is cleared before assigning the new text: when the edit
    /// shortens the text (e.g. clearing a bullet), a stale caret pointing past
    /// the new end makes TextEditor build an inverted range and crash.
    private func apply(_ edit: (text: String, caretOffset: Int)) {
        selection = nil
        textManager.text = edit.text
        let caret = edit.text.index(edit.text.startIndex, offsetBy: edit.caretOffset)
        selection = TextSelection(insertionPoint: caret)
    }

    /// When Return is pressed on a list line, continue the list automatically.
    private func continueListOnReturn() -> KeyPress.Result {
        guard let caret = caretIndex,
              let edit = ListContinuation.handleReturn(in: textManager.text, caret: caret) else {
            return .ignored
        }
        apply(edit)
        return .handled
    }

    /// Tab nests the current list item; Shift+Tab un-nests it.
    private func indentListItem(outdent: Bool) -> KeyPress.Result {
        guard let caret = caretIndex,
              let edit = ListContinuation.handleIndent(in: textManager.text, caret: caret, outdent: outdent) else {
            return .ignored
        }
        apply(edit)
        return .handled
    }

    /// Installs a local key-down monitor so Backspace inside a list item's
    /// marker prefix removes the whole prefix (indent + bullet + space) in one
    /// press. Needed because onKeyPress never receives the Backspace key inside
    /// a TextEditor.
    ///
    /// The caret is read straight from the focused NSTextView and the edit is
    /// made through AppKit, rather than SwiftUI's selection binding: that
    /// binding is unreliable for carets we set programmatically (e.g. the empty
    /// bullet left after Return), which is why those cases failed before.
    private func installBackspaceMonitor() {
        guard backspaceMonitor == nil else { return }
        backspaceMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // keyCode 51 is the Backspace key. Ignore it with modifiers held.
            guard event.keyCode == 51,
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
                  let textView = event.window?.firstResponder as? NSTextView else {
                return event
            }

            let selected = textView.selectedRange()
            let text = textView.string
            guard selected.length == 0,
                  let caret = Range(selected, in: text)?.lowerBound,
                  let deleteRange = ListContinuation.backspacePrefixRange(in: text, caret: caret) else {
                return event
            }

            let nsRange = NSRange(deleteRange, in: text)
            guard textView.shouldChangeText(in: nsRange, replacementString: "") else { return nil }
            textView.textStorage?.deleteCharacters(in: nsRange)
            textView.didChangeText()
            textView.setSelectedRange(NSRange(location: nsRange.location, length: 0))
            return nil // consume the event
        }
    }

    private func removeBackspaceMonitor() {
        if let backspaceMonitor {
            NSEvent.removeMonitor(backspaceMonitor)
            self.backspaceMonitor = nil
        }
    }

    /// Typing a space after a lone `*` converts it to a bullet glyph.
    private func convertMarkerOnSpace() -> KeyPress.Result {
        guard let caret = caretIndex,
              let edit = ListContinuation.convertMarkerBeforeSpace(in: textManager.text, caret: caret) else {
            return .ignored
        }
        apply(edit)
        return .handled
    }
}

#Preview {
    ContentView()
}
