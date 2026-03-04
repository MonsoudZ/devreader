import SwiftUI

struct CodePane: View {
	@AppStorage("codeEditorMode") private var mode: CodeMode = .scratch
	var body: some View {
		VStack(spacing: 0) {
			Picker("", selection: $mode) {
				Text("Scratchpad").tag(CodeMode.scratch)
				Text("Monaco").tag(CodeMode.monaco)
			}
			.pickerStyle(.segmented)
			.padding(8)
			.accessibilityIdentifier("codeModePicker")
			.accessibilityLabel("Editor mode")
			.accessibilityHint("Switch between scratchpad and Monaco editor")
			Divider()
			switch mode {
			case .scratch: ScratchRunner()
			case .monaco: MonacoWebEditor()
			}
		}
	}
}

enum CodeMode: String { case scratch, monaco }
