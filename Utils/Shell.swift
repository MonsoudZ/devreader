import Foundation

enum Shell {
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
		p.waitUntilExit()
		let out = String(data: outPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		let err = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
		return out + (err.isEmpty ? "" : "\n[stderr]\n" + err)
	}
	
	@discardableResult
	static func runCode(_ language: String, code: String) -> String {
		// Create a temporary file for languages that need it
		let tempDir = FileManager.default.temporaryDirectory
		let tempFile = tempDir.appendingPathComponent("temp_code.\(getFileExtension(for: language))")
		
		do {
			try code.write(to: tempFile, atomically: true, encoding: .utf8)
			
			let result: String
			switch language.lowercased() {
			case "python", "python3":
				result = run("/usr/bin/python3", args: [tempFile.path])
			case "ruby":
				result = run("/usr/bin/ruby", args: [tempFile.path])
			case "node", "node.js", "javascript":
				result = run("/usr/bin/node", args: [tempFile.path])
			case "swift":
				result = run("/usr/bin/swift", args: [tempFile.path])
			case "bash", "sh":
				result = run("/bin/bash", args: [tempFile.path])
			case "go":
				result = run("/usr/local/go/bin/go", args: ["run", tempFile.path])
			case "c":
				result = compileAndRunC(tempFile: tempFile)
			case "c++", "cpp":
				result = compileAndRunCpp(tempFile: tempFile)
			case "rust":
				result = compileAndRunRust(tempFile: tempFile)
			case "java":
				result = compileAndRunJava(tempFile: tempFile)
			case "sql":
				result = run("/usr/bin/sqlite3", args: [":memory:", ".read", tempFile.path])
			default:
				// Fallback to direct execution with -c/-e flags
				result = runDirect(language: language, code: code)
			}
			
			// Clean up temp file
			try? FileManager.default.removeItem(at: tempFile)
			return result
			
		} catch {
			return "Failed to create temp file: \(error.localizedDescription)"
		}
	}
	
	private static func runDirect(language: String, code: String) -> String {
		switch language.lowercased() {
		case "python", "python3":
			return run("/usr/bin/python3", args: ["-c"], stdin: code)
		case "ruby":
			return run("/usr/bin/ruby", args: ["-e"], stdin: code)
		case "node", "node.js", "javascript":
			return run("/usr/bin/node", args: ["-e"], stdin: code)
		case "bash", "sh":
			return run("/bin/bash", args: ["-c"], stdin: code)
		default:
			return "Unsupported language: \(language)"
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
		case "sql": return "sql"
		default: return "txt"
		}
	}
	
	private static func compileAndRunC(tempFile: URL) -> String {
		let outputFile = tempFile.deletingPathExtension().appendingPathExtension("out")
		let compileResult = run("/usr/bin/gcc", args: ["-o", outputFile.path, tempFile.path])
		if !compileResult.isEmpty && !compileResult.contains("error") {
			let runResult = run(outputFile.path)
			try? FileManager.default.removeItem(at: outputFile)
			return runResult
		}
		return compileResult
	}
	
	private static func compileAndRunCpp(tempFile: URL) -> String {
		let outputFile = tempFile.deletingPathExtension().appendingPathExtension("out")
		let compileResult = run("/usr/bin/g++", args: ["-o", outputFile.path, tempFile.path])
		if !compileResult.isEmpty && !compileResult.contains("error") {
			let runResult = run(outputFile.path)
			try? FileManager.default.removeItem(at: outputFile)
			return runResult
		}
		return compileResult
	}
	
	private static func compileAndRunRust(tempFile: URL) -> String {
		let outputFile = tempFile.deletingPathExtension().appendingPathExtension("out")
		let compileResult = run("/usr/local/bin/rustc", args: ["-o", outputFile.path, tempFile.path])
		if !compileResult.isEmpty && !compileResult.contains("error") {
			let runResult = run(outputFile.path)
			try? FileManager.default.removeItem(at: outputFile)
			return runResult
		}
		return compileResult
	}
	
	private static func compileAndRunJava(tempFile: URL) -> String {
		let compileResult = run("/usr/bin/javac", args: [tempFile.path])
		if compileResult.isEmpty || !compileResult.contains("error") {
			let className = tempFile.deletingPathExtension().lastPathComponent
			let runResult = run("/usr/bin/java", args: [className])
			// Clean up .class file
			let classFile = tempFile.deletingPathExtension().appendingPathExtension("class")
			try? FileManager.default.removeItem(at: classFile)
			return runResult
		}
		return compileResult
	}
}
