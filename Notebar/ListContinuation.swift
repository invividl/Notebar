//
//  ListContinuation.swift
//  Notebar
//

import Foundation

/// Plain-text "smart list" behaviour. Bullets are literally the characters at
/// the start of each line (how lightweight Markdown editors handle lists), so
/// the document stays a plain `String`.
///
/// Items are laid out on a 4-column grid: an item's *content* always starts on
/// a tab stop, with the marker hanging in the columns before it. So a
/// top-level bullet reads `  - hello` (content at column 4) and lines up with a
/// once-tab-indented plain line. This relies on the editor's monospaced font.
///
/// - Return continues the current list item, or clears an empty one.
/// - Tab / Shift+Tab nest / un-nest a list item, or soft-tab a plain line.
/// - Typing `* ` or `- ` snaps the marker onto the grid; `* ` also becomes a
///   bullet glyph (`•` at the top level, `◦` when nested). `-` stays literal.
enum ListContinuation {

    /// Width of one indent level / tab stop, in columns.
    static let tabWidth = 4

    /// Filled circle used for top-level circle bullets.
    static let circleBullet = "•"
    /// Hollow circle used for nested circle bullets.
    static let whiteCircle = "◦"

    // MARK: - Return

    /// Decides what a Return key press should do.
    ///
    /// - Returns: The new text and caret offset (in Characters from the start),
    ///   or `nil` when the current line isn't a list item — in which case the
    ///   caller should let the editor insert a normal newline.
    static func handleReturn(in text: String, caret: String.Index) -> (text: String, caretOffset: Int)? {
        let (lineStart, lineEnd) = lineBounds(in: text, around: caret)
        guard let item = parse(line: text[lineStart..<lineEnd]) else { return nil }

        if item.contentIsEmpty {
            // Empty item: remove the marker and end the list, leaving a blank
            // line. Don't insert a newline.
            let prefixEnd = text.index(lineStart, offsetBy: item.prefixLength)
            var newText = text
            newText.removeSubrange(lineStart..<prefixEnd)
            return (newText, text.distance(from: text.startIndex, to: lineStart))
        } else {
            // Continue the list on a new line, at the same nesting level.
            let insertion = "\n" + alignedPrefix(level: item.level, marker: item.continuationMarker)
            var newText = text
            newText.insert(contentsOf: insertion, at: caret)
            let caretOffset = text.distance(from: text.startIndex, to: caret) + insertion.count
            return (newText, caretOffset)
        }
    }

    // MARK: - Tab / Shift+Tab

    /// Nests (`outdent == false`) or un-nests (`outdent == true`) the current
    /// list item by one level, keeping its content on the tab-stop grid. On a
    /// plain (non-list) line it inserts or removes a 4-column soft tab instead.
    ///
    /// - Returns: `nil` when there's nothing to do (e.g. un-nesting a top-level
    ///   item, or a plain line with no leading spaces to remove).
    static func handleIndent(in text: String, caret: String.Index, outdent: Bool) -> (text: String, caretOffset: Int)? {
        let (lineStart, lineEnd) = lineBounds(in: text, around: caret)

        guard let item = parse(line: text[lineStart..<lineEnd]) else {
            return softTab(in: text, caret: caret, lineStart: lineStart, outdent: outdent)
        }

        let newLevel = outdent ? item.level - 1 : item.level + 1
        guard newLevel >= 0 else { return nil }

        let newMarker = item.marker(atLevel: newLevel)
        let newPrefix = alignedPrefix(level: newLevel, marker: newMarker)
        let newLine = newPrefix + item.content

        var newText = text
        newText.replaceSubrange(lineStart..<lineEnd, with: newLine)

        // Everything on the line shifts by the change in prefix length.
        let lineStartOffset = text.distance(from: text.startIndex, to: lineStart)
        let caretWithinLine = text.distance(from: lineStart, to: caret)
        let shifted = caretWithinLine + (newPrefix.count - item.prefixLength)
        let clamped = min(max(shifted, 0), newLine.count)
        return (newText, lineStartOffset + clamped)
    }

    /// Inserts or removes a soft tab on a plain line so its text sits on the
    /// same 4-column grid as list content.
    private static func softTab(in text: String, caret: String.Index, lineStart: String.Index, outdent: Bool) -> (text: String, caretOffset: Int)? {
        let column = text.distance(from: lineStart, to: caret)
        let caretOffset = text.distance(from: text.startIndex, to: caret)

        if outdent {
            // Remove the spaces back to the previous tab stop (up to tabWidth).
            let target = column == 0 ? 0 : ((column - 1) / tabWidth) * tabWidth
            var removeStart = caret
            var removed = 0
            while removed < (column - target),
                  removeStart > lineStart,
                  text[text.index(before: removeStart)] == " " {
                removeStart = text.index(before: removeStart)
                removed += 1
            }
            guard removed > 0 else { return nil }
            var newText = text
            newText.removeSubrange(removeStart..<caret)
            return (newText, caretOffset - removed)
        } else {
            // Advance to the next tab stop.
            let spaces = tabWidth - (column % tabWidth)
            var newText = text
            newText.insert(contentsOf: String(repeating: " ", count: spaces), at: caret)
            return (newText, caretOffset + spaces)
        }
    }

    // MARK: - Marker conversion

    /// When the caret sits right after a lone leading `*` or `-`, snaps the
    /// marker onto the tab-stop grid (adding the space the user just typed).
    /// `*` also becomes a bullet glyph appropriate for the nesting level.
    ///
    /// - Returns: `nil` when the line isn't `<indent>*` or `<indent>-`, so the
    ///   caller lets the editor insert a normal space.
    static func convertMarkerBeforeSpace(in text: String, caret: String.Index) -> (text: String, caretOffset: Int)? {
        let (lineStart, _) = lineBounds(in: text, around: caret)
        let typed = text[lineStart..<caret]
        let indent = typed.prefix { $0 == " " || $0 == "\t" }
        let rest = typed[indent.endIndex...]
        guard rest == "*" || rest == "-" else { return nil }

        let level = indent.count / tabWidth
        let marker: String
        if rest == "*" {
            marker = level == 0 ? circleBullet : whiteCircle
        } else {
            marker = "-"
        }
        let newPrefix = alignedPrefix(level: level, marker: marker)

        var newText = text
        newText.replaceSubrange(lineStart..<caret, with: newPrefix)
        let caretOffset = text.distance(from: text.startIndex, to: lineStart) + newPrefix.count
        return (newText, caretOffset)
    }

    // MARK: - Backspace

    /// The range of a list item's marker prefix (indent + marker + space) that
    /// a single Backspace should delete, so the user doesn't have to remove the
    /// space, glyph and indent one character at a time.
    ///
    /// Fires when the caret is anywhere within the prefix through the start of
    /// the content — which also covers an empty item, whose caret sits at the
    /// end of the trailing space.
    ///
    /// - Returns: `nil` when the caret isn't inside a list item's prefix, so
    ///   the caller performs a normal Backspace.
    static func backspacePrefixRange(in text: String, caret: String.Index) -> Range<String.Index>? {
        let (lineStart, lineEnd) = lineBounds(in: text, around: caret)
        guard let item = parse(line: text[lineStart..<lineEnd]) else { return nil }

        let prefixEnd = text.index(lineStart, offsetBy: item.prefixLength)
        // Leave a caret at the very start of the line alone, so Backspace there
        // still merges with the previous line as usual.
        guard caret > lineStart, caret <= prefixEnd else { return nil }

        return lineStart..<prefixEnd
    }

    // MARK: - Layout

    /// The prefix (padding + marker + space) that places an item's content on
    /// the tab stop for `level`.
    private static func alignedPrefix(level: Int, marker: String) -> String {
        let markerAndSpace = marker + " "
        let column = tabWidth * (level + 1)
        let padding = max(0, column - markerAndSpace.count)
        return String(repeating: " ", count: padding) + markerAndSpace
    }

    // MARK: - Parsing

    /// A single character that begins a bullet, mapped to whether it belongs to
    /// the circle family (glyph changes with depth) or stays literal.
    private enum Family {
        case dash          // "-" — literal at every level
        case circle        // "*" / "•" / "◦" — glyph depends on depth
        case ordered       // "1." / "2)" …
    }

    /// The parsed shape of a list line.
    private struct Item {
        let indent: Substring
        let markerText: String      // the marker as it appears now, e.g. "-", "•", "1."
        let content: Substring      // text after "marker + space"
        let family: Family
        let orderedNumber: Int?
        let orderedPunct: Character?

        var contentIsEmpty: Bool {
            content.trimmingCharacters(in: .whitespaces).isEmpty
        }

        /// Number of leading characters (indent + marker + space); also the
        /// column at which the content starts.
        var prefixLength: Int {
            indent.count + markerText.count + 1
        }

        /// The nesting level, derived from where the content sits on the grid.
        var level: Int {
            max(0, (prefixLength + tabWidth / 2) / tabWidth - 1)
        }

        /// The marker to use at a given nesting level.
        func marker(atLevel level: Int) -> String {
            switch family {
            case .dash:
                return "-"
            case .circle:
                return level <= 0 ? circleBullet : whiteCircle
            case .ordered:
                return markerText
            }
        }

        /// The marker for a continuation line at the current level.
        var continuationMarker: String {
            switch family {
            case .dash:
                return "-"
            case .circle:
                return marker(atLevel: level)
            case .ordered:
                return "\((orderedNumber ?? 0) + 1)\(orderedPunct ?? ".")"
            }
        }
    }

    private static func lineBounds(in text: String, around caret: String.Index) -> (start: String.Index, end: String.Index) {
        let start: String.Index
        if let newline = text[..<caret].lastIndex(of: "\n") {
            start = text.index(after: newline)
        } else {
            start = text.startIndex
        }
        let end = text[caret...].firstIndex(of: "\n") ?? text.endIndex
        return (start, end)
    }

    private static func parse(line: Substring) -> Item? {
        let indent = line.prefix { $0 == " " || $0 == "\t" }
        let rest = line[indent.endIndex...]

        // Single-character bullet markers followed by a space.
        let bulletFamilies: [Character: Family] = [
            "-": .dash,
            "*": .circle,
            Character(circleBullet): .circle,
            Character(whiteCircle): .circle,
        ]
        if let first = rest.first, let family = bulletFamilies[first],
           rest.dropFirst().first == " " {
            return Item(
                indent: indent,
                markerText: String(first),
                content: rest.dropFirst(2),
                family: family,
                orderedNumber: nil,
                orderedPunct: nil
            )
        }

        // Ordered: digits followed by "." or ")" and a space, e.g. "1. ".
        let digits = rest.prefix { $0.isNumber }
        if !digits.isEmpty {
            let afterDigits = rest[digits.endIndex...]
            if let punct = afterDigits.first, punct == "." || punct == ")",
               afterDigits.dropFirst().first == " " {
                return Item(
                    indent: indent,
                    markerText: "\(digits)\(punct)",
                    content: afterDigits.dropFirst(2),
                    family: .ordered,
                    orderedNumber: Int(digits),
                    orderedPunct: punct
                )
            }
        }

        return nil
    }
}
