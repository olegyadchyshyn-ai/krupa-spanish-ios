import Foundation
import AVFoundation
import Speech

/// Синтез іспанського мовлення (відповідник android `SpanishTtsEngine`).
@MainActor
final class SpeechService: NSObject, ObservableObject {

    @Published private(set) var isSpeaking = false
    @Published private(set) var lastError: String?
    @Published private(set) var availableVoices: [AVSpeechSynthesisVoice] = []

    private let synthesizer = AVSpeechSynthesizer()
    private var rate: Float = 0.45
    private var preferredGender: TtsVoiceGender = .any
    private var currentText: String?

    override init() {
        super.init()
        synthesizer.delegate = self
        refreshVoices()
    }

    /// Оновлює перелік іспанських голосів, доступних на пристрої.
    func refreshVoices() {
        let spanish = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("es") }
            .sorted { $0.language < $1.language }
        availableVoices = spanish
    }

    /// Налаштовує швидкість і бажаний голос.
    func configure(rate: Double, gender: TtsVoiceGender, preferredLanguage: String = "es-ES") {
        self.rate = Float(min(0.8, max(0.2, rate)))
        self.preferredGender = gender
        _ = preferredLanguage
    }

    /// Вибір голосу: спершу точна мова (es-ES), далі будь-який іспанський.
    private func voice(for language: String) -> AVSpeechSynthesisVoice? {
        let candidates = availableVoices.filter { $0.language.hasPrefix("es") }
        let exact = candidates.filter { $0.language == language }
        let pool = exact.isEmpty ? candidates : exact

        switch preferredGender {
        case .female:
            if let voice = pool.first(where: { $0.gender == .female }) { return voice }
        case .male:
            if let voice = pool.first(where: { $0.gender == .male }) { return voice }
        case .any:
            break
        }
        return pool.first ?? AVSpeechSynthesisVoice(language: language)
    }

    /// Озвучує текст іспанською.
    func speak(_ text: String, language: String = "es-ES", rateOverride: Double? = nil) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }

        configureAudioSession()

        let utterance = AVSpeechUtterance(string: trimmed)
        utterance.voice = voice(for: language)
        utterance.rate = Float(rateOverride ?? Double(rate))
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        utterance.preUtteranceDelay = 0
        utterance.postUtteranceDelay = 0.05

        currentText = trimmed
        isSpeaking = true
        synthesizer.speak(utterance)
    }

    /// Озвучує текст із паузою між репліками (для діалогів аудіювання).
    func speakDialogue(_ lines: [String], language: String = "es-ES") {
        stop()
        configureAudioSession()
        isSpeaking = true
        for (index, line) in lines.enumerated() {
            let utterance = AVSpeechUtterance(string: line)
            utterance.voice = voice(for: language)
            utterance.rate = rate
            utterance.postUtteranceDelay = index == lines.count - 1 ? 0 : 0.4
            synthesizer.speak(utterance)
        }
    }

    func stop() {
        if synthesizer.isSpeaking {
            synthesizer.stopSpeaking(at: .immediate)
        }
        isSpeaking = false
        currentText = nil
    }

    /// Чи озвучується зараз саме цей текст.
    func isSpeakingText(_ text: String) -> Bool {
        isSpeaking && currentText == text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers, .mixWithOthers])
            try session.setActive(true, options: [])
        } catch {
            lastError = "Не вдалося налаштувати аудіо: \(error.localizedDescription)"
        }
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            if !synthesizer.isSpeaking {
                self.isSpeaking = false
                self.currentText = nil
            }
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            self.isSpeaking = false
            self.currentText = nil
        }
    }
}

// MARK: - Розпізнавання мовлення

/// Розпізнавання іспанського мовлення з мікрофона (відповідник android `SpanishSpeechRecognizer`).
@MainActor
final class SpeechRecognitionService: NSObject, ObservableObject {

    enum State: Equatable {
        case idle
        case listening
        case finished(String)
        case failed(String)
    }

    @Published private(set) var state: State = .idle
    @Published private(set) var transcript: String = ""
    @Published private(set) var isRecording: Bool = false
    @Published private(set) var audioLevel: Double = 0

    private let audioEngine = AVAudioEngine()
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "es-ES"))

    /// Запитує дозвіл на розпізнавання мовлення й мікрофон.
    func requestAuthorization() async -> Bool {
        let speechGranted = await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
        guard speechGranted else {
            state = .failed("Немає дозволу на розпізнавання мовлення. Увімкніть його в Налаштуваннях.")
            return false
        }
        let micGranted = await withCheckedContinuation { continuation in
            AVAudioApplication.requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
        if !micGranted {
            state = .failed("Немає доступу до мікрофона. Увімкніть його в Налаштуваннях.")
        }
        return micGranted
    }

    var isAvailable: Bool { recognizer?.isAvailable ?? false }

    /// Починає слухати. Результат зʼявляється в `transcript` і в `state`.
    func start(locale: String = "es-ES") throws {
        stop()

        guard let recognizer, recognizer.isAvailable else {
            state = .failed("Розпізнавання мовлення недоступне на цьому пристрої.")
            return
        }

        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.record, mode: .measurement, options: [.duckOthers])
        try session.setActive(true, options: .notifyOthersOnDeactivation)

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        request.taskHint = .dictation
        if #available(iOS 13.0, *) {
            request.requiresOnDeviceRecognition = false
        }
        recognitionRequest = request
        transcript = ""

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            let level = SpeechRecognitionService.level(from: buffer)
            Task { @MainActor in
                self?.audioLevel = level
            }
        }

        recognitionTask = recognizer.recognitionTask(with: request) { [weak self] result, error in
            Task { @MainActor in
                guard let self else { return }
                if let result {
                    self.transcript = result.bestTranscription.formattedString
                    if result.isFinal {
                        self.finish(with: self.transcript)
                    }
                }
                if let error, self.isRecording {
                    // Порожній результат + помилка = нічого не почуто.
                    if self.transcript.isEmpty {
                        self.finish(with: "")
                    } else {
                        self.finish(with: self.transcript)
                    }
                    _ = error
                }
            }
        }

        audioEngine.prepare()
        try audioEngine.start()
        isRecording = true
        state = .listening
    }

    /// Зупиняє запис і повертає розпізнаний текст.
    func stop() {
        if audioEngine.isRunning {
            audioEngine.stop()
            audioEngine.inputNode.removeTap(onBus: 0)
        }
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
        audioLevel = 0
        do {
            try AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        } catch {
            // Ігноруємо: сесію все одно перевстановить синтезатор мовлення.
        }
    }

    /// Зупиняє запис і фіксує результат.
    @discardableResult
    func finishRecording() -> String {
        let text = transcript
        stop()
        finish(with: text)
        return text
    }

    private func finish(with text: String) {
        isRecording = false
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        transcript = trimmed
        state = .finished(trimmed)
    }

    func reset() {
        stop()
        transcript = ""
        state = .idle
    }

    /// Середня гучність буфера — для індикатора рівня запису.
    private static func level(from buffer: AVAudioPCMBuffer) -> Double {
        guard let channel = buffer.floatChannelData?[0] else { return 0 }
        let count = Int(buffer.frameLength)
        guard count > 0 else { return 0 }
        var sum: Float = 0
        for index in 0..<count {
            let sample = channel[index]
            sum += sample * sample
        }
        let rms = sqrt(sum / Float(count))
        let normalized = min(1, max(0, Double(rms) * 12))
        return normalized
    }
}
