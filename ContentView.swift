import SwiftUI

struct ContentView: View {
    @EnvironmentObject var engine: LyricsEngine
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        VStack(spacing: 24) {
            Text("LyricDash")
                .font(.largeTitle.bold())

            VStack(spacing: 4) {
                Text(engine.title.isEmpty ? "Nothing playing" : engine.title)
                    .font(.headline)
                Text(engine.artist)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                Text(engine.currentLine)
                    .font(.title2.bold())
                    .multilineTextAlignment(.center)
                Text(engine.nextLine)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
            .padding()
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20))

            Stepper("Timing: \(engine.offset, specifier: "%+.1f") s",
                    value: $engine.offset, in: -5...5, step: 0.5)

            Button(engine.isRunning ? "Stop" : "Start") {
                if engine.isRunning {
                    engine.stop()
                } else {
                    Task { await engine.start() }
                }
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Text(engine.status)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()
        }
        .padding()
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                engine.appBecameActive()
            }
        }
    }
}
