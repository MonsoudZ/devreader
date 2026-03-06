import Foundation

/// Reusable debounced persistence helper. Coalesces rapid save calls into a single
/// write after a configurable delay. Call `schedule()` to queue a save and `flush()`
/// to force an immediate write (e.g., on app background / window close).
@MainActor
final class DebouncedPersister {
	nonisolated(unsafe) private var workItem: DispatchWorkItem?
	private let delay: TimeInterval
	private let action: @MainActor () -> Void

	init(delay: TimeInterval = 0.3, action: @escaping @MainActor () -> Void) {
		self.delay = delay
		self.action = action
	}

	deinit {
		workItem?.cancel()
	}

	func schedule() {
		workItem?.cancel()
		let item = DispatchWorkItem { @Sendable [weak self] in
			Task { @MainActor in
				self?.action()
			}
		}
		workItem = item
		DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
	}

	func flush() {
		guard let item = workItem else { return }
		item.cancel()
		workItem = nil
		action()
	}

	var hasPending: Bool { workItem != nil }
}
