import Foundation

// Contrato comum entre os motores de transcrição (whisper.cpp e Apple
// SpeechAnalyzer — ver ADR 0002). Um "protocol" em Swift é equivalente a
// uma interface: descreve o que um tipo faz, sem amarrar a como ele faz.
// Doc: https://docs.swift.org/swift-book/documentation/the-swift-programming-language/protocols/
protocol STTEngine: Sendable {
    /// Nome legível pra logs e comparação entre motores.
    var name: String { get }

    /// Transcreve um arquivo de áudio (WAV mono 16kHz) e devolve o texto bruto.
    /// `language` usa códigos curtos: "pt", "en".
    func transcribe(audioFileURL: URL, language: String) async throws -> String
}

enum STTError: Error, CustomStringConvertible {
    case notAvailable(String)
    case processFailed(String)

    var description: String {
        switch self {
        case .notAvailable(let reason): return "STT indisponível: \(reason)"
        case .processFailed(let reason): return "STT falhou: \(reason)"
        }
    }
}
