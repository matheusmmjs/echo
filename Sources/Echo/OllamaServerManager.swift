import Foundation

// Gerencia o ciclo de vida do `ollama serve`: sobe automaticamente com as
// flags certas quando o Echo abre (se ainda não tiver um rodando), derruba
// quando o Echo fecha — mas só se foi o Echo quem subiu, pra não incomodar
// se você já tinha um Ollama rodando por outro motivo.
// @MainActor: só é chamado a partir do AppDelegate (já MainActor); marcar
// aqui também evita o Swift 6 reclamar de mutar `process` a partir de um
// contexto concorrente.
@MainActor
final class OllamaServerManager {
    private var process: Process?
    private let binaryPath = "/opt/homebrew/opt/ollama/bin/ollama"
    private let baseURL = URL(string: "http://localhost:11434")!

    /// Garante que o Ollama está no ar, subindo um processo se preciso.
    /// Não bloqueia por muito tempo: espera no máximo ~6s pelo servidor
    /// responder antes de desistir (a primeira transcrição real vai
    /// simplesmente falhar/timeout se isso não for suficiente).
    func ensureRunning() async {
        if await isReachable() { return }
        start()
        for _ in 0..<20 {
            try? await Task.sleep(nanoseconds: 300_000_000)
            if await isReachable() { return }
        }
    }

    func stopIfWeStartedIt() {
        guard let process else {
            debugLog("OllamaServerManager.stopIfWeStartedIt: process é nil")
            return
        }
        guard process.isRunning else {
            debugLog("OllamaServerManager.stopIfWeStartedIt: process.isRunning é false")
            return
        }
        debugLog("OllamaServerManager.stopIfWeStartedIt: terminando pid \(process.processIdentifier)")
        process.terminate()
    }

    private func isReachable() async -> Bool {
        var request = URLRequest(url: baseURL)
        request.timeoutInterval = 1
        return (try? await URLSession.shared.data(for: request)) != nil
    }

    private func start() {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            debugLog("OllamaServerManager: binário não encontrado em \(binaryPath)")
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = ["serve"]
        // Herda o ambiente inteiro do Echo (HOME, PATH, etc) e só
        // adiciona/sobrescreve as flags específicas do Ollama por cima —
        // substituir o ambiente inteiro faz o `ollama serve` travar com
        // "panic: $HOME is not defined" (Ollama precisa de HOME pra achar
        // ~/.ollama/models).
        // OLLAMA_KEEP_ALIVE=30m: ver ADR 0003 — evita descarregar o modelo
        // da RAM entre usos e recarregar do disco (16s de delay observado).
        var environment = ProcessInfo.processInfo.environment
        environment["OLLAMA_KEEP_ALIVE"] = "30m"
        environment["OLLAMA_FLASH_ATTENTION"] = "1"
        environment["OLLAMA_KV_CACHE_TYPE"] = "q8_0"
        process.environment = environment
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
            self.process = process
            debugLog("OllamaServerManager: subiu ollama serve (pid \(process.processIdentifier))")
        } catch {
            debugLog("OllamaServerManager: falhou ao subir ollama serve: \(error)")
        }
    }
}
