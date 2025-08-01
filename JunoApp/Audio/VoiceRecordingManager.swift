import AVFoundation
import Speech
import Foundation

@MainActor
final class VoiceRecordingManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    @Published var isRecording = false
    @Published var audioLevel: Float = 0.0
    @Published var transcribedText = ""
    @Published var permissionStatus: PermissionStatus = .notDetermined
    @Published var errorMessage: String?
    
    // MARK: - Private Properties
    private var audioEngine: AVAudioEngine?
    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioFormat: AVAudioFormat?
    private var levelTimer: Timer?
    
    // MARK: - Types
    enum PermissionStatus {
        case notDetermined
        case authorized
        case denied
        case restricted
        case speechUnavailable
    }
    
    enum VoiceRecordingError: LocalizedError {
        case speechRecognitionUnavailable
        case microphonePermissionDenied
        case speechPermissionDenied
        case audioEngineFailure(Error)
        case recognitionTaskFailed(Error)
        
        var errorDescription: String? {
            switch self {
            case .speechRecognitionUnavailable:
                return "Speech recognition is not available on this device"
            case .microphonePermissionDenied:
                return "Microphone access is required for voice recording"
            case .speechPermissionDenied:
                return "Speech recognition permission is required"
            case .audioEngineFailure(let error):
                return "Audio engine error: \(error.localizedDescription)"
            case .recognitionTaskFailed(let error):
                return "Speech recognition failed: \(error.localizedDescription)"
            }
        }
    }
    
    // MARK: - Initialization
    override init() {
        super.init()
        setupSpeechRecognizer()
        requestPermissions()
    }
    
    // MARK: - Public Methods
    func startRecording() async throws {
        guard !isRecording else { return }
        
        try await checkPermissions()
        try setupAudioSession()
        try startAudioEngine()
        
        isRecording = true
        transcribedText = ""
        errorMessage = nil
        startAudioLevelMonitoring()
        
        print("🎤 Voice recording started")
    }
    
    func stopRecording() {
        guard isRecording else { return }
        
        stopAudioEngine()
        stopAudioLevelMonitoring()
        
        isRecording = false
        audioLevel = 0.0
        
        print("🎤 Voice recording stopped")
    }
    
    func requestPermissions() {
        Task {
            await checkAndRequestPermissions()
        }
    }
    
    // MARK: - Private Methods
    private func setupSpeechRecognizer() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        speechRecognizer?.delegate = self
    }
    
    private func checkAndRequestPermissions() async {
        // Check microphone permission
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        if microphoneStatus == .undetermined {
            let granted = await withCheckedContinuation { continuation in
                AVAudioSession.sharedInstance().requestRecordPermission { granted in
                    continuation.resume(returning: granted)
                }
            }
            if !granted {
                updatePermissionStatus(.denied)
                return
            }
        } else if microphoneStatus == .denied {
            updatePermissionStatus(.denied)
            return
        }
        
        // Check speech recognition permission
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        switch speechStatus {
        case .notDetermined:
            let status = await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { status in
                    continuation.resume(returning: status)
                }
            }
            handleSpeechAuthorizationStatus(status)
        case .authorized:
            updatePermissionStatus(.authorized)
        case .denied, .restricted:
            updatePermissionStatus(.denied)
        @unknown default:
            updatePermissionStatus(.denied)
        }
    }
    
    private func checkPermissions() async throws {
        let microphoneStatus = AVAudioSession.sharedInstance().recordPermission
        guard microphoneStatus == .granted else {
            throw VoiceRecordingError.microphonePermissionDenied
        }
        
        let speechStatus = SFSpeechRecognizer.authorizationStatus()
        guard speechStatus == .authorized else {
            throw VoiceRecordingError.speechPermissionDenied
        }
        
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceRecordingError.speechRecognitionUnavailable
        }
    }
    
    @MainActor
    private func updatePermissionStatus(_ status: PermissionStatus) {
        permissionStatus = status
    }
    
    @MainActor
    private func handleSpeechAuthorizationStatus(_ status: SFSpeechRecognizerAuthorizationStatus) {
        switch status {
        case .authorized:
            permissionStatus = .authorized
        case .denied, .restricted:
            permissionStatus = .denied
        case .notDetermined:
            permissionStatus = .notDetermined
        @unknown default:
            permissionStatus = .denied
        }
    }
    
    private func setupAudioSession() throws {
        do {
            try AudioSessionManager.shared.configureForVoice()
            print("🎤 Audio session configured for voice recording")
        } catch {
            throw VoiceRecordingError.audioEngineFailure(error)
        }
    }
    
    private func startAudioEngine() throws {
        audioEngine = AVAudioEngine()
        guard let audioEngine = audioEngine else {
            throw VoiceRecordingError.audioEngineFailure(NSError(domain: "VoiceRecording", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to create audio engine"]))
        }
        
        let inputNode = audioEngine.inputNode
        audioFormat = inputNode.outputFormat(forBus: 0)
        
        guard let audioFormat = audioFormat else {
            throw VoiceRecordingError.audioEngineFailure(NSError(domain: "VoiceRecording", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to get audio format"]))
        }
        
        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceRecordingError.audioEngineFailure(NSError(domain: "VoiceRecording", code: -3, userInfo: [NSLocalizedDescriptionKey: "Failed to create recognition request"]))
        }
        
        recognitionRequest.shouldReportPartialResults = true
        
        // Create recognition task
        guard let speechRecognizer = speechRecognizer else {
            throw VoiceRecordingError.speechRecognitionUnavailable
        }
        
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                guard let self = self else { return }
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    self.stopRecording()
                    return
                }
                
                if let result = result {
                    self.transcribedText = result.bestTranscription.formattedString
                    
                    if result.isFinal {
                        self.stopRecording()
                    }
                }
            }
        }
        
        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: audioFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
            
            // Calculate audio level for UI feedback
            Task { @MainActor in
                guard let self = self else { return }
                let level = self.calculateAudioLevel(from: buffer)
                self.audioLevel = level
            }
        }
        
        // Start audio engine
        do {
            try audioEngine.start()
            print("🎤 Audio engine started successfully")
        } catch {
            throw VoiceRecordingError.audioEngineFailure(error)
        }
    }
    
    private func stopAudioEngine() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()
        
        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
    }
    
    private func startAudioLevelMonitoring() {
        levelTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            // Audio level is updated in the audio tap callback
            // This timer is just for keeping the monitoring active
        }
    }
    
    private func stopAudioLevelMonitoring() {
        levelTimer?.invalidate()
        levelTimer = nil
    }
    
    private func calculateAudioLevel(from buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData?[0] else { return 0.0 }
        
        let channelDataArray = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let rms = sqrt(channelDataArray.map { $0 * $0 }.reduce(0, +) / Float(channelDataArray.count))
        
        // Convert to a reasonable scale (0.0 to 1.0)
        let level = min(max(rms * 20, 0.0), 1.0)
        return level
    }
    
    deinit {
        Task { @MainActor in
            stopRecording()
        }
    }
}

// MARK: - SFSpeechRecognizerDelegate
extension VoiceRecordingManager: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                permissionStatus = .speechUnavailable
                errorMessage = "Speech recognition is temporarily unavailable"
                stopRecording()
            }
        }
    }
}
