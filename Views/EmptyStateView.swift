import SwiftUI

struct EmptyStateView: View {
	let icon: String
	let title: String
	let subtitle: String
	var actionLabel: String? = nil
	var action: (() -> Void)? = nil

	var body: some View {
		VStack(spacing: 12) {
			Spacer()
			Image(systemName: icon)
				.font(.system(size: 40))
				.foregroundStyle(.secondary)
			Text(title)
				.font(.headline)
				.foregroundStyle(.secondary)
			Text(subtitle)
				.font(.caption)
				.foregroundStyle(.tertiary)
			if let actionLabel, let action {
				Button(actionLabel, action: action)
					.buttonStyle(.bordered)
			}
			Spacer()
		}
		.frame(maxWidth: .infinity)
		.accessibilityElement(children: .combine)
	}
}
