import Foundation

// Manda o texto bruto da transcrição pro Ollama local (ver ADR 0003)
// limpar: remover hesitação, ajustar pontuação/capitalização, resolver
// autocorreção falada. `URLSession` é a API padrão do Foundation pra
// chamadas HTTP — aqui local, `localhost:11434`, sem sair da máquina.
//
// O prompt é sensível ao idioma de propósito: uma primeira versão sem
// isso instruía remover "um" como palavra de preenchimento (comum em
// inglês) e o modelo apagou o numeral "um" de "um, dois, três" em
// português — mesma grafia, significados diferentes. Cada idioma tem sua
// própria lista de preenchimentos.
struct OllamaCleaner {
    private let baseURL: URL
    private let model: String

    init(
        baseURL: URL = URL(string: "http://localhost:11434")!,
        model: String = "phi4-mini:3.8b-q4_K_M"
    ) {
        self.baseURL = baseURL
        self.model = model
    }

    func clean(rawText: String, language: String) async throws -> String {
        guard !rawText.isEmpty else { return rawText }

        let (languageName, fillers) = languageInfo(for: language)
        let prompt = """
        You are a transcript cleanup tool, not a writer. The text is in \(languageName). Follow these rules strictly:
        1. Remove these filler words/sounds if present: \(fillers). Do not remove any other word, even if it looks similar.
        2. Remove false starts and stutters.
        3. Fix punctuation and capitalization only.
        4. If the speaker corrects themselves mid-sentence (e.g. "meet Tuesday, actually Wednesday"), keep only the corrected version.
        5. Do NOT paraphrase, reword, summarize, or change word choice. Every word that is not a filler, false start, or discarded correction must appear in the output exactly as spoken, in \(languageName).
        6. Do NOT add words that were not said. Do NOT translate.
        7. Return ONLY the cleaned text. No quotes, no explanation, no preface.

        Now clean this:
        Raw: \(rawText)
        """

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
            "options": ["temperature": 0],
        ]

        var request = URLRequest(url: baseURL.appendingPathComponent("/api/generate"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let response = json["response"] as? String
        else {
            throw STTError.processFailed("Resposta inesperada do Ollama")
        }

        return response.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func languageInfo(for language: String) -> (name: String, fillers: String) {
        switch language {
        case "pt":
            return ("Portuguese", "né, tipo, sabe, ahn, hã, éh")
        default:
            return ("English", "um, uh, like, you know")
        }
    }
}
