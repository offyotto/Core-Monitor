import Combine
import SwiftUI

private enum EasterEggPreferences {
    static let enabledKey = "coremonitor.easterEggsEnabled"
    static let bestRallyKey = "coremonitor.easterEggsBestRally"
}

struct EasterEggLabCard: View {
    @AppStorage(EasterEggPreferences.enabledKey) private var easterEggsEnabled = false
    @AppStorage(EasterEggPreferences.bestRallyKey) private var bestRally = 0

    var body: some View {
        DarkCard(padding: 18) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Weird Easter Eggs")
                            .font(.system(size: 18, weight: .bold))
                        Text("Opt into the deliberately odd extras that do not belong in a thermal monitor, starting with a tiny 2-bit arcade.")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 12)

                    VStack(alignment: .trailing, spacing: 4) {
                        Text(easterEggsEnabled ? "Enabled" : "Disabled")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(easterEggsEnabled ? .green : .secondary)
                        Text(bestRally == 0 ? "No rally yet" : "Best rally \(bestRally)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $easterEggsEnabled) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Enable weird mode")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Shows hidden experiments and unlocks the retro ping pong board below.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                    }
                }
                .toggleStyle(.switch)
                .tint(Color.bdAccent)

                if easterEggsEnabled {
                    RetroPingPongArcade()
                }
            }
        }
    }
}

private struct RetroPingPongArcade: View {
    @AppStorage(EasterEggPreferences.bestRallyKey) private var bestRally = 0

    @State private var arenaSize: CGSize = .zero
    @State private var playerY: CGFloat = 0.5
    @State private var cpuY: CGFloat = 0.5
    @State private var ball = CGPoint(x: 0.5, y: 0.5)
    @State private var velocity = CGVector(dx: 0.0105, dy: 0.0065)
    @State private var playerScore = 0
    @State private var cpuScore = 0
    @State private var rally = 0
    @State private var isPaused = false

    private let timer = Timer.publish(every: 1.0 / 60.0, on: .main, in: .common).autoconnect()
    private let paddleHeightRatio: CGFloat = 0.22
    private let paddleWidthRatio: CGFloat = 0.018
    private let ballSizeRatio: CGFloat = 0.024
    private let playerPaddleX: CGFloat = 0.08
    private let cpuPaddleX: CGFloat = 0.92
    private let phosphor = Color(red: 0.70, green: 0.98, blue: 0.74)
    private let background = Color(red: 0.05, green: 0.08, blue: 0.05)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Text("2-Bit Ping Pong")
                    .font(.system(size: 13, weight: .bold, design: .monospaced))
                    .foregroundStyle(phosphor)

                Spacer(minLength: 0)

                scorePill(title: "YOU", value: playerScore)
                scorePill(title: "CPU", value: cpuScore)
                scorePill(title: "RALLY", value: rally)
            }

            GeometryReader { geometry in
                ZStack {
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(background)

                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(phosphor.opacity(0.22), lineWidth: 1)

                    centerNet(size: geometry.size)
                    paddle(at: playerPaddleX, y: playerY, size: geometry.size)
                    paddle(at: cpuPaddleX, y: cpuY, size: geometry.size)
                    ballView(size: geometry.size)

                    if isPaused {
                        VStack(spacing: 8) {
                            Text("PAUSED")
                                .font(.system(size: 20, weight: .black, design: .monospaced))
                                .foregroundStyle(phosphor)
                            Text("Drag inside the arena to move your paddle.")
                                .font(.system(size: 11, weight: .semibold, design: .monospaced))
                                .foregroundStyle(phosphor.opacity(0.68))
                        }
                        .padding(.horizontal, 18)
                        .padding(.vertical, 14)
                        .background(Color.black.opacity(0.34))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .contentShape(Rectangle())
                .overlay(alignment: .topLeading) {
                    Color.clear
                        .onAppear {
                            arenaSize = geometry.size
                            restartMatch()
                        }
                        .onChange(of: geometry.size) { newValue in
                            arenaSize = newValue
                        }
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            movePlayer(to: value.location.y)
                        }
                )
            }
            .frame(height: 228)
            .onReceive(timer) { _ in
                stepGame()
            }

            HStack(spacing: 10) {
                Text("Drag anywhere inside the arena to move your paddle. Best rally persists between launches.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer(minLength: 12)

                arcadeButton(title: isPaused ? "Resume" : "Pause", tint: Color.bdAccent) {
                    isPaused.toggle()
                }

                arcadeButton(title: "Reset", tint: .orange) {
                    restartMatch()
                }
            }
        }
    }

    private func scorePill(title: String, value: Int) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(phosphor.opacity(0.72))
            Text("\(value)")
                .font(.system(size: 15, weight: .black, design: .monospaced))
                .foregroundStyle(phosphor)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(phosphor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func arcadeButton(title: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .black, design: .monospaced))
                .foregroundStyle(tint)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(tint.opacity(0.28), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }

    private func centerNet(size: CGSize) -> some View {
        VStack(spacing: 8) {
            ForEach(0..<10, id: \.self) { _ in
                Rectangle()
                    .fill(phosphor.opacity(0.32))
                    .frame(width: 4, height: 10)
            }
        }
        .position(x: size.width / 2, y: size.height / 2)
    }

    private func paddle(at normalizedX: CGFloat, y normalizedY: CGFloat, size: CGSize) -> some View {
        let paddleHeight = max(30, size.height * paddleHeightRatio)
        let paddleWidth = max(8, size.width * paddleWidthRatio)

        return Rectangle()
            .fill(phosphor)
            .frame(width: paddleWidth, height: paddleHeight)
            .position(x: size.width * normalizedX, y: size.height * normalizedY)
            .shadow(color: phosphor.opacity(0.24), radius: 4)
    }

    private func ballView(size: CGSize) -> some View {
        let ballSize = max(8, min(size.width, size.height) * ballSizeRatio)

        return Rectangle()
            .fill(phosphor)
            .frame(width: ballSize, height: ballSize)
            .position(x: size.width * ball.x, y: size.height * ball.y)
            .shadow(color: phosphor.opacity(0.32), radius: 4)
    }

    private func movePlayer(to yPosition: CGFloat) {
        guard arenaSize.height > 0 else { return }
        let halfHeight = paddleHeightRatio / 2
        playerY = clamp(yPosition / arenaSize.height, lower: halfHeight, upper: 1 - halfHeight)
    }

    private func stepGame() {
        guard arenaSize.width > 0, arenaSize.height > 0, isPaused == false else { return }

        let paddleHalfHeight = paddleHeightRatio / 2
        let paddleHalfWidth = paddleWidthRatio / 2
        let ballRadius = ballSizeRatio / 2

        playerY = clamp(playerY, lower: paddleHalfHeight, upper: 1 - paddleHalfHeight)
        cpuY = clamp(cpuY + ((ball.y - cpuY) * 0.085), lower: paddleHalfHeight, upper: 1 - paddleHalfHeight)

        ball.x += velocity.dx
        ball.y += velocity.dy

        if ball.y <= ballRadius || ball.y >= 1 - ballRadius {
            ball.y = clamp(ball.y, lower: ballRadius, upper: 1 - ballRadius)
            velocity.dy *= -1
        }

        let playerCollisionX = playerPaddleX + paddleHalfWidth + ballRadius
        if ball.x <= playerCollisionX {
            if abs(ball.y - playerY) <= paddleHalfHeight {
                ball.x = playerCollisionX
                velocity.dx = min(abs(velocity.dx) * 1.04 + 0.0004, 0.028)
                velocity.dy = clamp(velocity.dy + ((ball.y - playerY) * 0.03), lower: -0.023, upper: 0.023)
                rally += 1
                bestRally = max(bestRally, rally)
            } else if ball.x < 0 {
                cpuScore += 1
                bestRally = max(bestRally, rally)
                rally = 0
                serveBall(towardPlayer: true)
                return
            }
        }

        let cpuCollisionX = cpuPaddleX - paddleHalfWidth - ballRadius
        if ball.x >= cpuCollisionX {
            if abs(ball.y - cpuY) <= paddleHalfHeight {
                ball.x = cpuCollisionX
                velocity.dx = -min(abs(velocity.dx) * 1.04 + 0.0004, 0.028)
                velocity.dy = clamp(velocity.dy + ((ball.y - cpuY) * 0.03), lower: -0.023, upper: 0.023)
                rally += 1
                bestRally = max(bestRally, rally)
            } else if ball.x > 1 {
                playerScore += 1
                bestRally = max(bestRally, rally)
                rally = 0
                serveBall(towardPlayer: false)
                return
            }
        }
    }

    private func restartMatch() {
        playerScore = 0
        cpuScore = 0
        rally = 0
        playerY = 0.5
        cpuY = 0.5
        isPaused = false
        serveBall(towardPlayer: Bool.random())
    }

    private func serveBall(towardPlayer: Bool) {
        ball = CGPoint(x: 0.5, y: 0.5)
        let horizontalDirection: CGFloat = towardPlayer ? -1 : 1
        let verticalDirection: CGFloat = Bool.random() ? 1 : -1
        velocity = CGVector(
            dx: horizontalDirection * 0.0105,
            dy: verticalDirection * CGFloat.random(in: 0.0045...0.0105)
        )
    }

    private func clamp(_ value: CGFloat, lower: CGFloat, upper: CGFloat) -> CGFloat {
        min(max(value, lower), upper)
    }
}
