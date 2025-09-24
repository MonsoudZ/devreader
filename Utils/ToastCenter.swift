import SwiftUI

final class ToastCenter: ObservableObject {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let message: String
        let style: Style
        enum Style { case info, success, warning, error }
    }

    @Published var toasts: [Toast] = []

    func show(_ title: String, _ message: String, style: Toast.Style = .info, autoDismiss: TimeInterval = 3) {
        let toast = Toast(title: title, message: message, style: style)
        toasts.append(toast)
        DispatchQueue.main.asyncAfter(deadline: .now() + autoDismiss) { [weak self] in
            self?.toasts.removeAll { $0 == toast }
        }
    }
}

struct ToastOverlay: ViewModifier {
    @ObservedObject var center: ToastCenter

    func body(content: Content) -> some View {
        ZStack(alignment: .topTrailing) {
            content
            VStack(alignment: .trailing, spacing: 8) {
                ForEach(center.toasts) { toast in
                    HStack(spacing: 10) {
                        Circle().fill(color(for: toast.style)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(toast.title).bold()
                            Text(toast.message).font(.caption)
                        }
                    }
                    .padding(10)
                    .background(.ultraThinMaterial)
                    .cornerRadius(8)
                    .shadow(radius: 4)
                }
            }
            .padding(12)
        }
    }

    private func color(for style: ToastCenter.Toast.Style) -> Color {
        switch style { case .info: return .blue; case .success: return .green; case .warning: return .orange; case .error: return .red }
    }
}

extension View {
    func toastOverlay(_ center: ToastCenter) -> some View { self.modifier(ToastOverlay(center: center)) }
}


