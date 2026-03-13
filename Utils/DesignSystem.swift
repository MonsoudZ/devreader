import SwiftUI

// MARK: - Design Tokens

/// Single source of truth for all visual constants in the app.
enum DS {

	// MARK: Spacing

	enum Spacing {
		/// 2pt — hairline gaps
		static let xxs: CGFloat = 2
		/// 4pt — tight inner padding
		static let xs: CGFloat = 4
		/// 8pt — default inner padding, icon gaps
		static let sm: CGFloat = 8
		/// 12pt — standard content spacing
		static let md: CGFloat = 12
		/// 16pt — section padding, card insets
		static let lg: CGFloat = 16
		/// 24pt — major section gaps
		static let xl: CGFloat = 24
		/// 32pt — page-level margins
		static let xxl: CGFloat = 32
	}

	// MARK: Corner Radius

	enum Radius {
		/// 4pt — pills, tags
		static let sm: CGFloat = 4
		/// 6pt — inputs, small cards
		static let md: CGFloat = 6
		/// 8pt — cards, toolbars
		static let lg: CGFloat = 8
		/// 12pt — sheets, toasts
		static let xl: CGFloat = 12
	}

	// MARK: Shadows

	enum Shadow {
		/// Subtle lift for cards and floating elements
		static func card(_ scheme: ColorScheme = .light) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
			let opacity: Double = scheme == .dark ? 0.4 : 0.12
			return (Color.black.opacity(opacity), 6, 0, 2)
		}

		/// Stronger elevation for toolbars and popovers
		static func toolbar(_ scheme: ColorScheme = .light) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
			let opacity: Double = scheme == .dark ? 0.5 : 0.15
			return (Color.black.opacity(opacity), 8, 0, 3)
		}

		/// Colored glow for toasts and status indicators
		static func glow(_ color: Color) -> (color: Color, radius: CGFloat, x: CGFloat, y: CGFloat) {
			(color.opacity(0.25), 10, 0, 4)
		}
	}

	// MARK: Typography

	enum Typography {
		static let largeTitle: Font = .largeTitle
		static let title: Font = .title2.weight(.semibold)
		static let heading: Font = .headline
		static let subheading: Font = .subheadline.weight(.medium)
		static let body: Font = .body
		static let callout: Font = .callout
		static let caption: Font = .caption
		static let caption2: Font = .caption2
		static let mono: Font = .system(.body, design: .monospaced)
		static let monoCaption: Font = .system(.caption, design: .monospaced)
		static let monoSmall: Font = .system(.caption2, design: .monospaced)
	}

	// MARK: Colors

	enum Colors {
		// Semantic backgrounds
		static let surface = Color(NSColor.windowBackgroundColor)
		static let controlSurface = Color(NSColor.controlBackgroundColor)
		static let contentSurface = Color(NSColor.textBackgroundColor)
		static let selectedSurface = Color.accentColor.opacity(0.12)

		// Semantic foreground
		static let primary = Color.primary
		static let secondary = Color.secondary
		static let tertiary = Color(NSColor.tertiaryLabelColor)

		// Accent palette
		static let accent = Color.accentColor
		static let success = Color.green
		static let warning = Color.orange
		static let error = Color.red
		static let info = Color.blue
		static let critical = Color.purple

		// Annotation / highlight palette
		static func highlight(_ name: String) -> Color {
			switch name {
			case "green": .green.opacity(0.3)
			case "blue": .blue.opacity(0.3)
			case "pink": .pink.opacity(0.3)
			default: .yellow.opacity(0.3)
			}
		}

		// Tag colors (cycle through for variety)
		static let tagPalette: [Color] = [
			.blue, .purple, .green, .orange, .pink, .teal, .indigo
		]

		static func tag(for string: String) -> Color {
			let index = abs(string.hashValue) % tagPalette.count
			return tagPalette[index]
		}
	}

	// MARK: Animation

	enum Animation {
		static let quick: SwiftUI.Animation = .easeInOut(duration: 0.15)
		static let standard: SwiftUI.Animation = .easeInOut(duration: 0.2)
		static let smooth: SwiftUI.Animation = .easeInOut(duration: 0.3)
		static let spring: SwiftUI.Animation = .spring(response: 0.4, dampingFraction: 0.8)
		static let bounce: SwiftUI.Animation = .spring(response: 0.5, dampingFraction: 0.7)
	}

	// MARK: Layout

	enum Layout {
		/// Sidebar column widths
		static let sidebarMin: CGFloat = 220
		static let sidebarIdeal: CGFloat = 280
		static let sidebarMax: CGFloat = 360

		/// Inspector column widths
		static let inspectorMin: CGFloat = 300
		static let inspectorIdeal: CGFloat = 360
		static let inspectorMax: CGFloat = 480

		/// Thumbnail pane width
		static let thumbnailWidth: CGFloat = 160

		/// Toolbar metrics
		static let toolbarHeight: CGFloat = 36
		static let tabBarHeight: CGFloat = 32

		/// Icon sizes
		static let iconSm: CGFloat = 14
		static let iconMd: CGFloat = 20
		static let iconLg: CGFloat = 28
		static let iconXl: CGFloat = 40

		/// Min touch/click target
		static let minTapTarget: CGFloat = 28
	}
}

// MARK: - View Modifiers

/// Floating toolbar background (search bar, PDF toolbar, TTS controls)
struct FloatingToolbarStyle: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		let shadow = DS.Shadow.toolbar(colorScheme)
		content
			.padding(.horizontal, DS.Spacing.md)
			.padding(.vertical, DS.Spacing.sm)
			.background(.regularMaterial)
			.clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
			.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
	}
}

/// Card-style container (sections, panels, grouped content)
struct CardStyle: ViewModifier {
	@Environment(\.colorScheme) private var colorScheme

	func body(content: Content) -> some View {
		let shadow = DS.Shadow.card(colorScheme)
		content
			.padding(DS.Spacing.md)
			.background(DS.Colors.controlSurface)
			.clipShape(RoundedRectangle(cornerRadius: DS.Radius.lg))
			.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
	}
}

/// Search field container styling
struct SearchFieldStyle: ViewModifier {
	func body(content: Content) -> some View {
		content
			.padding(.horizontal, DS.Spacing.md)
			.padding(.vertical, DS.Spacing.sm)
			.background(DS.Colors.controlSurface)
			.clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
	}
}

/// Section header styling for panel titles
struct SectionHeaderStyle: ViewModifier {
	func body(content: Content) -> some View {
		content
			.font(DS.Typography.heading)
			.foregroundStyle(DS.Colors.primary)
	}
}

/// Tag pill styling
struct TagPillStyle: ViewModifier {
	let color: Color

	func body(content: Content) -> some View {
		content
			.font(DS.Typography.caption2)
			.padding(.horizontal, DS.Spacing.sm)
			.padding(.vertical, DS.Spacing.xxs)
			.background(color.opacity(0.15))
			.foregroundStyle(color)
			.clipShape(Capsule())
	}
}

// MARK: - View Extensions

extension View {
	func floatingToolbarStyle() -> some View {
		modifier(FloatingToolbarStyle())
	}

	func cardStyle() -> some View {
		modifier(CardStyle())
	}

	func searchFieldStyle() -> some View {
		modifier(SearchFieldStyle())
	}

	func sectionHeaderStyle() -> some View {
		modifier(SectionHeaderStyle())
	}

	func tagPill(_ color: Color) -> some View {
		modifier(TagPillStyle(color: color))
	}
}

// MARK: - Button Styles

/// Primary action button — uses system borderedProminent style
struct DSPrimaryButtonStyle: PrimitiveButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		Button(role: nil, action: configuration.trigger) {
			configuration.label
		}
		.buttonStyle(.borderedProminent)
		.controlSize(.regular)
	}
}

/// Secondary action button — uses system bordered style
struct DSSecondaryButtonStyle: PrimitiveButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		Button(role: nil, action: configuration.trigger) {
			configuration.label
		}
		.buttonStyle(.bordered)
		.controlSize(.regular)
	}
}

/// Toolbar icon button — minimal with hover/press feedback
struct DSToolbarButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.frame(minWidth: DS.Layout.minTapTarget, minHeight: DS.Layout.minTapTarget)
			.contentShape(Rectangle())
			.background(
				RoundedRectangle(cornerRadius: DS.Radius.sm)
					.fill(configuration.isPressed ? DS.Colors.accent.opacity(0.12) : Color.clear)
			)
			.scaleEffect(configuration.isPressed ? 0.92 : 1.0)
			.animation(DS.Animation.quick, value: configuration.isPressed)
	}
}

/// Destructive action button
struct DSDestructiveButtonStyle: ButtonStyle {
	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.font(DS.Typography.subheading)
			.padding(.horizontal, DS.Spacing.md)
			.padding(.vertical, DS.Spacing.xs)
			.background(DS.Colors.error.opacity(configuration.isPressed ? 0.18 : 0.1))
			.foregroundStyle(DS.Colors.error)
			.clipShape(RoundedRectangle(cornerRadius: DS.Radius.md))
			.scaleEffect(configuration.isPressed ? 0.97 : 1.0)
			.animation(DS.Animation.quick, value: configuration.isPressed)
	}
}
