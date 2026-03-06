import Foundation
import AVFoundation
import Combine
@preconcurrency import PDFKit

@MainActor
final class TextToSpeechService: ObservableObject {
	private let synthesizer = AVSpeechSynthesizer()
	@Published var isSpeaking = false
	@Published var currentPage: Int = 0
	private var pages: [String] = []
	private var pageIndex: Int = 0
	private var delegate: SpeechDelegate?

	init() {
		let d = SpeechDelegate()
		d.onFinish = { [weak self] in
			Task { @MainActor in
				self?.didFinishUtterance()
			}
		}
		self.delegate = d
		synthesizer.delegate = d
	}

	/// Start reading from the given page index through the end of the document.
	func startReading(document: PDFDocument, fromPage startPage: Int) {
		stop()
		pages = (startPage..<document.pageCount).compactMap { i in
			document.page(at: i)?.string?.trimmingCharacters(in: .whitespacesAndNewlines)
		}.filter { !$0.isEmpty }
		guard !pages.isEmpty else { return }
		pageIndex = 0
		currentPage = startPage
		isSpeaking = true
		speakCurrentPage()
	}

	/// Read just the current page.
	func readCurrentPage(document: PDFDocument, pageIndex idx: Int) {
		stop()
		guard let page = document.page(at: idx),
			  let text = page.string?.trimmingCharacters(in: .whitespacesAndNewlines),
			  !text.isEmpty else { return }
		pages = [text]
		pageIndex = 0
		currentPage = idx
		isSpeaking = true
		speakCurrentPage()
	}

	func pause() {
		synthesizer.pauseSpeaking(at: .word)
		isSpeaking = false
	}

	func resume() {
		if synthesizer.isPaused {
			synthesizer.continueSpeaking()
			isSpeaking = true
		}
	}

	func stop() {
		synthesizer.stopSpeaking(at: .immediate)
		isSpeaking = false
		pages = []
		pageIndex = 0
	}

	var isPaused: Bool {
		synthesizer.isPaused
	}

	private func speakCurrentPage() {
		guard pageIndex < pages.count else {
			isSpeaking = false
			return
		}
		let utterance = AVSpeechUtterance(string: pages[pageIndex])
		utterance.rate = AVSpeechUtteranceDefaultSpeechRate
		utterance.voice = AVSpeechSynthesisVoice(language: nil) // system default
		synthesizer.speak(utterance)
	}

	private func didFinishUtterance() {
		pageIndex += 1
		currentPage += 1
		if pageIndex < pages.count {
			speakCurrentPage()
		} else {
			isSpeaking = false
		}
	}
}

private final class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate, @unchecked Sendable {
	var onFinish: (() -> Void)?

	func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
		onFinish?()
	}
}
