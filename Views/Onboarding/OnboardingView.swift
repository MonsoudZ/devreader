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
		ZStack {
			// Background
			Color(.windowBackgroundColor)
				.ignoresSafeArea()
			
			VStack(spacing: 40) {
				Spacer()
				
				// Main content
				VStack(spacing: 30) {
					// Icon
					Image(systemName: steps[currentStep].icon)
						.font(.system(size: 80))
						.foregroundStyle(.blue)
						.symbolEffect(.bounce, value: currentStep)
					
					// Text content
					VStack(spacing: 16) {
						Text(steps[currentStep].title)
							.font(.largeTitle)
							.fontWeight(.bold)
							.multilineTextAlignment(.center)
						
						Text(steps[currentStep].subtitle)
							.font(.title2)
							.foregroundStyle(.secondary)
							.multilineTextAlignment(.center)
						
						Text(steps[currentStep].description)
							.font(.body)
							.multilineTextAlignment(.center)
							.padding(.horizontal, 40)
							.foregroundStyle(.secondary)
					}
					.animation(.easeInOut(duration: 0.3), value: currentStep)
				}
				
				Spacer()
				
				// Progress indicators
				HStack(spacing: 12) {
					ForEach(0..<steps.count, id: \.self) { index in
						Circle()
							.fill(index == currentStep ? .blue : .gray.opacity(0.3))
							.frame(width: 12, height: 12)
							.animation(.easeInOut(duration: 0.2), value: currentStep)
					}
				}
				
				// Navigation buttons
				HStack(spacing: 20) {
					if currentStep > 0 {
						Button("Back") {
							withAnimation(.easeInOut(duration: 0.3)) {
								currentStep -= 1
							}
						}
						.buttonStyle(.bordered)
						.controlSize(.large)
					}
					
					Spacer()
					
					if currentStep < steps.count - 1 {
						Button("Next") {
							withAnimation(.easeInOut(duration: 0.3)) {
								currentStep += 1
							}
						}
						.buttonStyle(.borderedProminent)
						.controlSize(.large)
					} else {
						Button("Get Started") {
							dismiss()
						}
						.buttonStyle(.borderedProminent)
						.controlSize(.large)
					}
				}
				.padding(.horizontal, 40)
				.padding(.bottom, 40)
			}
		}
		.frame(minWidth: 600, minHeight: 500)
	}
}

struct OnboardingStep { let title: String; let subtitle: String; let description: String; let icon: String }
