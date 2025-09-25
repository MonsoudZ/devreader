import XCTest
@testable import DevReader

final class FileManagementTests: XCTestCase {
    
    override func tearDownWithError() throws {
        // Clean up test files
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let testPath = documentsPath.appendingPathComponent("DevReader/CodeFiles")
        
        if FileManager.default.fileExists(atPath: testPath.path) {
            try? FileManager.default.removeItem(at: testPath)
        }
    }
    
    // MARK: - File Save Tests
    
    func testSaveFileWithCorrectExtension() {
        let testCode = "print('Hello World')"
        let language = CodeLang.python
        let fileName = "test_file.py"
        
        // Create a temporary file to test saving
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileName)
        
        do {
            try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Verify file was created with correct extension
            XCTAssertTrue(FileManager.default.fileExists(atPath: tempFile.path), "File should be created")
            XCTAssertEqual(tempFile.pathExtension, language.fileExtension, "File should have correct extension")
            
            // Verify content
            let content = try String(contentsOf: tempFile, encoding: .utf8)
            XCTAssertEqual(content, testCode, "File content should match saved code")
            
            // Clean up
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("File save test failed: \(error)")
        }
    }
    
    func testSaveMultipleLanguageFiles() {
        let testCases: [(CodeLang, String, String)] = [
            (.python, "print('Hello')", "test.py"),
            (.ruby, "puts 'Hello'", "test.rb"),
            (.javascript, "console.log('Hello')", "test.js"),
            (.swift, "print(\"Hello\")", "test.swift"),
            (.c, "#include <stdio.h>\nint main() { printf(\"Hello\"); return 0; }", "test.c"),
            (.cpp, "#include <iostream>\nint main() { std::cout << \"Hello\"; return 0; }", "test.cpp"),
            (.rust, "fn main() { println!(\"Hello\"); }", "test.rs"),
            (.java, "public class Main { public static void main(String[] args) { System.out.println(\"Hello\"); } }", "test.java"),
            (.go, "package main\nimport \"fmt\"\nfunc main() { fmt.Println(\"Hello\") }", "test.go"),
            (.bash, "echo 'Hello'", "test.sh"),
            (.sql, "SELECT 'Hello' as message;", "test.sql")
        ]
        
        for (language, code, fileName) in testCases {
            let tempDir = FileManager.default.temporaryDirectory
            let tempFile = tempDir.appendingPathComponent(fileName)
            
            do {
                try code.write(to: tempFile, atomically: true, encoding: .utf8)
                
                // Verify file extension
                XCTAssertEqual(tempFile.pathExtension, language.fileExtension, 
                              "\(language.rawValue) should have correct extension")
                
                // Verify content
                let content = try String(contentsOf: tempFile, encoding: .utf8)
                XCTAssertEqual(content, code, "\(language.rawValue) content should match")
                
                // Clean up
                try FileManager.default.removeItem(at: tempFile)
            } catch {
                XCTFail("File save test failed for \(language.rawValue): \(error)")
            }
        }
    }
    
    // MARK: - File Load Tests
    
    func testLoadFileWithLanguageDetection() {
        let testCode = "print('Hello World')"
        let fileName = "test_detection.py"
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileName)
        
        do {
            try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Test language detection
            let ext = tempFile.pathExtension.lowercased()
            let detectedLanguage = CodeLang.allCases.first { $0.fileExtension == ext }
            
            XCTAssertNotNil(detectedLanguage, "Should detect language from file extension")
            XCTAssertEqual(detectedLanguage, .python, "Should detect Python from .py extension")
            
            // Clean up
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("File load test failed: \(error)")
        }
    }
    
    func testLoadFileContent() {
        let testCode = "def hello():\n    print('Hello World')\n    return True"
        let fileName = "test_content.py"
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileName)
        
        do {
            try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Load content
            let loadedContent = try String(contentsOf: tempFile, encoding: .utf8)
            XCTAssertEqual(loadedContent, testCode, "Loaded content should match original")
            
            // Clean up
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("File load test failed: \(error)")
        }
    }
    
    // MARK: - Export Tests
    
    func testVSCodeProjectExport() {
        let testCode = "print('Hello from VSCode!')"
        let fileName = "test_vscode.py"
        let projectName = "test-project"
        
        let tempDir = FileManager.default.temporaryDirectory
        let projectPath = tempDir.appendingPathComponent(projectName)
        
        do {
            // Create project directory
            try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)
            
            // Create source file
            let sourceFile = projectPath.appendingPathComponent(fileName)
            try testCode.write(to: sourceFile, atomically: true, encoding: .utf8)
            
            // Create VSCode settings
            let settingsPath = projectPath.appendingPathComponent(".vscode")
            try FileManager.default.createDirectory(at: settingsPath, withIntermediateDirectories: true)
            
            let settings = """
            {
                "files.associations": {
                    "*.py": "python"
                }
            }
            """
            
            try settings.write(to: settingsPath.appendingPathComponent("settings.json"), 
                             atomically: true, encoding: .utf8)
            
            // Verify project structure
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path), "Source file should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: settingsPath.path), "Settings directory should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: settingsPath.appendingPathComponent("settings.json").path), 
                         "Settings file should exist")
            
            // Clean up
            try FileManager.default.removeItem(at: projectPath)
        } catch {
            XCTFail("VSCode export test failed: \(error)")
        }
    }
    
    func testVimConfigurationExport() {
        let testCode = "print('Hello from Vim!')"
        let fileName = "test_vim.py"
        
        let vimConfig = """
        " DevReader Export - \(fileName)
        set syntax=python
        set number
        set autoindent
        set smartindent
        
        " Code content:
        \(testCode)
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let vimFile = tempDir.appendingPathComponent("\(fileName).vim")
        
        do {
            try vimConfig.write(to: vimFile, atomically: true, encoding: .utf8)
            
            // Verify vim configuration
            let content = try String(contentsOf: vimFile, encoding: .utf8)
            XCTAssertTrue(content.contains("set syntax=python"), "Should contain Python syntax setting")
            XCTAssertTrue(content.contains("set number"), "Should contain number setting")
            XCTAssertTrue(content.contains(testCode), "Should contain original code")
            
            // Clean up
            try FileManager.default.removeItem(at: vimFile)
        } catch {
            XCTFail("Vim export test failed: \(error)")
        }
    }
    
    func testEmacsConfigurationExport() {
        let testCode = "print('Hello from Emacs!')"
        let fileName = "test_emacs.py"
        
        let emacsConfig = """
        ;; DevReader Export - \(fileName)
        ;; -*- mode: python -*-
        
        \(testCode)
        """
        
        let tempDir = FileManager.default.temporaryDirectory
        let emacsFile = tempDir.appendingPathComponent("\(fileName).el")
        
        do {
            try emacsConfig.write(to: emacsFile, atomically: true, encoding: .utf8)
            
            // Verify emacs configuration
            let content = try String(contentsOf: emacsFile, encoding: .utf8)
            XCTAssertTrue(content.contains(";; -*- mode: python -*-"), "Should contain Python mode setting")
            XCTAssertTrue(content.contains(testCode), "Should contain original code")
            
            // Clean up
            try FileManager.default.removeItem(at: emacsFile)
        } catch {
            XCTFail("Emacs export test failed: \(error)")
        }
    }
    
    func testJetBrainsProjectExport() {
        let testCode = "print('Hello from JetBrains!')"
        let fileName = "test_jetbrains.py"
        let projectName = "test-jetbrains-project"
        
        let tempDir = FileManager.default.temporaryDirectory
        let projectPath = tempDir.appendingPathComponent(projectName)
        
        do {
            // Create project directory
            try FileManager.default.createDirectory(at: projectPath, withIntermediateDirectories: true)
            
            // Create source file
            let sourceFile = projectPath.appendingPathComponent(fileName)
            try testCode.write(to: sourceFile, atomically: true, encoding: .utf8)
            
            // Create .idea directory
            let ideaPath = projectPath.appendingPathComponent(".idea")
            try FileManager.default.createDirectory(at: ideaPath, withIntermediateDirectories: true)
            
            // Verify project structure
            XCTAssertTrue(FileManager.default.fileExists(atPath: sourceFile.path), "Source file should exist")
            XCTAssertTrue(FileManager.default.fileExists(atPath: ideaPath.path), "Idea directory should exist")
            
            // Clean up
            try FileManager.default.removeItem(at: projectPath)
        } catch {
            XCTFail("JetBrains export test failed: \(error)")
        }
    }
    
    // MARK: - File Management Tests
    
    func testRecentFilesManagement() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let codeFilesPath = documentsPath.appendingPathComponent("DevReader/CodeFiles")
        
        do {
            // Create directory
            try FileManager.default.createDirectory(at: codeFilesPath, withIntermediateDirectories: true)
            
            // Create test files
            let testFiles = ["test1.py", "test2.rb", "test3.js"]
            for fileName in testFiles {
                let filePath = codeFilesPath.appendingPathComponent(fileName)
                try "Test content for \(fileName)".write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // List files
            let files = try FileManager.default.contentsOfDirectory(at: codeFilesPath, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension != "" }
            
            XCTAssertEqual(files.count, 3, "Should have 3 test files")
            
            // Verify file names
            let fileNames = files.map { $0.lastPathComponent }.sorted()
            XCTAssertEqual(fileNames, ["test1.py", "test2.rb", "test3.js"], "Should have correct file names")
            
            // Clean up
            try FileManager.default.removeItem(at: codeFilesPath)
        } catch {
            XCTFail("Recent files management test failed: \(error)")
        }
    }
    
    func testFileDeletion() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let codeFilesPath = documentsPath.appendingPathComponent("DevReader/CodeFiles")
        
        do {
            // Create directory and test file
            try FileManager.default.createDirectory(at: codeFilesPath, withIntermediateDirectories: true)
            let testFile = codeFilesPath.appendingPathComponent("test_delete.py")
            try "Test content".write(to: testFile, atomically: true, encoding: .utf8)
            
            // Verify file exists
            XCTAssertTrue(FileManager.default.fileExists(atPath: testFile.path), "Test file should exist")
            
            // Delete file
            try FileManager.default.removeItem(at: testFile)
            
            // Verify file is deleted
            XCTAssertFalse(FileManager.default.fileExists(atPath: testFile.path), "Test file should be deleted")
            
            // Clean up
            try FileManager.default.removeItem(at: codeFilesPath)
        } catch {
            XCTFail("File deletion test failed: \(error)")
        }
    }
    
    // MARK: - Performance Tests
    
    func testFileOperationsPerformance() {
        let testCode = String(repeating: "print('Performance test line')\n", count: 100)
        let fileName = "performance_test.py"
        
        let tempDir = FileManager.default.temporaryDirectory
        let tempFile = tempDir.appendingPathComponent(fileName)
        
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Test save performance
            try testCode.write(to: tempFile, atomically: true, encoding: .utf8)
            
            // Test load performance
            let _ = try String(contentsOf: tempFile, encoding: .utf8)
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertLessThan(timeElapsed, 1.0, "File operations should complete within 1 second")
            
            // Clean up
            try FileManager.default.removeItem(at: tempFile)
        } catch {
            XCTFail("File operations performance test failed: \(error)")
        }
    }
    
    func testMultipleFileOperations() {
        let testCode = "print('Multiple file test')"
        let fileCount = 50
        
        let tempDir = FileManager.default.temporaryDirectory
        let startTime = CFAbsoluteTimeGetCurrent()
        
        do {
            // Create multiple files
            for i in 0..<fileCount {
                let fileName = "test_\(i).py"
                let filePath = tempDir.appendingPathComponent(fileName)
                try testCode.write(to: filePath, atomically: true, encoding: .utf8)
            }
            
            // List and verify files
            let files = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: nil)
                .filter { $0.lastPathComponent.hasPrefix("test_") && $0.pathExtension == "py" }
            
            XCTAssertEqual(files.count, fileCount, "Should have \(fileCount) test files")
            
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            XCTAssertLessThan(timeElapsed, 3.0, "Multiple file operations should complete within 3 seconds")
            
            // Clean up
            for file in files {
                try FileManager.default.removeItem(at: file)
            }
        } catch {
            XCTFail("Multiple file operations test failed: \(error)")
        }
    }
}
