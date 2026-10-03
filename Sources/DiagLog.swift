// Log de diagnóstico em ~/Library/Logs/Piano MIDI Bridge.log (para suporte e testes).
import Foundation

enum DiagLog {
    static let url = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent("Library/Logs/Piano MIDI Bridge.log")
    private static let queue = DispatchQueue(label: "piano-midi-bridge.log")
    private static let formatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"; return f
    }()

    static func write(_ message: String) {
        let line = "\(formatter.string(from: Date()))  \(message)\n"
        queue.async {
            // mantém o arquivo pequeno: recomeça ao passar de 1 MB
            if let size = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int, size > 1_000_000 {
                try? FileManager.default.removeItem(at: url)
            }
            if let h = try? FileHandle(forWritingTo: url) {
                h.seekToEndOfFile(); h.write(Data(line.utf8)); try? h.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}
