import Foundation

// Combina dois STTEngine num só: tenta o principal, só recorre ao
// alternativo se o principal falhar, der timeout, ou devolver vazio.
// Decisão de qual motor é o padrão está no ADR 0002 — baseada em benchmark
// real (Apple ~3x mais rápido, não aluciona em silêncio, whisper.cpp fica
// como rede de segurança sem custo enquanto não é chamado).
struct FallbackSTTEngine: STTEngine {
    let name: String

    private let primary: any STTEngine
    private let fallback: any STTEngine
    private let timeoutSeconds: Double

    init(primary: any STTEngine, fallback: any STTEngine, timeoutSeconds: Double = 20) {
        self.primary = primary
        self.fallback = fallback
        self.timeoutSeconds = timeoutSeconds
        self.name = "\(primary.name) (fallback: \(fallback.name))"
    }

    func transcribe(audioFileURL: URL, language: String) async throws -> String {
        let primaryText = await withTimeout(seconds: timeoutSeconds) {
            try await primary.transcribe(audioFileURL: audioFileURL, language: language)
        }
        if let primaryText, !primaryText.isEmpty {
            return primaryText
        }

        debugLog("FallbackSTTEngine: \(primary.name) falhou/vazio, tentando \(fallback.name)")
        let fallbackText = await withTimeout(seconds: timeoutSeconds) {
            try await fallback.transcribe(audioFileURL: audioFileURL, language: language)
        }
        guard let fallbackText else {
            throw STTError.processFailed("Ambos os motores falharam ou deram timeout")
        }
        return fallbackText
    }
}
