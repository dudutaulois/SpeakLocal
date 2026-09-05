import SwiftUI

struct ContentView: View {
    @StateObject private var viewModel = TTSViewModel()

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(red: 0.07, green: 0.09, blue: 0.14), Color(red: 0.10, green: 0.12, blue: 0.20)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            ).ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Divider().opacity(0.2)
                if viewModel.engineInstalled { mainEditor } else { setupView }
                Divider().opacity(0.2)
                footer
            }
        }
        .onAppear { viewModel.refreshEngineStatus() }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("SpeakLocal").font(.system(size: 28, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Kokoro-82M · on-device · free").font(.subheadline).foregroundStyle(.white.opacity(0.65))
            }
            Spacer()
            if viewModel.engineInstalled { controlsBar }
        }
        .padding(.horizontal, 24).padding(.vertical, 18)
    }

    private var controlsBar: some View {
        HStack(spacing: 16) {
            Picker("Voice", selection: $viewModel.selectedVoiceID) {
                ForEach(VoiceCatalog.grouped, id: \.0) { group, voices in
                    Section(group) { ForEach(voices) { Text($0.displayName).tag($0.id) } }
                }
            }.labelsHidden().frame(width: 220)
            VStack(alignment: .leading) {
                Text("Speed \(viewModel.speed, specifier: "%.1f")×").font(.caption).foregroundStyle(.white.opacity(0.6))
                Slider(value: $viewModel.speed, in: 0.7...1.4, step: 0.05).frame(width: 140)
            }
            Toggle("48 kHz", isOn: $viewModel.useHighQualitySampleRate).toggleStyle(.switch)
        }
    }

    private var mainEditor: some View {
        VStack(spacing: 16) {
            TextEditor(text: $viewModel.text)
                .font(.system(size: 16, design: .rounded))
                .scrollContentBackground(.hidden)
                .padding(8)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            HStack {
                Button(action: viewModel.speak) { Label(viewModel.isBusy ? "Working..." : "Speak", systemImage: "play.fill") }
                    .buttonStyle(PrimaryButtonStyle()).disabled(viewModel.isBusy)
                Button(action: viewModel.stop) { Label("Stop", systemImage: "stop.fill") }.buttonStyle(SecondaryButtonStyle())
                Button(action: viewModel.saveAudio) { Label("Save WAV", systemImage: "square.and.arrow.down") }.buttonStyle(SecondaryButtonStyle())
                Spacer()
            }
        }.padding(24).foregroundStyle(.white)
    }

    private var setupView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "waveform.circle.fill").font(.system(size: 64)).foregroundStyle(Color.cyan.opacity(0.85))
            Text("One-time setup").font(.title2.bold()).foregroundStyle(.white)
            Text("Install Kokoro-82M (~350 MB download, then fully offline).").multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.7)).frame(maxWidth: 520)
            Button("Install Engine") { viewModel.runInstallScript() }.buttonStyle(PrimaryButtonStyle())
            if !viewModel.installLog.isEmpty {
                ScrollView { Text(viewModel.installLog).font(.system(.caption, design: .monospaced)).textSelection(.enabled) }
                    .frame(maxWidth: 560, maxHeight: 160).padding(12).background(Color.black.opacity(0.25))
            }
            Text("Or run in Terminal: ./install.sh").font(.caption).foregroundStyle(.white.opacity(0.45))
            Spacer()
        }.padding(24)
    }

    private var footer: some View {
        HStack {
            Circle().fill(viewModel.engineInstalled ? Color.green : Color.orange).frame(width: 8, height: 8)
            Text(viewModel.statusMessage).font(.caption).foregroundStyle(.white.opacity(0.6))
            Spacer()
        }.padding(.horizontal, 24).padding(.vertical, 12)
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 18).padding(.vertical, 10)
            .background(LinearGradient(colors: [Color.cyan.opacity(0.9), Color.blue.opacity(0.85)], startPoint: .leading, endPoint: .trailing))
            .foregroundStyle(.white).clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.font(.headline).padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.white.opacity(0.10)).foregroundStyle(.white.opacity(0.9))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }
}
