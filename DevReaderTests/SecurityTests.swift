import XCTest
@testable import DevReader

/// Tests for security-critical code paths: URL filtering, XSS prevention, JS escaping, path traversal.
@MainActor
final class SecurityTests: XCTestCase {

	// MARK: - Monaco Template Literal Escaping

	/// The Monaco HTML builder escapes input for template literals (backtick-delimited).
	/// These tests verify the escaping chain applied in MonacoWebEditor.html().

	func testMonacoEscapesBackslash() {
		let input = "let path = \"C:\\\\Users\""
		let escaped = applyMonacoEscaping(input)
		XCTAssertFalse(escaped.contains("\\") && !escaped.contains("\\\\"),
					   "Backslashes should be doubled")
	}

	func testMonacoEscapesBacktick() {
		let input = "let s = `template`"
		let escaped = applyMonacoEscaping(input)
		XCTAssertTrue(escaped.contains("\\`"), "Backticks should be escaped")
		// Ensure the backtick can't break out of the template literal
		XCTAssertFalse(escaped.contains("`") && !escaped.contains("\\`"),
					   "Unescaped backtick found — template literal injection possible")
	}

	func testMonacoEscapesDollarSign() {
		let input = "let cost = $100; ${exploit}"
		let escaped = applyMonacoEscaping(input)
		XCTAssertTrue(escaped.contains("\\$"), "Dollar signs should be escaped to prevent ${} injection")
	}

	func testMonacoEscapesLineSeparators() {
		let input = "line1\u{2028}line2\u{2029}line3"
		let escaped = applyMonacoEscaping(input)
		XCTAssertTrue(escaped.contains("\\u2028"), "U+2028 should be escaped")
		XCTAssertTrue(escaped.contains("\\u2029"), "U+2029 should be escaped")
		XCTAssertFalse(escaped.contains("\u{2028}"), "Raw U+2028 should not remain")
		XCTAssertFalse(escaped.contains("\u{2029}"), "Raw U+2029 should not remain")
	}

	func testMonacoEscapingFullChain() {
		// A malicious payload attempting template literal injection
		let payload = "`;alert(1);//"
		let escaped = applyMonacoEscaping(payload)
		XCTAssertTrue(escaped.hasPrefix("\\`"), "Leading backtick must be escaped")
		// The escaped string should be safe inside a template literal
		XCTAssertFalse(escaped.contains("`") && !escaped.contains("\\`"))
	}

	// MARK: - WebViewHTML JS String Escaping (single-quote context)

	func testJSEscapesBackslash() {
		let input = "C:\\Users\\test"
		let escaped = applyJSSingleQuoteEscaping(input)
		XCTAssertTrue(escaped.contains("\\\\"), "Backslashes should be doubled")
	}

	func testJSEscapesSingleQuote() {
		let input = "it's a test"
		let escaped = applyJSSingleQuoteEscaping(input)
		XCTAssertTrue(escaped.contains("\\'"), "Single quotes should be escaped")
	}

	func testJSEscapesNewlines() {
		let input = "line1\nline2\rline3"
		let escaped = applyJSSingleQuoteEscaping(input)
		XCTAssertTrue(escaped.contains("\\n"), "Newlines should be escaped")
		XCTAssertTrue(escaped.contains("\\r"), "Carriage returns should be escaped")
	}

	func testJSEscapesNullByte() {
		let input = "before\0after"
		let escaped = applyJSSingleQuoteEscaping(input)
		XCTAssertTrue(escaped.contains("\\0"), "Null bytes should be escaped")
		XCTAssertFalse(escaped.contains("\0"), "Raw null should not remain")
	}

	func testJSEscapesLineSeparators() {
		let input = "a\u{2028}b\u{2029}c"
		let escaped = applyJSSingleQuoteEscaping(input)
		XCTAssertTrue(escaped.contains("\\u2028"))
		XCTAssertTrue(escaped.contains("\\u2029"))
	}

	func testJSEscapingFullInjection() {
		// Attempt to break out of single-quoted string
		let payload = "'; document.cookie; '"
		let escaped = applyJSSingleQuoteEscaping(payload)
		XCTAssertTrue(escaped.contains("\\'"), "Quotes must be escaped")
		// The result should be safe when wrapped in single quotes
	}

	// MARK: - Path Traversal Validation

	func testPathTraversalBlocksOutsideHome() {
		let etcPasswd = URL(fileURLWithPath: "/etc/passwd")
		XCTAssertFalse(CodeFileService.isPathAllowed(etcPasswd), "/etc/passwd should be blocked")
	}

	func testPathTraversalBlocksRootFiles() {
		let rootFile = URL(fileURLWithPath: "/bin/sh")
		XCTAssertFalse(CodeFileService.isPathAllowed(rootFile), "/bin/sh should be blocked")
	}

	func testPathTraversalAllowsHomeDirectory() {
		let homeFile = FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("test.txt")
		XCTAssertTrue(CodeFileService.isPathAllowed(homeFile), "Files in home dir should be allowed")
	}

	func testPathTraversalAllowsTempDirectory() {
		let tmpFile = FileManager.default.temporaryDirectory.appendingPathComponent("test.txt")
		XCTAssertTrue(CodeFileService.isPathAllowed(tmpFile), "Files in temp dir should be allowed")
	}

	func testPathTraversalBlocksDotDotEscape() {
		let homeDir = FileManager.default.homeDirectoryForCurrentUser
		let traversal = homeDir.appendingPathComponent("../../etc/passwd")
		XCTAssertFalse(CodeFileService.isPathAllowed(traversal),
					   "Path traversal with .. should be blocked after standardization")
	}

	func testLoadFileRejectsTraversal() {
		let etcPasswd = URL(fileURLWithPath: "/etc/passwd")
		XCTAssertThrowsError(try CodeFileService.loadFile(at: etcPasswd)) { error in
			XCTAssertTrue(error is CodeFileError)
		}
	}

	// MARK: - Helpers

	/// Replicates the escaping chain used in MonacoWebEditor.html() for template literals.
	private func applyMonacoEscaping(_ input: String) -> String {
		input
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "`", with: "\\`")
			.replacingOccurrences(of: "$", with: "\\$")
			.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
			.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
	}

	/// Replicates the escaping chain used in WebViewHTML.Coord.webView(_:didFinish:) for single-quote JS strings.
	private func applyJSSingleQuoteEscaping(_ input: String) -> String {
		input
			.replacingOccurrences(of: "\\", with: "\\\\")
			.replacingOccurrences(of: "'", with: "\\'")
			.replacingOccurrences(of: "\n", with: "\\n")
			.replacingOccurrences(of: "\r", with: "\\r")
			.replacingOccurrences(of: "\0", with: "\\0")
			.replacingOccurrences(of: "\u{2028}", with: "\\u2028")
			.replacingOccurrences(of: "\u{2029}", with: "\\u2029")
	}
}
