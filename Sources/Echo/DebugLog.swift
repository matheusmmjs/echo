import Foundation

// `NSLog`/`os_log` com texto dinâmico (%@) é redigido por privacidade no
// Console/`log show` do macOS — aparece como "<private>" pra qualquer um
// de fora (inclusive nós, olhando via terminal). Pra debug durante o
// desenvolvimento, escrevemos direto num arquivo simples, sem esse filtro.
// Remover/desligar isso quando o pipeline estiver estável (ADR a decidir).
func debugLog(_ message: String) {
    let line = "\(Date()) \(message)\n"
    let url = URL(fileURLWithPath: NSString(string: "~/Library/Logs/echo-debug.log").expandingTildeInPath)
    if let data = line.data(using: .utf8) {
        if FileManager.default.fileExists(atPath: url.path),
           let handle = try? FileHandle(forWritingTo: url) {
            handle.seekToEndOfFile()
            handle.write(data)
            try? handle.close()
        } else {
            try? data.write(to: url)
        }
    }
}
