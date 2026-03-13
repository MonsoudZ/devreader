import SwiftUI

struct EmptyStateView: View {
	let icon: String
	let title: String
	let subtitle: String
	var actionLabel: String? = nil
	var action: (() -> Void)? = nil

	var body: some View {
		VStack(spacing: DS.Spacing.md) {
			Spacer()
			Image(systemName: icon)
				.font(.system(size: DS.Layout.iconXl))
				.foregroundStyle(DS.Colors.secondary)
			Text(title)
				.font(DS.Typography.heading)
				.foregroundStyle(DS.Colors.secondary)
			Text(subtitle)
				.font(DS.Typography.caption)
				.foregroundStyle(DS.Colors.tertiary)
			if let actionLabel, let action {
				Button(actionLabel, action: action)
					.buttonStyle(DSSecondaryButtonStyle())
			}
			Spacer()
		}
		.frame(maxWidth: .infinity)
		.accessibilityElement(children: .combine)
	}
}
