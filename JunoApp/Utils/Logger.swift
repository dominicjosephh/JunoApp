import Foundation

enum Log {
    static func d(_ msg: String) {
        #if DEBUG
            print("🧭 [DEBUG] \(msg)")
        #endif
    }

    static func e(_ msg: String) {
        print("❌ [ERROR] \(msg)")
    }
}
