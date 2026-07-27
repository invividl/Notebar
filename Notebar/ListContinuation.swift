//
//  ListContinuation.swift
//  Notebar
//

import Foundation

/// Plain-text "smart list" behaviour. Bullets are literally the characters at
/// the start of each line (how lightweight Markdown editors handle lists), so
/// the document stays a plain `String`.
///
/// - Return continues the current list item, or clears an empty one.
/// - Tab / Shift+Tab nests / un-nests the current item.
/// - Typing `* ` converts the marker to a bullet glyph: `•` at the top level,
///   `◦` when nested. `-` is kept literally at every level.
enum ListContinuation {

    /// One level of nesting.
    static let indentUnit = "    " // 4 spaces

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
            let insertion = "\n" + item.indent + item.nextMarker + " "
            var newText = text
            newText.insert(contentsOf: insertion, at: caret)
            let caretOffset = text.distance(from: text.startIndex, to: caret) + insertion.count
            return (newText, caretOffset)
        }
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

    // MARK: - Tab / Shift+Tab

    /// Nests (`outdent == false`) or un-nests (`outdent == true`) the current
    /// list item by one level, updating circle-bullet glyphs for the new depth.
    ///
    /// - Returns: `nil` when the current line isn't a list item, or when
    ///   un-nesting a line that has no indentation to remove.
    static func handleIndent(in text: String, caret: String.Index, outdent: Bool) -> (text: String, caretOffset: Int)? {
        let (lineStart, lineEnd) = lineBounds(in: text, around: caret)
        guard let item = parse(line: text[lineStart..<lineEnd]) else { return nil }

        let newIndent: String
        if outdent {
            guard item.indent.count >= indentUnit.count else { return nil }
            newIndent = String(item.indent.dropLast(indentUnit.count))
        } else {
            newIndent = String(item.indent) + indentUnit
        }

        let newLevel = newIndent.count / indentUnit.count
        let newMarker = item.marker(atLevel: newLevel)
        let newLine = newIndent + newMarker + " " + item.content

        var newText = text
        newText.replaceSubrange(lineStart..<lineEnd, with: newLine)

        // Everything on the line shifts by the change in prefix length.
        let oldPrefixLength = item.indent.count + item.markerText.count + 1
        let newPrefixLength = newIndent.count + newMarker.count + 1
        let lineStartOffset = text.distance(from: text.startIndex, to: lineStart)
        let caretWithinLine = text.distance(from: lineStart, to: caret)
        let shifted = caretWithinLine + (newPrefixLength - oldPrefixLength)
        let clamped = min(max(shifted, 0), newLine.count)
        return (newText, lineStartOffset + clamped)
    }

    // MARK: - Marker conversion

    /// When the caret sits right after a lone leading `*`, converts it to a
    /// bullet glyph appropriate for the nesting level and appends the space the
    /// user just typed.
    ///
    /// - Returns: `nil` when the line isn't `<indent>*`, so the caller lets the
    ///   editor insert a normal space.
    static func convertMarkerBeforeSpace(in text: String, caret: String.Index) -> (text: String, caretOffset: Int)? {
        let (lineStart, _) = lineBounds(in: text, around: caret)
        let typed = text[lineStart..<caret]
        let indent = typed.prefix { $0 == " " || $0 == "\t" }
        guard String(typed[indent.endIndex...]) == "*" else { return nil }

        let level = indent.count / indentUnit.count
        let glyph = level <= 0 ? circleBullet : whiteCircle

        let starStart = text.index(before: caret)
        var newText = text
        newText.replaceSubrange(starStart..<caret, with: glyph + " ")
        // Replaced one character ("*") with two (glyph + space).
        let caretOffset = text.distance(from: text.startIndex, to: caret) + 1
        return (newText, caretOffset)
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

        /// Number of leading characters (indent + marker + space).
        var prefixLength: Int {
            indent.count + markerText.count + 1
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
        var nextMarker: String {
            switch family {
            case .dash:
                return "-"
            case .circle:
                return marker(atLevel: indent.count / indentUnit.count)
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
