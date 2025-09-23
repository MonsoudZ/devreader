import SwiftUI

struct OnboardingView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var currentStep = 0
	
	private let steps = [
		OnboardingStep(title: "Welcome to DevReader", subtitle: "Your PDF reader for developers", description: "DevReader combines PDF reading, note-taking, and coding tools in one powerful app.", icon: "doc.text.fill"),
		OnboardingStep(title: "Smart Note-Taking", subtitle: "Highlight and capture", description: "Select text in any PDF and press ⌘⇧H to instantly create organized notes. Add page-specific markdown notes for detailed annotations.", icon: "highlighter"),
		OnboardingStep(title: "Code & Web Integration", subtitle: "Built-in development tools", description: "Run Python, Ruby, and Node.js code directly in the app. Browse documentation with the integrated web view.", icon: "terminal.fill"),
		OnboardingStep(title: "Ready to Start", subtitle: "Import your first PDF", description: "Click 'Import PDFs…' to add documents to your library, or drag and drop PDFs into the sidebar.", icon: "plus.circle.fill")
	]
	
	var body: some View {
		NavigationView {
			VStack(spacing: 30) {
				Image(systemName: steps[currentStep].icon).font(.system(size: 60)).foregroundStyle(.blue)
				VStack(spacing: 12) {
					Text(steps[currentStep].title).font(.largeTitle).fontWeight(.bold)
					Text(steps[currentStep].subtitle).font(.title2).foregroundStyle(.secondary)
					Text(steps[currentStep].description).font(.body).multilineTextAlignment(.center).padding(.horizontal, 40)
				}
				HStack(spacing: 8) { ForEach(0..<steps.count, id: \.self) { index in Circle().fill(index == currentStep ? .blue : .gray.opacity(0.3)).frame(width: 8, height: 8) } }
				HStack(spacing: 20) {
					if currentStep > 0 { Button("Back") { withAnimation { currentStep -= 1 } } }
					Spacer()
					if currentStep < steps.count - 1 {
						Button("Next") { withAnimation { currentStep += 1 } }.buttonStyle(.borderedProminent)
					} else {
						Button("Get Started") { dismiss() }.buttonStyle(.borderedProminent)
					}
				}
				.padding(.horizontal, 40)
			}
			.frame(width: 500, height: 400)
			.navigationTitle("")
		}
	}
}

struct OnboardingStep { let title: String; let subtitle: String; let description: String; let icon: String }
