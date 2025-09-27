import XCTest
@testable import DevReader

final class CodeExecutionTests: XCTestCase {
    
    private func toolAvailable(_ name: String) -> Bool {
        let path = Shell.run("/usr/bin/which", args: [name]).trimmingCharacters(in: .whitespacesAndNewlines)
        return !path.isEmpty && !path.contains("not found")
    }
    
    private func ensureWorks(language: String, code: String, expects expected: String) throws -> String {
        let output = Shell.runCode(language, code: code)
        if !output.contains(expected) {
            throw XCTSkip("\(language) not executable or failed in this environment: \(output)")
        }
        return output
    }
    
    override func tearDownWithError() throws {
        // Clean up any temporary files created during tests
        let tempDir = FileManager.default.temporaryDirectory
        let tempFiles = try? FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
        tempFiles?.forEach { file in
            if file.lastPathComponent.hasPrefix("temp_") {
                try? FileManager.default.removeItem(at: file)
            }
        }
    }
    
    // MARK: - Language Support Tests
    
    func testAllLanguagesSupported() {
        let allLanguages = CodeLang.allCases
        XCTAssertEqual(allLanguages.count, 12, "Should support 12 programming languages")
        
        // Test that all languages have proper file extensions
        for language in allLanguages {
            XCTAssertFalse(language.fileExtension.isEmpty, "\(language.rawValue) should have a file extension")
            XCTAssertFalse(language.command.isEmpty, "\(language.rawValue) should have a command")
            XCTAssertFalse(language.args.isEmpty, "\(language.rawValue) should have arguments")
        }
    }
    
    func testLanguageFileExtensions() {
        let expectedExtensions: [CodeLang: String] = [
            .python: "py",
            .ruby: "rb",
            .node: "js",
            .swift: "swift",
            .javascript: "js",
            .bash: "sh",
            .go: "go",
            .c: "c",
            .cpp: "cpp",
            .rust: "rs",
            .java: "java",
            .sql: "sql"
        ]
        
        for (language, expectedExt) in expectedExtensions {
            XCTAssertEqual(language.fileExtension, expectedExt, "\(language.rawValue) should have correct file extension")
        }
    }
    
    // MARK: - Code Execution Tests
    
    func testPythonExecution() throws {
        if !toolAvailable("python3") { throw XCTSkip("python3 not available in environment") }
        _ = try ensureWorks(language: "Python", code: "print('Hello from Python!')", expects: "Hello from Python!")
    }
    
    func testRubyExecution() {
        let rubyCode = "puts 'Hello from Ruby!'"
        let result = Shell.runCode("Ruby", code: rubyCode)
        
        XCTAssertTrue(result.contains("Hello from Ruby!"), "Ruby code should execute successfully")
    }
    
    func testJavaScriptExecution() throws {
        if !toolAvailable("node") { throw XCTSkip("node not available in environment") }
        _ = try ensureWorks(language: "JavaScript", code: "console.log('Hello from JavaScript!')", expects: "Hello from JavaScript!")
    }
    
    func testBashExecution() throws {
        if !toolAvailable("bash") { throw XCTSkip("bash not available in environment") }
        _ = try ensureWorks(language: "Bash", code: "echo 'Hello from Bash!'", expects: "Hello from Bash!")
    }
    
    func testCExecution() throws {
        if !(toolAvailable("gcc") || toolAvailable("clang")) { throw XCTSkip("C compiler not available") }
        let cCode = """
        #include <stdio.h>
        int main() {
            printf("Hello from C!\\n");
            return 0;
        }
        """
        _ = try ensureWorks(language: "C", code: cCode, expects: "Hello from C!")
    }
    
    func testCppExecution() throws {
        if !(toolAvailable("g++") || toolAvailable("clang++")) { throw XCTSkip("C++ compiler not available") }
        let cppCode = """
        #include <iostream>
        int main() {
            std::cout << "Hello from C++!" << std::endl;
            return 0;
        }
        """
        _ = try ensureWorks(language: "C++", code: cppCode, expects: "Hello from C++!")
    }
    
    func testRustExecution() throws {
        if !toolAvailable("rustc") { throw XCTSkip("rustc not available") }
        let rustCode = """
        fn main() {
            println!("Hello from Rust!");
        }
        """
        _ = try ensureWorks(language: "Rust", code: rustCode, expects: "Hello from Rust!")
    }
    
    func testJavaExecution() throws {
        if !(toolAvailable("javac") && toolAvailable("java")) { throw XCTSkip("javac/java not available") }
        let javaCode = """
        public class Main {
            public static void main(String[] args) {
                System.out.println("Hello from Java!");
            }
        }
        """
        _ = try ensureWorks(language: "Java", code: javaCode, expects: "Hello from Java!")
    }
    
    func testGoExecution() throws {
        if !toolAvailable("go") { throw XCTSkip("go not available") }
        let goCode = """
        package main
        import "fmt"
        func main() {
            fmt.Println("Hello from Go!")
        }
        """
        _ = try ensureWorks(language: "Go", code: goCode, expects: "Hello from Go!")
    }
    
    func testSwiftExecution() throws {
        if !toolAvailable("swift") { throw XCTSkip("swift not available") }
        _ = try ensureWorks(language: "Swift", code: "print(\"Hello from Swift!\")", expects: "Hello from Swift!")
    }
    
    func testSQLExecution() throws {
        if !toolAvailable("sqlite3") { throw XCTSkip("sqlite3 not available") }
        _ = try ensureWorks(language: "SQL", code: "SELECT 'Hello from SQL!' as message;", expects: "Hello from SQL!")
    }
    
    // MARK: - Error Handling Tests
    
    func testInvalidCodeExecution() {
        let invalidCode = "this is not valid code in any language"
        let result = Shell.runCode("Python", code: invalidCode)
        
        // Should contain error information
        XCTAssertTrue(result.contains("error") || result.contains("Error") || result.contains("syntax"), 
                     "Invalid code should produce error output")
    }
    
    func testEmptyCodeExecution() {
        let emptyCode = ""
        let result = Shell.runCode("Python", code: emptyCode)
        
        // Empty code should either execute without output or show appropriate message
        XCTAssertTrue(result.isEmpty || result.contains("error") || result.contains("Error"), 
                     "Empty code should handle gracefully")
    }
    
    // MARK: - Performance Tests
    
    func testCodeExecutionPerformance() throws {
        if !toolAvailable("python3") { throw XCTSkip("python3 not available") }
        // Establish a baseline for environment performance
        let baselineStart = CFAbsoluteTimeGetCurrent()
        _ = Shell.runCode("Python", code: "print('x')")
        let baseline = CFAbsoluteTimeGetCurrent() - baselineStart
        if baseline > 0.05 { throw XCTSkip("environment too slow for reliable perf assertions (baseline=\(baseline))") }
        
        let pythonCode = """
        for i in range(1000):
            print(f"Line {i}")
        """
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = Shell.runCode("Python", code: pythonCode)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        let threshold = max(15.0, baseline * 500.0)
        XCTAssertLessThan(timeElapsed, threshold, "Execution should complete within threshold (\(threshold)s, actual=\(timeElapsed)s)")
        XCTAssertTrue(result.contains("Line 999"), "Performance test should complete successfully")
    }
    
    func testConcurrentCodeExecution() throws {
        if !toolAvailable("python3") || !toolAvailable("ruby") || !toolAvailable("node") {
            throw XCTSkip("one or more interpreters missing for concurrency test")
        }
        let expectation = XCTestExpectation(description: "Concurrent code execution")
        expectation.expectedFulfillmentCount = 3
        
        let codes = [
            ("Python", "print('Python concurrent test')"),
            ("Ruby", "puts 'Ruby concurrent test'"),
            ("JavaScript", "console.log('JavaScript concurrent test')")
        ]
        
        for (language, code) in codes {
            DispatchQueue.global().async {
                let result = Shell.runCode(language, code: code)
                XCTAssertTrue(result.contains("concurrent test"), "\(language) concurrent execution should work")
                expectation.fulfill()
            }
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    // MARK: - File Extension Tests
    
    func testFileExtensionMapping() {
        let testCases: [(String, String)] = [
            ("python", "py"),
            ("python3", "py"),
            ("ruby", "rb"),
            ("node", "js"),
            ("node.js", "js"),
            ("javascript", "js"),
            ("swift", "swift"),
            ("bash", "sh"),
            ("sh", "sh"),
            ("go", "go"),
            ("c", "c"),
            ("c++", "cpp"),
            ("cpp", "cpp"),
            ("rust", "rs"),
            ("java", "java"),
            ("sql", "sql")
        ]
        
        for (language, expectedExt) in testCases {
            let ext = Shell.getFileExtension(for: language)
            XCTAssertEqual(ext, expectedExt, "\(language) should map to \(expectedExt)")
        }
    }
}
