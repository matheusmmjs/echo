import AVFoundation

// AVAudioEngine: API do AVFoundation pra capturar/processar áudio em tempo
// real. Aqui só usamos a parte mais simples: pegar o node de entrada (o
// microfone), "grampear" (tap) o áudio que passa por ele, e escrever num
// arquivo WAV enquanto a tecla Fn estiver pressionada.
// Doc: https://developer.apple.com/documentation/avfaudio/avaudioengine
final class AudioRecorder {
    private let engine = AVAudioEngine()
    private var audioFile: AVAudioFile?
    private(set) var isRecording = false

    /// Começa a gravar; devolve a URL do arquivo que está sendo escrito.
    func start() throws -> URL {
        let input = engine.inputNode
        let format = input.inputFormat(forBus: 0)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("echo-\(UUID().uuidString).wav")

        // Grava no formato nativo do microfone (sample rate do hardware) —
        // tanto whisper.cpp quanto o SpeechAnalyzer reamostram internamente,
        // não precisamos forçar 16kHz aqui.
        audioFile = try AVAudioFile(forWriting: url, settings: format.settings)

        input.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, _ in
            try? self?.audioFile?.write(from: buffer)
        }

        engine.prepare()
        try engine.start()
        isRecording = true
        return url
    }

    /// Para a gravação e devolve a URL do arquivo gravado (ou nil se não
    /// estava gravando).
    func stop() -> URL? {
        guard isRecording else { return nil }
        engine.inputNode.removeTap(onBus: 0)
        engine.stop()
        let url = audioFile?.url
        audioFile = nil
        isRecording = false
        return url
    }
}
