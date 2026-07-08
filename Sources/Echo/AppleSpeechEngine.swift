import Foundation
import Speech
import AVFoundation

// SpeechAnalyzer/SpeechTranscriber: framework nativo de transcrição
// introduzido no macOS 26 (WWDC25). Roda via Neural Engine como serviço do
// sistema — não compete pelo nosso orçamento de 8GB de RAM como o
// whisper.cpp compete (ver ADR 0002). API muito nova (2025/2026), por isso
// guardamos tudo atrás de `#available` em vez de subir o deployment target
// mínimo do pacote inteiro.
// Doc: https://developer.apple.com/documentation/speech/speechanalyzer
struct AppleSpeechEngine: STTEngine {
    let name = "Apple SpeechAnalyzer (nativo)"

    func transcribe(audioFileURL: URL, language: String) async throws -> String {
        guard #available(macOS 26, *) else {
            throw STTError.notAvailable("SpeechAnalyzer exige macOS 26+")
        }
        return try await transcribeModern(audioFileURL: audioFileURL, language: language)
    }

    @available(macOS 26, *)
    private func transcribeModern(audioFileURL: URL, language: String) async throws -> String {
        let locale = Locale(identifier: localeIdentifier(for: language))

        guard SpeechTranscriber.isAvailable else {
            throw STTError.notAvailable("SpeechTranscriber não disponível neste Mac")
        }

        let supportedLocales = await DictationTranscriber.supportedLocales
        guard supportedLocales.map({ $0.identifier(.bcp47) }).contains(locale.identifier(.bcp47)) else {
            throw STTError.notAvailable("idioma '\(language)' não suportado pelo SpeechAnalyzer")
        }

        let transcriber = SpeechTranscriber(
            locale: locale,
            transcriptionOptions: [],
            reportingOptions: [],
            attributeOptions: []
        )

        // Primeira chamada pra um idioma novo baixa o modelo em background
        // (pode levar mais que alguns segundos) — chamadas seguintes acham
        // o modelo já instalado e são rápidas.
        try await ensureModelInstalled(transcriber: transcriber, locale: locale)

        let analyzer = SpeechAnalyzer(modules: [transcriber])
        let audioFile = try AVAudioFile(forReading: audioFileURL)

        if let lastSample = try await analyzer.analyzeSequence(from: audioFile) {
            try await analyzer.finalizeAndFinish(through: lastSample)
        } else {
            await analyzer.cancelAndFinishNow()
        }

        var finalText = ""
        for try await result in transcriber.results where result.isFinal {
            finalText += String(result.text.characters)
        }
        return finalText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    @available(macOS 26, *)
    private func ensureModelInstalled(transcriber: SpeechTranscriber, locale: Locale) async throws {
        let installed = await Set(SpeechTranscriber.installedLocales)
        let alreadyInstalled = installed.map { $0.identifier(.bcp47) }.contains(locale.identifier(.bcp47))
        guard !alreadyInstalled else { return }

        // Baixa o modelo de idioma sob demanda (uma vez só, fica instalado
        // no sistema depois — outros apps que usem SpeechAnalyzer reusam).
        if let request = try await AssetInventory.assetInstallationRequest(supporting: [transcriber]) {
            try await request.downloadAndInstall()
        }
    }

    private func localeIdentifier(for language: String) -> String {
        switch language {
        case "pt": return "pt-BR"
        case "en": return "en-US"
        default: return language
        }
    }
}
