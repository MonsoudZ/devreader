import Foundation

nonisolated enum Shell {
    /// Default execution timeout in seconds
    private static let executionTimeout: TimeInterval = 30

    private struct RunResult {
        let output: String
        let exitCode: Int32
    }

    // MARK: - Core Process Execution

    /// Runs a configured Process with pipe I/O, async reading, and timeout.
    /// All public/private run methods delegate here to avoid duplicating
    /// the pipe-setup / async-read / timeout-wait boilerplate.
    private static func executeProcess(_ process: Process, stdin: String? = nil) -> RunResult {
        let inPipe = Pipe()
        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardInput = inPipe
        process.standardOutput = outPipe
        process.standardError = errPipe

        do { try process.run() } catch {
            return RunResult(output: "Failed to start: \(error)", exitCode: -1)
        }

        if let s = stdin { inPipe.fileHandleForWriting.write(Data(s.utf8)) }
        inPipe.fileHandleForWriting.closeFile()

        // Read pipes asynchronously BEFORE waitUntilExit to prevent deadlock
        // when child output exceeds the ~64 KB pipe buffer.
        var outData = Data()
        var errData = Data()
        let ioGroup = DispatchGroup()

        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            outData = outPipe.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }
        ioGroup.enter()
        DispatchQueue.global(qos: .userInitiated).async {
            errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            ioGroup.leave()
        }

        // Wait with timeout to prevent infinite hangs
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

        ioGroup.wait()

        let out = String(data: outData, encoding: .utf8) ?? ""
        let err = String(data: errData, encoding: .utf8) ?? ""
        let output = out + (err.isEmpty ? "" : "\n[stderr]\n" + err)
        return RunResult(output: output, exitCode: process.terminationStatus)
    }

    /// Creates a Process targeting the given executable path and arguments.
    private static func makeProcess(_ cmd: String, args: [String]) -> Process {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: cmd)
        p.arguments = args
        return p
    }

    // MARK: - Public / Internal Run Methods

    @discardableResult
    static func run(_ cmd: String, args: [String] = [], stdin: String? = nil) -> String {
        executeProcess(makeProcess(cmd, args: args), stdin: stdin).output
    }

    private static func runReturningResult(_ cmd: String, args: [String] = [], stdin: String? = nil) -> RunResult {
        executeProcess(makeProcess(cmd, args: args), stdin: stdin)
    }

    private static func runWithFallbackReturningResult(_ primary: String, fallback: String, args: [String] = [], stdin: String? = nil) -> RunResult {
        if FileManager.default.fileExists(atPath: primary) {
            let result = runReturningResult(primary, args: args, stdin: stdin)
            if result.exitCode != -1 { return result }
        }
        let result = executeProcess(makeProcess("/usr/bin/env", args: [fallback] + args), stdin: stdin)
        if result.exitCode == -1 && result.output.hasPrefix("Failed to start:") {
            return RunResult(
                output: "Error: \(fallback) not found. Please ensure \(fallback) is installed and available in PATH.",
                exitCode: -1
            )
        }
        return result
    }

    private static func runWithFallback(_ primary: String, fallback: String, args: [String] = [], stdin: String? = nil) -> String {
        runWithFallbackReturningResult(primary, fallback: fallback, args: args, stdin: stdin).output
    }

    // MARK: - Sandboxed Execution

    /// Maximum virtual memory for sandboxed code execution (512 MB, in KB for ulimit -v)
    private static let sandboxMemoryLimitKB = 512 * 1024
    /// Maximum output file size for sandboxed code execution (10 MB, in 512-byte blocks for ulimit -f)
    private static let sandboxFileSizeBlocks = 10 * 1024 * 2

    /// Escapes a string for safe inclusion in a single-quoted shell argument.
    private static func escapeShellArg(_ arg: String) -> String {
        "'" + arg.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    /// Runs a command with resource limits (memory, file size) applied via ulimit.
    /// Used by runCode to prevent user code from exhausting system resources.
    private static func runSandboxed(_ cmd: String, args: [String] = []) -> String {
        let shellArgs = ([cmd] + args).map { escapeShellArg($0) }.joined(separator: " ")
        let script = "ulimit -v \(sandboxMemoryLimitKB) 2>/dev/null; ulimit -f \(sandboxFileSizeBlocks) 2>/dev/null; exec \(shellArgs)"
        return run("/bin/bash", args: ["-c", script])
    }

    /// Resolves primary/fallback path and runs with resource limits.
    private static func runWithFallbackSandboxed(_ primary: String, fallback: String, args: [String] = []) -> String {
        let cmd = FileManager.default.fileExists(atPath: primary) ? primary : fallback
        return runSandboxed(cmd, args: args)
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
                result = runWithFallbackSandboxed("/usr/bin/python3", fallback: "python3", args: [tempFile.path])
            case "ruby":
                result = runWithFallbackSandboxed("/usr/bin/ruby", fallback: "ruby", args: [tempFile.path])
            case "node", "node.js", "javascript":
                result = runWithFallbackSandboxed("/usr/bin/node", fallback: "node", args: [tempFile.path])
            case "swift":
                result = runWithFallbackSandboxed("/usr/bin/swift", fallback: "swift", args: [tempFile.path])
            case "bash", "sh":
                result = runWithFallbackSandboxed("/bin/bash", fallback: "bash", args: [tempFile.path])
            case "go":
                result = runWithFallbackSandboxed("/usr/local/go/bin/go", fallback: "go", args: ["run", tempFile.path])
            case "c":
                result = compileAndRunC(tempFile: tempFile)
            case "c++", "cpp":
                result = compileAndRunCpp(tempFile: tempFile)
            case "rust":
                result = compileAndRunRust(tempFile: tempFile)
            case "java":
                result = compileAndRunJava(tempFile: tempFile)
            case "typescript":
                result = runWithFallbackSandboxed("/usr/local/bin/npx", fallback: "npx", args: ["tsx", tempFile.path])
            case "kotlin":
                result = runWithFallbackSandboxed("/usr/local/bin/kotlinc", fallback: "kotlinc", args: ["-script", tempFile.path])
            case "dart":
                result = runWithFallbackSandboxed("/usr/local/bin/dart", fallback: "dart", args: ["run", tempFile.path])
            case "sql":
                result = runWithFallbackSandboxed("/usr/bin/sqlite3", fallback: "sqlite3", args: [":memory:", ".read", tempFile.path])
            default:
                result = "Unsupported language: \(language)"
            }

            return result

        } catch {
            return "Failed to create temp file: \(error.localizedDescription)"
        }
    }

    static func getFileExtension(for language: String) -> String {
        CodeLang.fromName(language)?.fileExtension ?? "txt"
    }

    private static func compileAndRunC(tempFile: URL) -> String {
        let outputFile = tempFile.deletingPathExtension()
            .appendingPathExtension("\(UUID().uuidString).out")
        defer { try? FileManager.default.removeItem(at: outputFile) }

        // Try gcc first, then clang as fallback
        let compileResult = runWithFallbackReturningResult("/usr/bin/gcc", fallback: "gcc", args: ["-o", outputFile.path, tempFile.path])
        if compileResult.exitCode == 0 {
            return runSandboxed(outputFile.path)
        }

        // Try clang as fallback
        let clangResult = runWithFallbackReturningResult("/usr/bin/clang", fallback: "clang", args: ["-o", outputFile.path, tempFile.path])
        if clangResult.exitCode == 0 {
            return runSandboxed(outputFile.path)
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
            return runSandboxed(outputFile.path)
        }

        // Try clang++ as fallback
        let clangResult = runWithFallbackReturningResult("/usr/bin/clang++", fallback: "clang++", args: ["-o", outputFile.path, tempFile.path])
        if clangResult.exitCode == 0 {
            return runSandboxed(outputFile.path)
        }

        return "Compilation failed. Please ensure g++ or clang++ is installed.\nG++ Error: \(compileResult.output)\nClang++ Error: \(clangResult.output)"
    }

    private static func compileAndRunRust(tempFile: URL) -> String {
        let outputFile = tempFile.deletingPathExtension()
            .appendingPathExtension("\(UUID().uuidString).out")
        defer { try? FileManager.default.removeItem(at: outputFile) }

        let compileResult = runWithFallbackReturningResult("/usr/local/bin/rustc", fallback: "rustc", args: ["-o", outputFile.path, tempFile.path])
        if compileResult.exitCode == 0 {
            return runSandboxed(outputFile.path)
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
            return runWithFallbackSandboxed("/usr/bin/java", fallback: "java", args: ["-cp", javaDir.path, className])
        }
        return "Java compilation failed. Please ensure javac and java are installed.\nError: \(compileResult.output)"
    }
}
