import Foundation

/// Reusable debounced persistence helper. Coalesces rapid save calls into a single
/// write after a configurable delay. Call `schedule()` to queue a save and `flush()`
/// to force an immediate write (e.g., on app background / window close).
@MainActor
final class DebouncedPersister {
	private var debounceTask: Task<Void, Never>?
	private let delay: TimeInterval
	private let action: @MainActor () -> Void

	init(delay: TimeInterval = 0.3, action: @escaping @MainActor () -> Void) {
		self.delay = delay
		self.action = action
	}

	deinit {
		// Task is Sendable — safe to access from nonisolated deinit
		debounceTask?.cancel()
	}

	func schedule() {
		debounceTask?.cancel()
		let delay = self.delay
		let action = self.action
		debounceTask = Task {
			try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
			guard !Task.isCancelled else { return }
			action()
		}
	}

	func flush() {
		guard debounceTask != nil else { return }
		debounceTask?.cancel()
		debounceTask = nil
		action()
	}

	var hasPending: Bool { debounceTask != nil }
}
