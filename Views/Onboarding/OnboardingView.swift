import SwiftUI

struct OnboardingView: View {
	@Environment(\.dismiss) private var dismiss
	@State private var currentStep = 0
	@AppStorage("didSeeOnboarding") private var didSeeOnboarding = false
	
	private let steps = OnboardingStepFactory.createDefaultSteps()
	
	var body: some View {
		ZStack {
			// Background
			Color(.windowBackgroundColor)
				.ignoresSafeArea()
			
			VStack(spacing: DS.Spacing.xxl) {
				Spacer()

				// Main content
				VStack(spacing: DS.Spacing.xl) {
					// Icon
					Image(systemName: steps[currentStep].icon)
						.font(.system(size: 80))
						.foregroundStyle(DS.Colors.info)
						.symbolEffect(.bounce, value: currentStep)
						.accessibilityLabel(steps[currentStep].accessibilityLabel)
						.accessibilityHint(steps[currentStep].accessibilityHint)

					// Text content
					VStack(spacing: DS.Spacing.lg) {
						Text(steps[currentStep].title)
							.font(.largeTitle)
							.fontWeight(.bold)
							.multilineTextAlignment(.center)

						Text(steps[currentStep].subtitle)
							.font(DS.Typography.title)
							.foregroundStyle(DS.Colors.secondary)
							.multilineTextAlignment(.center)

						Text(steps[currentStep].description)
							.font(DS.Typography.body)
							.multilineTextAlignment(.center)
							.padding(.horizontal, DS.Spacing.xxl)
							.foregroundStyle(DS.Colors.secondary)
					}
					.animation(DS.Animation.smooth, value: currentStep)
				}

				Spacer()

				// Progress indicators
				HStack(spacing: DS.Spacing.md) {
					ForEach(0..<steps.count, id: \.self) { index in
						Circle()
							.fill(index == currentStep ? DS.Colors.info : .gray.opacity(0.3))
							.frame(width: DS.Spacing.md, height: DS.Spacing.md)
							.animation(DS.Animation.standard, value: currentStep)
					}
				}

				// Navigation buttons
				HStack(spacing: DS.Spacing.xl) {
					if currentStep > 0 {
						Button("Back") {
							withAnimation(DS.Animation.smooth) {
								currentStep -= 1
							}
						}
						.buttonStyle(DSSecondaryButtonStyle())
						.controlSize(.large)
						.accessibilityIdentifier("onboardingBack")
						.accessibilityLabel("Go to previous step")
						.accessibilityHint("Return to the previous onboarding step")
					}

					Spacer()

					if currentStep < steps.count - 1 {
						Button("Next") {
							withAnimation(DS.Animation.smooth) {
								currentStep += 1
							}
						}
						.buttonStyle(DSPrimaryButtonStyle())
						.controlSize(.large)
						.accessibilityIdentifier("onboardingNext")
						.accessibilityLabel("Go to next step")
						.accessibilityHint("Continue to the next onboarding step")
					} else {
						Button("Get Started") {
							didSeeOnboarding = true
							dismiss()
						}
						.buttonStyle(DSPrimaryButtonStyle())
						.controlSize(.large)
						.accessibilityIdentifier("onboardingGetStarted")
						.accessibilityLabel("Complete onboarding")
						.accessibilityHint("Finish the onboarding process and start using DevReader")
					}
				}
				.padding(.horizontal, DS.Spacing.xxl)
				.padding(.bottom, DS.Spacing.xxl)
			}
		}
		.frame(minWidth: 600, minHeight: 500)
		.onAppear {
			// Reset to first step when view appears
			currentStep = 0
		}
		.onKeyPress(.rightArrow) {
			if currentStep < steps.count - 1 {
				withAnimation(DS.Animation.smooth) {
					currentStep += 1
				}
				return .handled
			}
			return .ignored
		}
		.onKeyPress(.leftArrow) {
			if currentStep > 0 {
				withAnimation(DS.Animation.smooth) {
					currentStep -= 1
				}
				return .handled
			}
			return .ignored
		}
		.onKeyPress(.return) {
			if currentStep < steps.count - 1 {
				withAnimation(DS.Animation.smooth) {
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
	
}
