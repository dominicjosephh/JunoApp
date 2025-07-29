import AVFoundation

final class AudioRecorder: NSObject, AVAudioRecorderDelegate {
    private var recorder: AVAudioRecorder?
    private var fileURL: URL?

    func start() throws {
        let audioSession = AVAudioSession.sharedInstance()
        switch audioSession.recordPermission {
        case .undetermined:
            var granted = false
            let sem = DispatchSemaphore(value: 0)
            audioSession.requestRecordPermission { ok in
                granted = ok
                sem.signal()
            }
            sem.wait()
            if !granted {
                throw NSError(domain: "AudioRecorder", code: 1,
                              userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
            }
        case .denied:
            throw NSError(domain: "AudioRecorder", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Microphone permission denied"])
        case .granted:
            break
        @unknown default: break
        }

        let filename = "juno_voice_\(UUID().uuidString).m4a"
        let tempDir = FileManager.default.temporaryDirectory
        let url = tempDir.appendingPathComponent(filename)
        fileURL = url

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue,
        ]

        recorder = try AVAudioRecorder(url: url, settings: settings)
        recorder?.delegate = self
        recorder?.isMeteringEnabled = true
        recorder?.prepareToRecord()
        recorder?.record()
    }

    func stop() -> Data? {
        recorder?.stop()
        let url = fileURL
        recorder = nil
        guard let url else { return nil }
        return try? Data(contentsOf: url)
    }
}
