import SwiftUI

struct ScratchRunner: View {
	@State private var language: CodeLang = .python
	@State private var code: String = ""
	@State private var output: String = ""
	@State private var isRunning = false

	private var defaultCode: String {
		switch language {
		case .python:
			return "# Write some quick test code and run it.\n# Example:\n# print('hello from DevReader!')"
		case .ruby:
			return "# Write some quick test code and run it.\n# Example:\n# puts 'hello from DevReader!'"
		case .node, .javascript:
			return "// Write some quick test code and run it.\n// Example:\n// console.log('hello from DevReader!');"
		case .swift:
			return "// Write some quick test code and run it.\n// Example:\n// print(\"hello from DevReader!\")"
		case .bash:
			return "# Write some quick test code and run it.\n# Example:\n# echo 'hello from DevReader!'"
		case .go:
			return "// Write some quick test code and run it.\n// Example:\n// package main\n// import \"fmt\"\n// func main() { fmt.Println(\"hello from DevReader!\") }"
		case .c:
			return "// Write some quick test code and run it.\n// Example:\n// #include <stdio.h>\n// int main() { printf(\"hello from DevReader!\\n\"); return 0; }"
		case .cpp:
			return "// Write some quick test code and run it.\n// Example:\n// #include <iostream>\n// int main() { std::cout << \"hello from DevReader!\" << std::endl; return 0; }"
		case .rust:
			return "// Write some quick test code and run it.\n// Example:\n// fn main() { println!(\"hello from DevReader!\"); }"
		case .java:
			return "// Write some quick test code and run it.\n// Example:\n// public class Main {\n//     public static void main(String[] args) {\n//         System.out.println(\"hello from DevReader!\");\n//     }\n// }"
		case .typescript:
			return "// Write some quick test code and run it.\n// Example:\n// console.log('hello from DevReader!');"
		case .kotlin:
			return "// Write some quick test code and run it.\n// Example:\n// println(\"hello from DevReader!\")"
		case .dart:
			return "// Write some quick test code and run it.\n// Example:\n// print('hello from DevReader!');"
		case .sql:
			return "-- Write some quick test code and run it.\n-- Example:\n-- SELECT 'hello from DevReader!' as message;"
		}
	}

	var body: some View {
		VStack(spacing: 0) {
			HStack {
				Picker("Language", selection: $language) {
					ForEach(CodeLang.allCases, id: \.self) { lang in
						Text(lang.rawValue).tag(lang)
					}
				}
				.pickerStyle(.menu)
				.frame(maxWidth: 150)
				.accessibilityIdentifier("scratchLanguagePicker")
				.accessibilityLabel("Programming language")
				.accessibilityHint("Select the programming language for code execution")

				Spacer()
				Button {
					PrintService.printCode(code, language: language.rawValue)
				} label: {
					Label("Print", systemImage: "printer")
						.labelStyle(.iconOnly)
				}
				.buttonStyle(.bordered)
				.controlSize(.small)
				.accessibilityIdentifier("scratchPrint")
				.accessibilityLabel("Print code")
				.accessibilityHint("Print the code using the system print dialog")
				Button(isRunning ? "Running…" : "Run") { run() }
					.buttonStyle(.borderedProminent)
					.controlSize(.small)
					.disabled(isRunning)
					.accessibilityIdentifier("scratchRunButton")
					.accessibilityLabel("Run code")
					.accessibilityHint("Execute the code in the editor")
			}.padding(8)
			Divider()
			TextEditor(text: $code)
				.font(.system(.body, design: .monospaced))
				.padding(8)
			Divider()
			ScrollView { Text(output).font(.system(.footnote, design: .monospaced)).padding(8) }
		}
		.onAppear {
			if code.isEmpty {
				code = defaultCode
			}
		}
		.onChange(of: language) {
			code = defaultCode
		}
	}

	func run() {
		isRunning = true; output = ""
		LoadingStateManager.shared.startLoading(.general, message: "Running \(language.rawValue) code...")
		let lang = language.rawValue
		let source = code
		Task.detached(priority: .userInitiated) {
			let result = Shell.runCode(lang, code: source)
			await MainActor.run {
				self.output = result
				self.isRunning = false
				LoadingStateManager.shared.stopLoading(.general)
			}
		}
	}
}
