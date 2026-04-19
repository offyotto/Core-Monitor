import AVFoundation
import Foundation

enum KernelPanicMusicCue: String, Equatable {
    case silence
    case phaseOne
    case phaseTwo
    case phaseThree

    var resourceName: String? {
        switch self {
        case .silence:
            return nil
        case .phaseOne:
            return "kernelpanic_phase1"
        case .phaseTwo:
            return "kernelpanic_phase2"
        case .phaseThree:
            return "kernelpanic_phase3"
        }
    }

    var resourceExtension: String? {
        switch self {
        case .silence:
            return nil
        default:
            return "m4a"
        }
    }

    var volume: Float {
        switch self {
        case .silence:
            return 0
        case .phaseOne:
            return 0.7
        case .phaseTwo:
            return 0.78
        case .phaseThree:
            return 0.85
        }
    }
}

@MainActor
final class KernelPanicMusicPlayer {
    private var player: AVAudioPlayer?
    private var currentCue: KernelPanicMusicCue = .silence

    func play(cue: KernelPanicMusicCue) {
        guard cue != .silence else {
            stop()
            return
        }

        if currentCue == cue, let player {
            player.volume = cue.volume
            if !player.isPlaying {
                player.play()
            }
            return
        }

        stop()

        guard
            let resourceName = cue.resourceName,
            let resourceExtension = cue.resourceExtension,
            let url = Bundle.main.url(forResource: resourceName, withExtension: resourceExtension)
        else {
            currentCue = .silence
            return
        }

        do {
            let player = try AVAudioPlayer(contentsOf: url)
            player.numberOfLoops = -1
            player.volume = cue.volume
            player.prepareToPlay()
            player.play()
            self.player = player
            currentCue = cue
        } catch {
            currentCue = .silence
            player = nil
        }
    }

    func pause() {
        player?.pause()
    }

    func resume(cue: KernelPanicMusicCue) {
        guard cue != .silence else {
            stop()
            return
        }

        if currentCue != cue || player == nil {
            play(cue: cue)
            return
        }

        player?.play()
    }

    func stop() {
        player?.stop()
        player = nil
        currentCue = .silence
    }
}
