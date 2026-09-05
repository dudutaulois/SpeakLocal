import AppKit
import Foundation
import UniformTypeIdentifiers

enum EnginePaths {
    static let supportDirectory: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return base.appendingPathComponent("SpeakLocal", isDirectory: true)
    }()

    static var venvPython: URL {
        supportDirectory.appendingPathComponent("venv/bin/python3")
    }

    static var speakScript: URL {
        supportDirectory.appendingPathComponent("speak.py")
    }

    static var isInstalled: Bool {
        FileManager.default.fileExists(atPath: venvPython.path)
            && FileManager.default.fileExists(atPath: speakScript.path)
    }
}

struct SynthesisResult: Decodable {
    let output: String
    let duration: Double
    let sampleRate: Int
    let voice: String

    enum CodingKeys: String, CodingKey {
        case output, duration, voice
        case sampleRate = "sample_rate"
    }

    var outputURL: URL { URL(fileURLWithPath: output) }
}

struct EngineErrorPayload: Decodable { let error: String }

enum TTSPhase: Equatable {
    case idle, loadingModel, synthesizing, playing, saving
}

@MainActor
final class TTSViewModel: ObservableObject {
    @Published var text = "Welcome to SpeakLocal. Paste any text here and press Speak."
    @Published var selectedVoiceID = "af_heart"
    @Published var speed: Double = 1.0
    @Published var useHighQualitySampleRate = true
    @Published var phase: TTSPhase = .idle
    @Published var statusMessage = "Ready"
    @Published var lastDuration: Double?
    @Published var engineInstalled = EnginePaths.isInstalled
    @Published var installLog = ""

    private let playback = AudioPlayback()
    private var synthesisTask: Task<Void, Never>?

    var isBusy: Bool { phase != .idle }
    var isPlaying: Bool { playback.isPlaying }

    func refreshEngineStatus() { engineInstalled = EnginePaths.isInstalled }

    func runInstallScript() {
        installLog = "Starting installation...\n"
        phase = .loadingModel
        statusMessage = "Installing TTS engine..."
        Task {
            do {
                let repoRoot = Self.locateRepoRoot()
                let scriptURL = repoRoot.appendingPathComponent("install.sh")
                guard FileManager.default.fileExists(atPath: scriptURL.path) else {
                    throw NSError(domain: "SpeakLocal", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not find install.sh. Run it from Terminal in the project folder."])
                }
                let output = try await Self.runProcess(executable: URL(fileURLWithPath: "/bin/bash"), arguments: [scriptURL.path], environment: ProcessInfo.processInfo.environment)
                installLog += output
                refreshEngineStatus()
                phase = .idle
                statusMessage = engineInstalled ? "Engine ready" : "Installation finished — check log"
            } catch {
                installLog += "\nError: \(error.localizedDescription)\n"
                phase = .idle
                statusMessage = "Installation failed"
            }
        }
    }

    func speak() {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { statusMessage = "Enter some text first"; return }
        guard engineInstalled else { statusMessage = "Install the engine first"; return }
        synthesisTask?.cancel(); playback.stop()
        synthesisTask = Task {
            do {
                phase = .synthesizing; statusMessage = "Generating speech..."
                let outputURL = FileManager.default.temporaryDirectory.appendingPathComponent("speaklocal-\(UUID().uuidString).wav")
                let sampleRate = useHighQualitySampleRate ? 48000 : 24000
                let result = try await synthesize(text: text, voice: selectedVoiceID, speed: speed, sampleRate: sampleRate, outputURL: outputURL)
                lastDuration = result.duration; phase = .playing
                statusMessage = String(format: "Playing (%.1fs)", result.duration)
                try playback.play(url: result.outputURL)
            } catch { if !Task.isCancelled { statusMessage = error.localizedDescription } }
            if !playback.isPlaying { phase = .idle; if statusMessage.hasPrefix("Playing") { statusMessage = "Done" } }
        }
    }

    func stop() { synthesisTask?.cancel(); playback.stop(); phase = .idle; statusMessage = "Stopped" }

    func saveAudio() {
        guard engineInstalled else { statusMessage = "Install the engine first"; return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.wav]
        panel.nameFieldStringValue = "speaklocal-output.wav"
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let destination = panel.url else { return }
        Task {
            do {
                phase = .saving; statusMessage = "Saving audio..."
                let sampleRate = useHighQualitySampleRate ? 48000 : 24000
                _ = try await synthesize(text: text, voice: selectedVoiceID, speed: speed, sampleRate: sampleRate, outputURL: destination)
                phase = .idle; statusMessage = "Saved to \(destination.lastPathComponent)"
            } catch { phase = .idle; statusMessage = error.localizedDescription }
        }
    }

    private func synthesize(text: String, voice: String, speed: Double, sampleRate: Int, outputURL: URL) async throws -> SynthesisResult {
        let output = try await Self.runProcess(
            executable: EnginePaths.venvPython,
            arguments: [EnginePaths.speakScript.path, "--text", text, "--voice", voice, "--speed", String(format: "%.2f", speed), "--sample-rate", String(sampleRate), "--output", outputURL.path],
            environment: ProcessInfo.processInfo.environment
        )
        guard let data = output.data(using: .utf8) else { throw NSError(domain: "SpeakLocal", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid engine response"]) }
        if let payload = try? JSONDecoder().decode(EngineErrorPayload.self, from: data) { throw NSError(domain: "SpeakLocal", code: 3, userInfo: [NSLocalizedDescriptionKey: payload.error]) }
        return try JSONDecoder().decode(SynthesisResult.self, from: data)
    }

    private static func locateRepoRoot() -> URL {
        let bundleRoot = Bundle.main.bundleURL.deletingLastPathComponent()
        for candidate in [URL(fileURLWithPath: FileManager.default.currentDirectoryPath), bundleRoot, bundleRoot.deletingLastPathComponent()] {
            if FileManager.default.fileExists(atPath: candidate.appendingPathComponent("install.sh").path) { return candidate }
        }
        return URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
    }

    private static func runProcess(executable: URL, arguments: [String], environment: [String: String]) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = executable
            process.arguments = arguments
            process.environment = environment
            let stdout = Pipe(); let stderr = Pipe()
            process.standardOutput = stdout; process.standardError = stderr
            process.terminationHandler = { proc in
                let out = String(data: stdout.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let err = String(data: stderr.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                if proc.terminationStatus == 0 { continuation.resume(returning: out + err) }
                else { continuation.resume(throwing: NSError(domain: "SpeakLocal", code: Int(proc.terminationStatus), userInfo: [NSLocalizedDescriptionKey: (err.isEmpty ? out : err).trimmingCharacters(in: .whitespacesAndNewlines)])) }
            }
            do { try process.run() } catch { continuation.resume(throwing: error) }
        }
    }
}
