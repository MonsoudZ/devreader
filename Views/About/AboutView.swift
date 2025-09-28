import SwiftUI

/// About DevReader dialog with app information and credits
struct AboutView: View {
    @Binding var isPresented: Bool
    
    var body: some View {
        VStack(spacing: 24) {
            // App icon and title
            VStack(spacing: 12) {
                Image(systemName: "doc.text.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.blue)
                
                Text("DevReader")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text("Version \(appVersion)")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            
            // Description
            Text("A powerful PDF reader designed for developers, with advanced note-taking, code integration, and research tools.")
                .font(.body)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 20)
            
            // Features
            VStack(alignment: .leading, spacing: 8) {
                FeatureRow(icon: "note.text", title: "Smart Notes", description: "Take notes with automatic page linking")
                FeatureRow(icon: "code", title: "Code Integration", description: "Embed and manage code snippets")
                FeatureRow(icon: "paintbrush", title: "Sketch Tools", description: "Draw and annotate directly on PDFs")
                FeatureRow(icon: "magnifyingglass", title: "Advanced Search", description: "Fast search across large documents")
            }
            .padding(.horizontal, 20)
            
            // Credits
            VStack(spacing: 12) {
                Text("Built with SwiftUI and PDFKit")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                
                Text("© 2024 DevReader. All rights reserved.")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            
            // Action buttons
            HStack(spacing: 16) {
                Button("Privacy Policy") {
                    // Open privacy policy
                    if let url = URL(string: "https://devreader.app/privacy") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Support") {
                    // Open support
                    if let url = URL(string: "https://devreader.app/support") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .buttonStyle(.bordered)
                
                Button("Close") {
                    isPresented = false
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(32)
        .frame(width: 500, height: 600)
        .background(.regularMaterial)
        .cornerRadius(16)
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
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.blue)
                .frame(width: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
