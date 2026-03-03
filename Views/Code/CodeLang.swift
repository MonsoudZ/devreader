import Foundation

nonisolated enum CodeLang: String, CaseIterable, Sendable {
	case python = "Python"
	case ruby = "Ruby"
	case node = "Node.js"
	case swift = "Swift"
	case javascript = "JavaScript"
	case bash = "Bash"
	case go = "Go"
	case c = "C"
	case cpp = "C++"
	case rust = "Rust"
	case java = "Java"
	case typescript = "TypeScript"
	case kotlin = "Kotlin"
	case dart = "Dart"
	case sql = "SQL"

	var command: String {
		switch self {
		case .python: return "python3"
		case .ruby: return "ruby"
		case .node: return "node"
		case .swift: return "swift"
		case .javascript: return "node"
		case .bash: return "bash"
		case .go: return "go"
		case .c: return "gcc"
		case .cpp: return "g++"
		case .rust: return "rustc"
		case .java: return "javac"
		case .typescript: return "npx"
		case .kotlin: return "kotlinc"
		case .dart: return "dart"
		case .sql: return "sqlite3"
		}
	}

	var args: [String] {
		switch self {
		case .python: return ["-c"]
		case .ruby: return ["-e"]
		case .node: return ["-e"]
		case .swift: return ["-"]
		case .javascript: return ["-e"]
		case .bash: return ["-c"]
		case .go: return ["run", "-"]
		case .c: return ["-o", "temp_c", "-"]
		case .cpp: return ["-o", "temp_cpp", "-"]
		case .rust: return ["-o", "temp_rust", "-"]
		case .java: return ["-"]
		case .typescript: return ["tsx"]
		case .kotlin: return ["-script"]
		case .dart: return ["run"]
		case .sql: return ["-"]
		}
	}

	var fileExtension: String {
		switch self {
		case .python: return "py"
		case .ruby: return "rb"
		case .node: return "js"
		case .swift: return "swift"
		case .javascript: return "js"
		case .bash: return "sh"
		case .go: return "go"
		case .c: return "c"
		case .cpp: return "cpp"
		case .rust: return "rs"
		case .java: return "java"
		case .typescript: return "ts"
		case .kotlin: return "kt"
		case .dart: return "dart"
		case .sql: return "sql"
		}
	}

	var monacoLanguage: String {
		switch self {
		case .python: return "python"
		case .ruby: return "ruby"
		case .node, .javascript: return "javascript"
		case .swift: return "swift"
		case .bash: return "shell"
		case .go: return "go"
		case .c: return "c"
		case .cpp: return "cpp"
		case .rust: return "rust"
		case .java: return "java"
		case .typescript: return "typescript"
		case .kotlin: return "kotlin"
		case .dart: return "dart"
		case .sql: return "sql"
		}
	}

	var vimSyntax: String {
		switch self {
		case .bash: return "sh"
		default: return monacoLanguage
		}
	}

	var emacsMode: String {
		switch self {
		case .bash: return "sh"
		case .cpp: return "c++"
		default: return monacoLanguage
		}
	}

	/// Look up a CodeLang from a lowercased language name string (e.g., "python3", "node.js")
	static func fromName(_ name: String) -> CodeLang? {
		switch name.lowercased() {
		case "python", "python3": return .python
		case "ruby": return .ruby
		case "node", "node.js": return .node
		case "javascript": return .javascript
		case "swift": return .swift
		case "bash", "sh": return .bash
		case "go": return .go
		case "c": return .c
		case "c++", "cpp": return .cpp
		case "rust": return .rust
		case "java": return .java
		case "typescript": return .typescript
		case "kotlin": return .kotlin
		case "dart": return .dart
		case "sql": return .sql
		default: return nil
		}
	}
}
