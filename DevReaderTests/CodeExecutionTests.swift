import XCTest
@testable import DevReader

final class CodeExecutionTests: XCTestCase {
    
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
    
    func testPythonExecution() {
        let pythonCode = "print('Hello from Python!')"
        let result = Shell.runCode("Python", code: pythonCode)
        
        XCTAssertTrue(result.contains("Hello from Python!"), "Python code should execute successfully")
        XCTAssertFalse(result.contains("error"), "Python execution should not contain errors")
    }
    
    func testRubyExecution() {
        let rubyCode = "puts 'Hello from Ruby!'"
        let result = Shell.runCode("Ruby", code: rubyCode)
        
        XCTAssertTrue(result.contains("Hello from Ruby!"), "Ruby code should execute successfully")
    }
    
    func testJavaScriptExecution() {
        let jsCode = "console.log('Hello from JavaScript!')"
        let result = Shell.runCode("JavaScript", code: jsCode)
        
        XCTAssertTrue(result.contains("Hello from JavaScript!"), "JavaScript code should execute successfully")
    }
    
    func testBashExecution() {
        let bashCode = "echo 'Hello from Bash!'"
        let result = Shell.runCode("Bash", code: bashCode)
        
        XCTAssertTrue(result.contains("Hello from Bash!"), "Bash code should execute successfully")
    }
    
    func testCExecution() {
        let cCode = """
        #include <stdio.h>
        int main() {
            printf("Hello from C!\\n");
            return 0;
        }
        """
        let result = Shell.runCode("C", code: cCode)
        
        XCTAssertTrue(result.contains("Hello from C!"), "C code should compile and execute successfully")
    }
    
    func testCppExecution() {
        let cppCode = """
        #include <iostream>
        int main() {
            std::cout << "Hello from C++!" << std::endl;
            return 0;
        }
        """
        let result = Shell.runCode("C++", code: cppCode)
        
        XCTAssertTrue(result.contains("Hello from C++!"), "C++ code should compile and execute successfully")
    }
    
    func testRustExecution() {
        let rustCode = """
        fn main() {
            println!("Hello from Rust!");
        }
        """
        let result = Shell.runCode("Rust", code: rustCode)
        
        XCTAssertTrue(result.contains("Hello from Rust!"), "Rust code should compile and execute successfully")
    }
    
    func testJavaExecution() {
        let javaCode = """
        public class Main {
            public static void main(String[] args) {
                System.out.println("Hello from Java!");
            }
        }
        """
        let result = Shell.runCode("Java", code: javaCode)
        
        XCTAssertTrue(result.contains("Hello from Java!"), "Java code should compile and execute successfully")
    }
    
    func testGoExecution() {
        let goCode = """
        package main
        import "fmt"
        func main() {
            fmt.Println("Hello from Go!")
        }
        """
        let result = Shell.runCode("Go", code: goCode)
        
        XCTAssertTrue(result.contains("Hello from Go!"), "Go code should execute successfully")
    }
    
    func testSwiftExecution() {
        let swiftCode = "print(\"Hello from Swift!\")"
        let result = Shell.runCode("Swift", code: swiftCode)
        
        XCTAssertTrue(result.contains("Hello from Swift!"), "Swift code should execute successfully")
    }
    
    func testSQLExecution() {
        let sqlCode = "SELECT 'Hello from SQL!' as message;"
        let result = Shell.runCode("SQL", code: sqlCode)
        
        XCTAssertTrue(result.contains("Hello from SQL!"), "SQL code should execute successfully")
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
    
    func testCodeExecutionPerformance() {
        let pythonCode = """
        for i in range(1000):
            print(f"Line {i}")
        """
        
        let startTime = CFAbsoluteTimeGetCurrent()
        let result = Shell.runCode("Python", code: pythonCode)
        let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
        
        XCTAssertLessThan(timeElapsed, 5.0, "Code execution should complete within 5 seconds")
        XCTAssertTrue(result.contains("Line 999"), "Performance test should complete successfully")
    }
    
    func testConcurrentCodeExecution() {
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
