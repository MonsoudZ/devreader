import SwiftUI

/// About DevReader dialog with app information and credits
struct AboutView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: DS.Spacing.xl) {
            // App icon and title
            VStack(spacing: DS.Spacing.md) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(DS.Colors.info)

                Text("DevReader")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Version \(appVersion)")
                    .font(.title3)
                    .foregroundStyle(DS.Colors.secondary)
            }

            // Description
            Text("A powerful PDF reader designed for developers, with advanced note-taking, code integration, and research tools.")
                .font(DS.Typography.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(DS.Colors.secondary)
                .padding(.horizontal, DS.Spacing.xl)

            // Features
            VStack(alignment: .leading, spacing: DS.Spacing.sm) {
                FeatureRow(icon: "note.text", title: "Smart Notes", description: "Take notes with automatic page linking")
                FeatureRow(icon: "code", title: "Code Integration", description: "Embed and manage code snippets")
                FeatureRow(icon: "paintbrush", title: "Sketch Tools", description: "Draw and annotate directly on PDFs")
                FeatureRow(icon: "magnifyingglass", title: "Advanced Search", description: "Fast search across large documents")
            }
            .padding(.horizontal, DS.Spacing.xl)

            // Credits
            VStack(spacing: DS.Spacing.md) {
                Text("Built with SwiftUI and PDFKit")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiary)

                Text("© \(Calendar.current.component(.year, from: Date())) DevReader. All rights reserved.")
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.tertiary)
            }

            // Action buttons
            HStack(spacing: DS.Spacing.lg) {
                Button("Privacy Policy") {
                    // Open privacy policy
                    if let url = URL(string: "https://devreader.app/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .accessibilityIdentifier("aboutPrivacyPolicy")

                Button("Support") {
                    // Open support
                    if let url = URL(string: "https://devreader.app/support") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(DSSecondaryButtonStyle())
                .accessibilityIdentifier("aboutSupport")

                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
                .accessibilityIdentifier("aboutClose")
            }
        }
        .padding(DS.Spacing.xxl)
        .frame(width: 500, height: 600)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: DS.Radius.xl))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("About DevReader dialog")
    }
    
    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"
    }
}

// MARK: - Feature Row

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        HStack(spacing: DS.Spacing.md) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(DS.Colors.info)
                .frame(width: DS.Spacing.xl)

            VStack(alignment: .leading, spacing: DS.Spacing.xxs) {
                Text(title)
                    .font(DS.Typography.heading)
                Text(description)
                    .font(DS.Typography.caption)
                    .foregroundStyle(DS.Colors.secondary)
            }

            Spacer()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Preview

struct AboutView_Previews: PreviewProvider {
    static var previews: some View {
        AboutView(isPresented: .constant(true))
    }
}
