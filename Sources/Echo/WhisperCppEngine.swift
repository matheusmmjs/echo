import Foundation

// Chama o binário `whisper-cli` (instalado via `brew install whisper-cpp`)
// como processo externo — ver ADR 0002. `Process` é a API do Foundation
// pra rodar outro programa e ler sua saída, equivalente a spawn/exec.
// Doc: https://developer.apple.com/documentation/foundation/process
struct WhisperCppEngine: STTEngine {
    let name = "whisper.cpp (small)"

    private let binaryPath: String
    private let modelPath: String

    init(
        binaryPath: String = "/opt/homebrew/bin/whisper-cli",
        modelPath: String = ("~/.cache/whisper-models/ggml-small.bin" as NSString).expandingTildeInPath
    ) {
        self.binaryPath = binaryPath
        self.modelPath = modelPath
    }

    func transcribe(audioFileURL: URL, language: String) async throws -> String {
        guard FileManager.default.fileExists(atPath: binaryPath) else {
            throw STTError.notAvailable("whisper-cli não encontrado em \(binaryPath)")
        }
        guard FileManager.default.fileExists(atPath: modelPath) else {
            throw STTError.notAvailable("modelo não encontrado em \(modelPath)")
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: binaryPath)
        process.arguments = [
            "-m", modelPath,
            "-f", audioFileURL.path,
            "-l", language,
            "-nt",  // sem timestamps
            "-np",  // sem logs de carregamento do modelo/Metal, só o texto
        ]

        let outputPipe = Pipe()
        process.standardOutput = outputPipe
        process.standardError = Pipe() // descarta stderr (logs do Metal)

        try process.run()
        process.waitUntilExit()

        guard process.terminationStatus == 0 else {
            throw STTError.processFailed("whisper-cli saiu com código \(process.terminationStatus)")
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let text = String(data: data, encoding: .utf8) ?? ""
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
