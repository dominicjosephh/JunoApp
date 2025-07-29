// AudioDiagnostics.swift
import AVFoundation

#if DEBUG
    enum AudioDiagnostics {
        static func logSessionInfo(tag: String) {
            let s = AVAudioSession.sharedInstance()
            let outputs = s.currentRoute.outputs.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ")
            debugPrint("""
            🔊 [Audio] \(tag)
               category: \(s.category.rawValue)
               mode: \(s.mode.rawValue)
               options: \(s.categoryOptions)
               route: \(outputs)
               sampleRate: \(s.sampleRate)
               ioBufferDuration: \(s.ioBufferDuration)
            """)
        }
    }
#endif
