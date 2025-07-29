// AudioDiagnostics.swift
import AVFoundation

#if DEBUG
    enum AudioDiagnostics {
        static func logSessionInfo(tag: String) {
            let s = AVAudioSession.sharedInstance()
            let outputs = s.currentRoute.outputs.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ")
            let inputs = s.currentRoute.inputs.map { "\($0.portType.rawValue)(\($0.portName))" }.joined(separator: ", ")
            debugPrint("""
            🔊 [Audio] \(tag)
               category: \(s.category.rawValue)
               mode: \(s.mode.rawValue)
               options: \(s.categoryOptions)
               output route: \(outputs)
               input route: \(inputs)
               sampleRate: \(s.sampleRate)
               ioBufferDuration: \(s.ioBufferDuration)
               isOtherAudioPlaying: \(s.isOtherAudioPlaying)
            """)
        }
        
        static func logPlayerStatus(player: AVPlayer?, tag: String) {
            guard let player = player else {
                debugPrint("🎧 [Player] \(tag) - No player")
                return
            }
            
            debugPrint("""
            🎧 [Player] \(tag)
               status: \(player.status.rawValue)
               timeControlStatus: \(player.timeControlStatus.rawValue)
               rate: \(player.rate)
               error: \(player.error?.localizedDescription ?? "none")
            """)
            
            if let item = player.currentItem {
                debugPrint("""
                📀 [PlayerItem] \(tag)
                   status: \(item.status.rawValue)
                   error: \(item.error?.localizedDescription ?? "none")
                   duration: \(item.duration.seconds)
                   loadedTimeRanges: \(item.loadedTimeRanges.count)
                """)
            }
        }
        
        static func logURLRequest(url: URL, tag: String) {
            debugPrint("""
            🌐 [URL] \(tag)
               url: \(url.absoluteString)
               scheme: \(url.scheme ?? "none")
               host: \(url.host ?? "none")
               path: \(url.path)
            """)
        }
        
        static func logAudioPlaybackError(error: Error, context: String) {
            debugPrint("""
            ❌ [Audio Error] \(context)
               error: \(error.localizedDescription)
               type: \(type(of: error))
            """)
        }
    }
#endif
