import Foundation

// Manda o texto bruto da transcrição pro Ollama local (ver ADR 0003)
// limpar: remover hesitação, ajustar pontuação/capitalização, resolver
// autocorreção falada. `URLSession` é a API padrão do Foundation pra
// chamadas HTTP — aqui local, `localhost:11434`, sem sair da máquina.
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

    func clean(rawText: String) async throws -> String {
        guard !rawText.isEmpty else { return rawText }

        let prompt = """
        Clean up this raw speech transcription for use as typed text: remove filler \
        words and false starts, fix punctuation and capitalization, resolve spoken \
        self-corrections (e.g. "let's meet Tuesday, actually Wednesday" becomes \
        "let's meet Wednesday"). Keep the original language and meaning. Return ONLY \
        the cleaned text, nothing else, no quotes, no explanation.

        Raw: \(rawText)
        """

        let body: [String: Any] = [
            "model": model,
            "prompt": prompt,
            "stream": false,
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
}
