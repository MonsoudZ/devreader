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
}
