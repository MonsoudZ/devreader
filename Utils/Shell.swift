import Foundation

nonisolated enum Shell {
    /// Default execution timeout in seconds
    private static let executionTimeout: TimeInterval = 30

    private struct RunResult {
        let output: String
        let exitCode: Int32
    }

    @discardableResult
    static func run(_ cmd: String, args: [String] = [], stdin: String? = nil) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let inPipe = Pipe(); let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe; p.standardInput = inPipe
        do { try p.run() } catch { return "Failed to start: \(error)" }
        if let s = stdin { inPipe.fileHandleForWriting.write(Data(s.utf8)) }
        inPipe.fileHandleForWriting.closeFile()

        // Read pipes asynchronously BEFORE waitUntilExit to prevent deadlock
        // when child output exceeds the ~64 KB pipe buffer.
        var outData = Data()
        var errData = Data()
        let outGroup = DispatchGroup()
        let errGroup = DispatchGroup()

        outGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            outGroup.leave()
        }
        errGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            errGroup.leave()
        }

        // Wait with timeout to prevent infinite hangs
        let waitGroup = DispatchGroup()
        waitGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            p.waitUntilExit()
            waitGroup.leave()
        }
        if waitGroup.wait(timeout: .now() + executionTimeout) == .timedOut {
            p.terminate()
            return "[Execution timed out after \(Int(executionTimeout))s]"
        }

        outGroup.wait()
        errGroup.wait()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        return out + (err.isEmpty ? "" : "\n[stderr]\n" + err)
    }

    private static func runReturningResult(_ cmd: String, args: [String] = [], stdin: String? = nil) -> RunResult {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        let inPipe = Pipe(); let outPipe = Pipe(); let errPipe = Pipe()
        p.standardOutput = outPipe; p.standardError = errPipe; p.standardInput = inPipe
        do { try p.run() } catch { return RunResult(output: "Failed to start: \(error)", exitCode: -1) }
        if let s = stdin { inPipe.fileHandleForWriting.write(Data(s.utf8)) }
        inPipe.fileHandleForWriting.closeFile()

        var outData = Data()
        var errData = Data()
        let outGroup = DispatchGroup()
        let errGroup = DispatchGroup()

        outGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            outGroup.leave()
        }
        errGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            errGroup.leave()
        }

        let waitGroup = DispatchGroup()
        waitGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            p.waitUntilExit()
            waitGroup.leave()
        }
        if waitGroup.wait(timeout: .now() + executionTimeout) == .timedOut {
            p.terminate()
            return RunResult(output: "[Execution timed out after \(Int(executionTimeout))s]", exitCode: -1)
        }

        outGroup.wait()
        errGroup.wait()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        let output = out + (err.isEmpty ? "" : "\n[stderr]\n" + err)
        return RunResult(output: output, exitCode: p.terminationStatus)
    }

    private static func runWithFallbackReturningResult(_ primary: String, fallback: String, args: [String] = [], stdin: String? = nil) -> RunResult {
        if FileManager.default.fileExists(atPath: primary) {
            let result = runReturningResult(primary, args: args, stdin: stdin)
            if result.exitCode != -1 {
                return result
            }
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [fallback] + args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        if let stdin = stdin {
            let inPipe = Pipe()
            process.standardInput = inPipe
            inPipe.fileHandleForWriting.write(stdin.data(using: .utf8) ?? Data())
            inPipe.fileHandleForWriting.closeFile()
        }

        do {
            try process.run()
        } catch {
            return RunResult(output: "Error: \(error.localizedDescription). Please ensure \(fallback) is installed and available in PATH.", exitCode: -1)
        }

        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        let waitGroup = DispatchGroup()
        waitGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            waitGroup.leave()
        }
        if waitGroup.wait(timeout: .now() + executionTimeout) == .timedOut {
            process.terminate()
            return RunResult(output: "[Execution timed out after \(Int(executionTimeout))s]", exitCode: -1)
        }

        group.wait()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        let output = out + (err.isEmpty ? "" : "\n[stderr]\n" + err)
        return RunResult(output: output, exitCode: process.terminationStatus)
    }

    private static func runWithFallback(_ primary: String, fallback: String, args: [String] = [], stdin: String? = nil) -> String {
        // Try primary path first
        if FileManager.default.fileExists(atPath: primary) {
            let result = runReturningResult(primary, args: args, stdin: stdin)
            if result.exitCode != -1 {
                return result.output
            }
        }

        // Fallback to system PATH
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = [fallback] + args

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        if let stdin = stdin {
            let inPipe = Pipe()
            process.standardInput = inPipe
            inPipe.fileHandleForWriting.write(stdin.data(using: .utf8) ?? Data())
            inPipe.fileHandleForWriting.closeFile()
        }

        do {
            try process.run()
        } catch {
            return "Error: \(error.localizedDescription). Please ensure \(fallback) is installed and available in PATH."
        }

        // Read pipes async before waiting
        var outData = Data()
        var errData = Data()
        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }

        let waitGroup = DispatchGroup()
        waitGroup.enter()
        DispatchQueue.global(qos: .utility).async {
            process.waitUntilExit()
            waitGroup.leave()
        }
        if waitGroup.wait(timeout: .now() + executionTimeout) == .timedOut {
            process.terminate()
            return "[Execution timed out after \(Int(executionTimeout))s]"
        }

        group.wait()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        return out + (err.isEmpty ? "" : "\n[stderr]\n" + err)
    }

    @discardableResult
    static func runCode(_ language: String, code: String) -> String {
        // Use a unique temp file name (UUID) to prevent symlink / TOCTOU attacks
        let tempDir = FileManager.default.temporaryDirectory
        let uniqueName = "devreader_\(UUID().uuidString).\(getFileExtension(for: language))"
        let tempFile = tempDir.appendingPathComponent(uniqueName)

        do {
            // Write with restrictive permissions (owner-only read/write)
            try code.write(to: tempFile, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: tempFile.path
            )

            defer {
                // Always clean up temp file
                try? FileManager.default.removeItem(at: tempFile)
            }

            let result: String
            switch language.lowercased() {
            case "python", "python3":
                result = runWithFallback("/usr/bin/python3", fallback: "python3", args: [tempFile.path])
            case "ruby":
                result = runWithFallback("/usr/bin/ruby", fallback: "ruby", args: [tempFile.path])
            case "node", "node.js", "javascript":
                result = runWithFallback("/usr/bin/node", fallback: "node", args: [tempFile.path])
            case "swift":
                result = runWithFallback("/usr/bin/swift", fallback: "swift", args: [tempFile.path])
            case "bash", "sh":
                result = runWithFallback("/bin/bash", fallback: "bash", args: [tempFile.path])
            case "go":
                result = runWithFallback("/usr/local/go/bin/go", fallback: "go", args: ["run", tempFile.path])
            case "c":
                result = compileAndRunC(tempFile: tempFile)
            case "c++", "cpp":
                result = compileAndRunCpp(tempFile: tempFile)
            case "rust":
                result = compileAndRunRust(tempFile: tempFile)
            case "java":
                result = compileAndRunJava(tempFile: tempFile)
            case "typescript":
                result = runWithFallback("/usr/local/bin/npx", fallback: "npx", args: ["tsx", tempFile.path])
            case "kotlin":
                result = runWithFallback("/usr/local/bin/kotlinc", fallback: "kotlinc", args: ["-script", tempFile.path])
            case "dart":
                result = runWithFallback("/usr/local/bin/dart", fallback: "dart", args: ["run", tempFile.path])
            case "sql":
                result = runWithFallback("/usr/bin/sqlite3", fallback: "sqlite3", args: [":memory:", ".read", tempFile.path])
            default:
                result = "Unsupported language: \(language)"
            }

            return result

        } catch {
            return "Failed to create temp file: \(error.localizedDescription)"
        }
    }

    static func getFileExtension(for language: String) -> String {
        switch language.lowercased() {
        case "python", "python3": return "py"
        case "ruby": return "rb"
        case "node", "node.js", "javascript": return "js"
        case "swift": return "swift"
        case "bash", "sh": return "sh"
        case "go": return "go"
        case "c": return "c"
        case "c++", "cpp": return "cpp"
        case "rust": return "rs"
        case "java": return "java"
        case "typescript": return "ts"
        case "kotlin": return "kt"
        case "dart": return "dart"
        case "sql": return "sql"
        default: return "txt"
        }
    }

    private static func compileAndRunC(tempFile: URL) -> String {
        let outputFile = tempFile.deletingPathExtension()
            .appendingPathExtension("\(UUID().uuidString).out")
        defer { try? FileManager.default.removeItem(at: outputFile) }

        // Try gcc first, then clang as fallback
        let compileResult = runWithFallbackReturningResult("/usr/bin/gcc", fallback: "gcc", args: ["-o", outputFile.path, tempFile.path])
        if compileResult.exitCode == 0 {
            return run(outputFile.path)
        }

        // Try clang as fallback
        let clangResult = runWithFallbackReturningResult("/usr/bin/clang", fallback: "clang", args: ["-o", outputFile.path, tempFile.path])
        if clangResult.exitCode == 0 {
            return run(outputFile.path)
        }

        return "Compilation failed. Please ensure gcc or clang is installed.\nGCC Error: \(compileResult.output)\nClang Error: \(clangResult.output)"
    }

    private static func compileAndRunCpp(tempFile: URL) -> String {
        let outputFile = tempFile.deletingPathExtension()
            .appendingPathExtension("\(UUID().uuidString).out")
        defer { try? FileManager.default.removeItem(at: outputFile) }

        // Try g++ first, then clang++ as fallback
        let compileResult = runWithFallbackReturningResult("/usr/bin/g++", fallback: "g++", args: ["-o", outputFile.path, tempFile.path])
        if compileResult.exitCode == 0 {
            return run(outputFile.path)
        }

        // Try clang++ as fallback
        let clangResult = runWithFallbackReturningResult("/usr/bin/clang++", fallback: "clang++", args: ["-o", outputFile.path, tempFile.path])
        if clangResult.exitCode == 0 {
            return run(outputFile.path)
        }

        return "Compilation failed. Please ensure g++ or clang++ is installed.\nG++ Error: \(compileResult.output)\nClang++ Error: \(clangResult.output)"
    }

    private static func compileAndRunRust(tempFile: URL) -> String {
        let outputFile = tempFile.deletingPathExtension()
            .appendingPathExtension("\(UUID().uuidString).out")
        defer { try? FileManager.default.removeItem(at: outputFile) }

        let compileResult = runWithFallbackReturningResult("/usr/local/bin/rustc", fallback: "rustc", args: ["-o", outputFile.path, tempFile.path])
        if compileResult.exitCode == 0 {
            return run(outputFile.path)
        }
        return "Rust compilation failed. Please ensure rustc is installed.\nError: \(compileResult.output)"
    }

    private static func compileAndRunJava(tempFile: URL) -> String {
        // Use a dedicated temp directory so inner classes (Foo$Bar.class) are cleaned up
        let javaDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("devreader_java_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: javaDir) }

        do {
            try FileManager.default.createDirectory(at: javaDir, withIntermediateDirectories: true)
        } catch {
            return "Failed to create temp directory: \(error.localizedDescription)"
        }

        let compileResult = runWithFallbackReturningResult(
            "/usr/bin/javac", fallback: "javac",
            args: ["-d", javaDir.path, tempFile.path]
        )
        if compileResult.exitCode == 0 {
            let className = tempFile.deletingPathExtension().lastPathComponent
            return runWithFallback("/usr/bin/java", fallback: "java", args: ["-cp", javaDir.path, className])
        }
        return "Java compilation failed. Please ensure javac and java are installed.\nError: \(compileResult.output)"
    }
}
