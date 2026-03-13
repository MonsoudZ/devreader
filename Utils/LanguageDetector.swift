import Foundation

/// Heuristic programming language detection from code text.
/// Scores text against keyword patterns for each language and returns the best match.
nonisolated enum LanguageDetector {

    // MARK: - Public API

    /// Detect the most likely programming language of the given source text.
    /// Returns `.python` when no clear winner is found.
    static func detect(_ text: String) -> CodeLang {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return .python
        }

        // Fast-path: check shebang on the first line
        if let shebangResult = detectFromShebang(text) {
            return shebangResult
        }

        // Score every language and pick the highest
        var bestLang: CodeLang = .python
        var bestScore = 0

        for (lang, patterns) in languagePatterns {
            var score = 0
            for pattern in patterns {
                score += occurrences(of: pattern, in: text)
            }
            if score > bestScore {
                bestScore = score
                bestLang = lang
            }
        }

        return bestLang
    }

    // MARK: - Shebang Detection

    private static func detectFromShebang(_ text: String) -> CodeLang? {
        let firstLine: String
        if let newlineIndex = text.firstIndex(of: "\n") {
            firstLine = String(text[text.startIndex..<newlineIndex])
        } else {
            firstLine = text
        }

        guard firstLine.hasPrefix("#!") else { return nil }

        let lower = firstLine.lowercased()
        if lower.contains("python") { return .python }
        if lower.contains("ruby") { return .ruby }
        if lower.contains("node") { return .node }
        if lower.contains("swift") { return .swift }
        if lower.contains("bash") || lower.contains("/sh") { return .bash }
        if lower.contains("perl") { return nil } // unsupported, fall through to scoring
        return nil
    }

    // MARK: - Pattern Definitions

    private static let languagePatterns: [CodeLang: [String]] = [
        .python: [
            "def ", "import ", "print(", "class ", "elif",
            "self.", "__init__", "from ", "lambda ", "except:",
        ],
        .swift: [
            "func ", "let ", "var ", "guard", "@",
            "protocol ", "struct ", "import Foundation",
            "import SwiftUI", "import UIKit",
        ],
        .javascript: [
            "const ", "=>", "console.", "function ",
            "require(", "export ", "document.", "window.",
        ],
        .typescript: [
            "const ", "=>", "console.", "function ",
            "export ", ": string", ": number", ": boolean",
            "interface ", "type ", "import {",
        ],
        .java: [
            "public class", "System.out", "void main",
            "import java", "private ", "protected ",
            "throws ", "new ", "@Override",
        ],
        .c: [
            "#include", "printf(", "int main",
            "stdio.h", "stdlib.h", "sizeof(",
            "malloc(", "NULL",
        ],
        .cpp: [
            "#include", "printf(", "int main",
            "std::", "iostream", "cout",
            "cin", "namespace ", "template<",
        ],
        .rust: [
            "fn main", "let mut", "println!",
            "impl ", "pub fn", "use std",
            "match ", "-> ", "&self",
        ],
        .go: [
            "package main", "fmt.", "func main",
            "import \"fmt\"", "func (", ":= ",
            "go func", "chan ", "defer ",
        ],
        .ruby: [
            "puts ", "def ", "end",
            "require '", "attr_", "class ",
            "do |", ".each", "nil",
        ],
        .bash: [
            "#!/bin/bash", "echo ", "if [",
            "fi", "done", "esac",
            "then", "elif ", "$(",
        ],
        .sql: [
            "SELECT", "FROM", "WHERE",
            "INSERT", "CREATE TABLE", "ALTER TABLE",
            "DROP ", "JOIN ", "GROUP BY",
        ],
        .kotlin: [
            "fun ", "val ", "var ",
            "println(", "class ", "import kotlin",
            "when ", "companion object", "override fun",
        ],
        .dart: [
            "void main", "print(", "Widget ",
            "import 'package:", "class ", "@override",
            "setState(", "final ", "const ",
        ],
    ]

    // MARK: - Helpers

    /// Count non-overlapping occurrences of `needle` in `haystack`.
    private static func occurrences(of needle: String, in haystack: String) -> Int {
        var count = 0
        var searchRange = haystack.startIndex..<haystack.endIndex
        while let range = haystack.range(of: needle, range: searchRange) {
            count += 1
            searchRange = range.upperBound..<haystack.endIndex
        }
        return count
    }
}
