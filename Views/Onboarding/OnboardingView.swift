import SwiftUI

struct OnboardingView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var currentStep = 0
	@AppStorage("didSeeOnboarding") private var didSeeOnboarding = false
	
	private var steps: [OnboardingStep] {
		OnboardingStepFactory.createDefaultSteps()
	}
	
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
						.accessibilityLabel(steps[currentStep].accessibilityLabel)
						.accessibilityHint(steps[currentStep].accessibilityHint)
					
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
						.accessibilityLabel("Go to previous step")
						.accessibilityHint("Return to the previous onboarding step")
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
						.accessibilityLabel("Go to next step")
						.accessibilityHint("Continue to the next onboarding step")
					} else {
						Button("Get Started") {
							didSeeOnboarding = true
							dismiss()
						}
						.buttonStyle(.borderedProminent)
						.controlSize(.large)
						.accessibilityLabel("Complete onboarding")
						.accessibilityHint("Finish the onboarding process and start using DevReader")
					}
				}
				.padding(.horizontal, 40)
				.padding(.bottom, 40)
			}
		}
		.frame(minWidth: 600, minHeight: 500)
		.onAppear {
			// Mark onboarding as seen when it appears
			didSeeOnboarding = true
		}
		.onKeyPress(.rightArrow) {
			if currentStep < steps.count - 1 {
				withAnimation(.easeInOut(duration: 0.3)) {
					currentStep += 1
				}
				return .handled
			}
			return .ignored
		}
		.onKeyPress(.leftArrow) {
			if currentStep > 0 {
				withAnimation(.easeInOut(duration: 0.3)) {
					currentStep -= 1
				}
				return .handled
			}
			return .ignored
		}
		.onKeyPress(.return) {
			if currentStep < steps.count - 1 {
				withAnimation(.easeInOut(duration: 0.3)) {
					currentStep += 1
				}
			} else {
				didSeeOnboarding = true
				dismiss()
			}
			return .handled
		}
	}
	
}

struct OnboardingStep {
	let title: String
	let subtitle: String
	let description: String
	let icon: String
	let accessibilityLabel: String
	let accessibilityHint: String
	
	init(title: String, subtitle: String, description: String, icon: String, accessibilityLabel: String? = nil, accessibilityHint: String? = nil) {
		self.title = title
		self.subtitle = subtitle
		self.description = description
		self.icon = icon
		self.accessibilityLabel = accessibilityLabel ?? "Onboarding step icon"
		self.accessibilityHint = accessibilityHint ?? "Visual indicator for the current onboarding step"
	}
}

// MARK: - OnboardingStepFactory

struct OnboardingStepFactory {
	static func createDefaultSteps() -> [OnboardingStep] {
		return [
			OnboardingStep(
				title: "Welcome to DevReader",
				subtitle: "Your PDF reader for developers",
				description: "DevReader combines PDF reading, note-taking, and coding tools in one powerful app.",
				icon: "doc.text.fill",
				accessibilityLabel: "Document icon",
				accessibilityHint: "Represents the main document reading functionality"
			),
			OnboardingStep(
				title: "Smart Note-Taking",
				subtitle: "Highlight and capture",
				description: "Select text in any PDF and press ⌘⇧H to instantly create organized notes. Add page-specific markdown notes for detailed annotations.",
				icon: "highlighter",
				accessibilityLabel: "Highlighter icon",
				accessibilityHint: "Represents note-taking and highlighting features"
			),
			OnboardingStep(
				title: "Code & Web Integration",
				subtitle: "Built-in development tools",
				description: "Run Python, Ruby, and Node.js code directly in the app. Browse documentation with the integrated web view.",
				icon: "terminal.fill",
				accessibilityLabel: "Terminal icon",
				accessibilityHint: "Represents code execution and web browsing tools"
			),
			OnboardingStep(
				title: "Ready to Start",
				subtitle: "Import your first PDF",
				description: "Click 'Import PDFs…' to add documents to your library, or drag and drop PDFs into the sidebar.",
				icon: "plus.circle.fill",
				accessibilityLabel: "Plus circle icon",
				accessibilityHint: "Represents importing and adding new PDFs to your library"
			)
		]
	}
	
	// Future: Add methods for localized steps, custom steps, etc.
	static func createLocalizedSteps(for locale: Locale) -> [OnboardingStep] {
		// Implementation for localized onboarding
		return createDefaultSteps()
	}
	
	static func createCustomSteps(_ customSteps: [OnboardingStep]) -> [OnboardingStep] {
		// Implementation for custom onboarding flows
		return customSteps
	}
}
