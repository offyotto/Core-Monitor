import SwiftUI

enum KernelPanicPreferences {
    static let enabledKey = "coremonitor.easterEggsEnabled"
    static let bestScoreKey = "coremonitor.kernelPanicBestScore"
}

struct EasterEggLabCard: View {
    @AppStorage(KernelPanicPreferences.enabledKey) private var easterEggsEnabled = false
    @AppStorage(KernelPanicPreferences.bestScoreKey) private var bestScore = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weird Easter Eggs")
                            .font(.system(size: 18, weight: .bold))
                        Text("Opt into the deliberately odd extras that do not belong in a thermal monitor, now starring a monochrome battle-box Kernel Panic.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(easterEggsEnabled ? "Enabled" : "Disabled")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(easterEggsEnabled ? .green : .secondary)
                        Text(bestScore == 0 ? "No panic contained yet" : "Best purge \(KernelPanicArcade.scoreString(bestScore))")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $easterEggsEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable weird mode")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Unlocks Kernel Panic, a fictional parody boss rush with an original monochrome battle-box look and zero real malware behavior.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.bdAccent)

                if easterEggsEnabled {
                    KernelPanicArcade()
                }
            }
            .padding(18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18))
    }
}
