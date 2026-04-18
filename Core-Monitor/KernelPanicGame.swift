import AppKit
import Combine
import SwiftUI

enum KernelPanicBossID: String, CaseIterable, Identifiable {
    case iloveyou = "ILOVEYOU"
    case wannacry = "WannaCry"
    case stuxnet = "Stuxnet"

    var id: String { rawValue }
}

enum KernelPanicMechanic: String, CaseIterable {
    case heartSpread = "white heart bursts"
    case textMines = "mail spam text drifts"
    case charmBurst = "mail flood volleys"
    case lockOnBursts = "lock-on warning bursts"
    case ransomWalls = "ransom-note walls"
    case fileBlockers = "fake encrypted-file cubes"
    case panicTeleport = "panic teleport arena corruption"
    case laserGrid = "rapid low-damage laser grids"
    case rotatingBeams = "rotating beam arrays"
    case turretDrones = "turret drone summons"
    case precisionStrikes = "targeted precision strikes"
    case segmentation = "temporary arena segmentation"
}

struct KernelPanicBossProfile: Identifiable {
    let id: KernelPanicBossID
    let difficultyRank: Int
    let tagline: String
    let introBody: String
    let openingLine: String
    let midpointLine: String?
    let defeatLine: String
    let mechanics: [KernelPanicMechanic]
    let maxHealth: Int
    let contactDamage: Int

    static let campaignOrder: [KernelPanicBossProfile] = [
        .init(
            id: .iloveyou,
            difficultyRank: 1,
            tagline: "An inbox avalanche made of white hearts and junk mail.",
            introBody: "A fake mail blob rendered as raw text. It spams white hearts and throwaway messages, then folds into denser junk when hurt.",
            openingLine: "Inbox spike detected.",
            midpointLine: nil,
            defeatLine: "Mail flood contained.",
            mechanics: [.heartSpread, .textMines, .charmBurst],
            maxHealth: 380,
            contactDamage: 16
        ),
        .init(
            id: .wannacry,
            difficultyRank: 2,
            tagline: "Locks, walls, cubes, and louder panic.",
            introBody: "A fake ransom-note wall with lock bursts and file-cube junk. Nothing encrypts, spreads, or does anything real. It only fills the arena with pressure.",
            openingLine: "You’re not safe.",
            midpointLine: "This won’t be so easy for you.",
            defeatLine: "The panic note tore itself apart.",
            mechanics: [.lockOnBursts, .ransomWalls, .fileBlockers, .panicTeleport],
            maxHealth: 560,
            contactDamage: 20
        ),
        .init(
            id: .stuxnet,
            difficultyRank: 3,
            tagline: "Cold, teleporting, glitching, and far less forgiving.",
            introBody: "The board glitches, the floor burns, and the boss starts teleporting. Expect rapid low-damage lasers, segmentation, drones, and precision strikes layered together.",
            openingLine: "Signal drift detected.",
            midpointLine: "This won’t hold.",
            defeatLine: "The static finally breaks.",
            mechanics: [.laserGrid, .rotatingBeams, .turretDrones, .precisionStrikes, .segmentation],
            maxHealth: 860,
            contactDamage: 24
        ),
    ]

    static let byID: [KernelPanicBossID: KernelPanicBossProfile] = Dictionary(
        uniqueKeysWithValues: campaignOrder.map { ($0.id, $0) }
    )
}

enum KernelPanicScene: Equatable {
    case title
    case playing
    case paused
    case gameOver
    case victory
}

private enum KernelPanicStage: Equatable {
    case phaseOneWarmup
    case iloveyou
    case phaseTwoWarmup
    case wannacry
    case phaseThreeFakeout
    case stuxnet
    case cleared
}

private enum KernelPanicConfig {
    static let columns = 58
    static let rows = 20
    static let fps = 12.0
    static let playerMaxHealth = 100
    static let playerRetryCount = 1
    static let maxFriendlyShots = 3
    static let shotCooldownTicks = 5
    static let shotLifetimeTicks = 17
    static let playerHitGraceTicks = 3
    static let playerRespawnGraceTicks = 8
}

enum KernelPanicDirection {
    case up
    case down
    case left
    case right

    var dx: Int {
        switch self {
        case .left: return -1
        case .right: return 1
        case .up, .down: return 0
        }
    }

    var dy: Int {
        switch self {
        case .up: return -1
        case .down: return 1
        case .left, .right: return 0
        }
    }

    var glyph: String {
        "<>"
    }

    var facingName: String {
        switch self {
        case .up: return "UP"
        case .down: return "DN"
        case .left: return "LT"
        case .right: return "RT"
        }
    }
}

struct KernelPanicPlayer {
    var x: Int
    var y: Int
    var facing: KernelPanicDirection
    var integrity: Int
    var retriesRemaining: Int
    var invulnerabilityTicks: Int
    var shotCooldownTicks: Int
}

struct KernelPanicShot: Identifiable {
    let id = UUID()
    let friendly: Bool
    var text: String
    var x: Int
    var y: Int
    var dx: Int
    var dy: Int
    var damage: Int
    var ttl: Int
}

enum KernelPanicHazardStyle {
    case spam
    case beamRow
    case beamColumn
    case wall
    case cube
    case marker
    case drone
    case segmentation
}

struct KernelPanicHazard: Identifiable {
    let id = UUID()
    let style: KernelPanicHazardStyle
    var text: String
    var x: Int
    var y: Int
    var dx: Int
    var dy: Int
    var width: Int
    var height: Int
    var ttl: Int
    var damage: Int
    var warningTicks: Int
    var lowDamage: Bool
}

struct KernelPanicBossRuntime {
    let profile: KernelPanicBossProfile
    var x: Int
    var y: Int
    var hp: Int
    var maxHP: Int
    var tickCount: Int
    var phase: Int
    var primaryCooldown: Int
    var secondaryCooldown: Int
    var utilityCooldown: Int
    var specialCooldown: Int
    var teleportCooldown: Int
    var midpointTriggered: Bool
}

private struct KernelPanicInputState {
    var up = false
    var down = false
    var left = false
    var right = false
    var fireHeld = false
}

struct KernelPanicRNG {
    private var state: UInt64

    init(seed: UInt64) {
        state = max(seed, 1)
    }

    mutating func nextUnit() -> Double {
        state = 2862933555777941757 &* state &+ 3037000493
        let upper = UInt32(truncatingIfNeeded: state >> 33)
        return Double(upper) / Double(UInt32.max)
    }

    mutating func nextInt(in range: ClosedRange<Int>) -> Int {
        let span = range.upperBound - range.lowerBound + 1
        return range.lowerBound + Int(floor(nextUnit() * Double(span)))
    }

    mutating func nextBool() -> Bool {
        nextUnit() > 0.5
    }
}

@MainActor
final class KernelPanicGameModel: ObservableObject {
    @Published private(set) var scene: KernelPanicScene = .title {
        didSet { syncMusicCue() }
    }
    @Published private(set) var showHelp = false
    @Published private(set) var score = 0
    @Published private(set) var bestScore = UserDefaults.standard.integer(forKey: KernelPanicPreferences.bestScoreKey)
    @Published private(set) var phaseLabel = "BOOT"
    @Published private(set) var statusLine = "PRESS ENTER"
    @Published private(set) var detailLine = "Raw text mode. No lock-on. Three shots max."
    @Published private(set) var musicCue: KernelPanicMusicCue = .silence
    @Published private(set) var player = KernelPanicPlayer(
        x: 6,
        y: KernelPanicConfig.rows / 2,
        facing: .right,
        integrity: KernelPanicConfig.playerMaxHealth,
        retriesRemaining: KernelPanicConfig.playerRetryCount,
        invulnerabilityTicks: 0,
        shotCooldownTicks: 0
    )
    @Published private(set) var friendlyShots: [KernelPanicShot] = []
    @Published private(set) var hostileShots: [KernelPanicShot] = []
    @Published private(set) var hazards: [KernelPanicHazard] = []
    @Published private(set) var boss: KernelPanicBossRuntime?

    private var rng: KernelPanicRNG
    private var input = KernelPanicInputState()
    private var lastTick = Date()
    private var stage: KernelPanicStage = .phaseOneWarmup {
        didSet { syncMusicCue() }
    }
    private var stageTicks = 0
    private var bossWakeTick = 0
    private var statusTicks = 0
    private var recentBosses: [KernelPanicBossID] = []

    init(seed: UInt64 = UInt64(Date().timeIntervalSince1970)) {
        rng = KernelPanicRNG(seed: seed)
    }

    let boardBackground = Color.black
    let boardForeground = Color.white

    var rawDisplay: String {
        let board = renderBoard()
        var lines = [
            fit("PHASE \(phaseLabel)   SCORE \(formattedScore(score))   INT \(padded(player.integrity, width: 3))   RET \(player.retriesRemaining)   BUF \(friendlyShots.count)/\(KernelPanicConfig.maxFriendlyShots)   FACE \(player.facing.facingName)"),
            fit("STATUS \(statusLine)"),
            fit("DETAIL \(detailLine)"),
            "+" + String(repeating: "-", count: KernelPanicConfig.columns) + "+",
        ]
        lines.append(contentsOf: board.map { "|" + String($0) + "|" })
        lines.append("+" + String(repeating: "-", count: KernelPanicConfig.columns) + "+")
        lines.append(fit(sceneFooter()))

        if showHelp {
            lines.append(fit("MOVE WASD/ARROWS   FIRE SPACE   PAUSE P   HELP H"))
            lines.append(fit("FICTIONAL PARODY BOSS THEMES ONLY. NO REAL MALWARE BEHAVIOR."))
        }

        return lines.joined(separator: "\n")
    }

    var displayGrid: [[Character]] {
        renderBoard()
    }

    var bossHealthFraction: Double {
        guard let boss else { return 0 }
        return Double(max(boss.hp, 0)) / Double(max(boss.maxHP, 1))
    }

    var integrityFraction: Double {
        Double(max(player.integrity, 0)) / Double(KernelPanicConfig.playerMaxHealth)
    }

    var canSkipPhase: Bool {
        switch scene {
        case .playing, .paused:
            return stage != .cleared
        case .title, .gameOver, .victory:
            return false
        }
    }

    var combatCaption: String {
        if let boss {
            return boss.profile.tagline
        }

        switch scene {
        case .title:
            return "Original monochrome battle-box mode."
        case .paused:
            return "Time is stalled. The box is still armed."
        case .gameOver:
            return "The kernel buckled under pressure."
        case .victory:
            return "The panic field collapsed."
        case .playing:
            switch stage {
            case .phaseOneWarmup:
                return "Inbox noise rises on its own timer."
            case .phaseTwoWarmup:
                return "The arena locks up before the next breach."
            case .phaseThreeFakeout:
                return "Silence hangs for one bad second."
            case .iloveyou, .wannacry, .stuxnet:
                return detailLine
            case .cleared:
                return "Everything finally stops moving."
            }
        }
    }

    var portraitLabel: String {
        if let boss {
            return boss.profile.id.rawValue.uppercased()
        }

        switch scene {
        case .title:
            return "KERNEL"
        case .paused:
            return "PAUSE"
        case .gameOver:
            return "PANIC"
        case .victory:
            return "CLEAR"
        case .playing:
            switch stage {
            case .phaseOneWarmup:
                return "SIGNAL"
            case .phaseTwoWarmup:
                return "LOCK"
            case .phaseThreeFakeout:
                return "..."
            case .iloveyou:
                return "MAIL"
            case .wannacry:
                return "NOTE"
            case .stuxnet:
                return "BREACH"
            case .cleared:
                return "CLEAR"
            }
        }
    }

    var portraitArt: [String] {
        kernelPanicPortraitArt(scene: scene, stage: stage, bossID: boss?.profile.id)
    }

    func tick(at date: Date) {
        lastTick = date
        step()
    }

    func handlePrimaryAction() {
        switch scene {
        case .title, .gameOver, .victory:
            startCampaign()
        case .paused:
            scene = .playing
            statusLine = "UNPAUSED"
            detailLine = "Move. Face with motion. Shots stay capped."
        case .playing:
            attemptFire()
        }
    }

    func handleSpacePressed() {
        switch scene {
        case .playing:
            input.fireHeld = true
            attemptFire()
        default:
            handlePrimaryAction()
        }
    }

    func handleSpaceReleased() {
        input.fireHeld = false
    }

    func setMoveUp(_ active: Bool) { input.up = active }
    func setMoveDown(_ active: Bool) { input.down = active }
    func setMoveLeft(_ active: Bool) { input.left = active }
    func setMoveRight(_ active: Bool) { input.right = active }

    func togglePause() {
        switch scene {
        case .playing:
            scene = .paused
            statusLine = "PAUSED"
            detailLine = "Press P, ENTER, or SPACE to resume."
        case .paused:
            scene = .playing
            statusLine = "UNPAUSED"
            detailLine = "Back in it."
        default:
            break
        }
    }

    func toggleHelp() {
        showHelp.toggle()
    }

    func skipCurrentPhase() {
        guard canSkipPhase else { return }
        advanceCurrentPlayableStage()
    }

    private func startCampaign() {
        scene = .playing
        showHelp = false
        score = 0
        stage = .phaseOneWarmup
        stageTicks = 0
        bossWakeTick = rng.nextInt(in: 82...120)
        recentBosses = []
        boss = nil
        hazards = []
        hostileShots = []
        friendlyShots = []
        player = KernelPanicPlayer(
            x: 6,
            y: KernelPanicConfig.rows / 2,
            facing: .right,
            integrity: KernelPanicConfig.playerMaxHealth,
            retriesRemaining: KernelPanicConfig.playerRetryCount,
            invulnerabilityTicks: 0,
            shotCooldownTicks: 0
        )
        phaseLabel = "1"
        queueStatus("BOOT", detail: "Phase 1 noise. The inbox spikes when it wants to.")
    }

    private func step() {
        if statusTicks > 0 {
            statusTicks -= 1
        }

        guard scene == .playing else { return }

        stageTicks += 1
        updatePlayer()

        if input.fireHeld {
            attemptFire()
        }

        updateShots()
        updateHazards()
        updateBoss()
        updateStage()
        detectCollisions()
        removeExpiredEntities()
    }

    private func updatePlayer() {
        if player.invulnerabilityTicks > 0 {
            player.invulnerabilityTicks -= 1
        }
        if player.shotCooldownTicks > 0 {
            player.shotCooldownTicks -= 1
        }

        var moved = false

        if input.up {
            player.y = max(0, player.y - 1)
            player.facing = .up
            moved = true
        }
        if input.down {
            player.y = min(KernelPanicConfig.rows - 1, player.y + 1)
            player.facing = .down
            moved = true
        }
        if input.left {
            player.x = max(0, player.x - 1)
            player.facing = .left
            moved = true
        }
        if input.right {
            player.x = min(KernelPanicConfig.columns - 2, player.x + 1)
            player.facing = .right
            moved = true
        }

        if moved, stage == .phaseThreeFakeout {
            detailLine = "It does not feel finished."
        }
    }

    private func attemptFire() {
        guard scene == .playing else { return }
        guard player.shotCooldownTicks == 0 else { return }
        guard friendlyShots.count < KernelPanicConfig.maxFriendlyShots else {
            detailLine = "BUFFER FULL"
            return
        }

        let snippet = KernelPanicCodePayload.samples[rng.nextInt(in: 0...(KernelPanicCodePayload.samples.count - 1))]
        friendlyShots.append(
            KernelPanicShot(
                friendly: true,
                text: snippet,
                x: clamp(player.x + player.facing.dx, lower: 0, upper: KernelPanicConfig.columns - 1),
                y: clamp(player.y + player.facing.dy, lower: 0, upper: KernelPanicConfig.rows - 1),
                dx: player.facing.dx,
                dy: player.facing.dy,
                damage: 22,
                ttl: KernelPanicConfig.shotLifetimeTicks
            )
        )
        player.shotCooldownTicks = KernelPanicConfig.shotCooldownTicks
            detailLine = "OUT \(snippet)"
    }

    private func updateShots() {
        for index in friendlyShots.indices {
            friendlyShots[index].x += friendlyShots[index].dx
            friendlyShots[index].y += friendlyShots[index].dy
            friendlyShots[index].ttl -= 1
        }

        for index in hostileShots.indices {
            hostileShots[index].x += hostileShots[index].dx
            hostileShots[index].y += hostileShots[index].dy
            hostileShots[index].ttl -= 1
        }
    }

    private func updateHazards() {
        var spawned: [KernelPanicHazard] = []

        for index in hazards.indices {
            hazards[index].x += hazards[index].dx
            hazards[index].y += hazards[index].dy
            hazards[index].ttl -= 1

            if hazards[index].warningTicks > 0 {
                hazards[index].warningTicks -= 1
            }

            if hazards[index].style == .marker, hazards[index].warningTicks == 0, hazards[index].ttl > 0 {
                if hazards[index].width >= KernelPanicConfig.columns {
                    spawned.append(
                        KernelPanicHazard(
                            style: .beamRow,
                            text: "",
                            x: 0,
                            y: clamp(hazards[index].y, lower: 0, upper: KernelPanicConfig.rows - 1),
                            dx: 0,
                            dy: 0,
                            width: KernelPanicConfig.columns,
                            height: 1,
                            ttl: 3,
                            damage: hazards[index].damage,
                            warningTicks: 0,
                            lowDamage: hazards[index].lowDamage
                        )
                    )
                    hazards[index].ttl = 0
                } else if hazards[index].height >= KernelPanicConfig.rows {
                    spawned.append(
                        KernelPanicHazard(
                            style: .beamColumn,
                            text: "",
                            x: clamp(hazards[index].x, lower: 0, upper: KernelPanicConfig.columns - 1),
                            y: 0,
                            dx: 0,
                            dy: 0,
                            width: 1,
                            height: KernelPanicConfig.rows,
                            ttl: 3,
                            damage: hazards[index].damage,
                            warningTicks: 0,
                            lowDamage: hazards[index].lowDamage
                        )
                    )
                    hazards[index].ttl = 0
                }
            }
        }

        hazards.append(contentsOf: spawned)
    }

    private func updateStage() {
        switch stage {
        case .phaseOneWarmup:
            phaseLabel = "1"
            if stageTicks % 8 == 0 {
                spawnPhaseOneNoise()
            }
            if stageTicks >= bossWakeTick {
                spawnBoss(.iloveyou)
            }

        case .iloveyou, .wannacry, .stuxnet:
            break

        case .phaseTwoWarmup:
            phaseLabel = "2"
            if stageTicks % 7 == 0 {
                spawnPhaseTwoNoise()
            }
            if stageTicks >= bossWakeTick {
                spawnBoss(.wannacry)
            }

        case .phaseThreeFakeout:
            phaseLabel = "3"
            if stageTicks == 1 {
                hostileShots.removeAll()
                hazards.removeAll()
                friendlyShots.removeAll()
                queueStatus("IS IT OVER?", detail: "The board goes quiet. It should not.")
            }
            if stageTicks >= 20 {
                spawnBoss(.stuxnet)
            }

        case .cleared:
            break
        }
    }

    private func spawnPhaseOneNoise() {
        let text = KernelPanicMailSpam.samples[rng.nextInt(in: 0...(KernelPanicMailSpam.samples.count - 1))]
        hostileShots.append(
            KernelPanicShot(
                friendly: false,
                text: text,
                x: KernelPanicConfig.columns - 1,
                y: rng.nextInt(in: 1...(KernelPanicConfig.rows - 2)),
                dx: -1,
                dy: rng.nextInt(in: -1...1),
                damage: 8,
                ttl: 18
            )
        )
        if rng.nextBool() {
            hostileShots.append(
                KernelPanicShot(
                    friendly: false,
                    text: "♡",
                    x: KernelPanicConfig.columns - 2,
                    y: rng.nextInt(in: 1...(KernelPanicConfig.rows - 2)),
                    dx: -1,
                    dy: 0,
                    damage: 7,
                    ttl: 14
                )
            )
        }
    }

    private func spawnPhaseTwoNoise() {
        if rng.nextBool() {
            hazards.append(
                KernelPanicHazard(
                    style: .wall,
                    text: "[ PAY ]",
                    x: KernelPanicConfig.columns - 8,
                    y: rng.nextInt(in: 1...(KernelPanicConfig.rows - 2)),
                    dx: -1,
                    dy: 0,
                    width: 7,
                    height: 1,
                    ttl: 14,
                    damage: 11,
                    warningTicks: 0,
                    lowDamage: false
                )
            )
        } else {
            hostileShots.append(
                KernelPanicShot(
                    friendly: false,
                    text: "[LOCK]",
                    x: KernelPanicConfig.columns - 6,
                    y: rng.nextInt(in: 1...(KernelPanicConfig.rows - 2)),
                    dx: -1,
                    dy: rng.nextInt(in: -1...1),
                    damage: 10,
                    ttl: 16
                )
            )
        }
    }

    private func spawnBoss(_ identifier: KernelPanicBossID) {
        guard let profile = KernelPanicBossProfile.byID[identifier] else { return }

        let xRange: ClosedRange<Int> = profile.id == .iloveyou ? 31...36 : 32...40
        let yRange: ClosedRange<Int> = profile.id == .stuxnet ? 2...9 : 3...10
        boss = KernelPanicBossRuntime(
            profile: profile,
            x: rng.nextInt(in: xRange),
            y: rng.nextInt(in: yRange),
            hp: profile.maxHealth,
            maxHP: profile.maxHealth,
            tickCount: 0,
            phase: 1,
            primaryCooldown: 2,
            secondaryCooldown: 7,
            utilityCooldown: 11,
            specialCooldown: 18,
            teleportCooldown: profile.id == .stuxnet ? 10 : 22,
            midpointTriggered: false
        )
        recentBosses.append(profile.id)
        stageTicks = 0

        switch profile.id {
        case .iloveyou:
            stage = .iloveyou
            phaseLabel = "1"
        case .wannacry:
            stage = .wannacry
            phaseLabel = "2"
        case .stuxnet:
            stage = .stuxnet
            phaseLabel = "3"
        }

        queueStatus(profile.id.rawValue, detail: profile.openingLine)
    }

    private func updateBoss() {
        guard var boss else { return }

        boss.tickCount += 1
        boss.phase = boss.hp <= boss.maxHP / 3 ? 3 : (boss.hp <= boss.maxHP * 2 / 3 ? 2 : 1)
        boss.primaryCooldown -= 1
        boss.secondaryCooldown -= 1
        boss.utilityCooldown -= 1
        boss.specialCooldown -= 1
        boss.teleportCooldown -= 1

        if !boss.midpointTriggered, let midpointLine = boss.profile.midpointLine, boss.hp <= boss.maxHP / 2 {
            boss.midpointTriggered = true
            queueStatus(boss.profile.id.rawValue, detail: midpointLine)
        }

        switch boss.profile.id {
        case .iloveyou:
            updateILOVEYOUBoss(&boss)
        case .wannacry:
            updateWannaCryBoss(&boss)
        case .stuxnet:
            updateStuxnetBoss(&boss)
        }

        if boss.hp <= 0 {
            self.boss = boss
            finishBossEncounter()
        } else {
            self.boss = boss
        }
    }

    private func updateILOVEYOUBoss(_ boss: inout KernelPanicBossRuntime) {
        boss.y = clamp(4 + ((boss.tickCount / 3) % 5) - 2, lower: 2, upper: KernelPanicConfig.rows - 7)

        if boss.primaryCooldown <= 0 {
            let count = boss.phase == 1 ? 4 : 6
            for offset in 0..<count {
                hostileShots.append(
                    KernelPanicShot(
                        friendly: false,
                        text: "♡",
                        x: boss.x - 1,
                        y: clamp(boss.y + 1 + offset - (count / 2), lower: 0, upper: KernelPanicConfig.rows - 1),
                        dx: -1,
                        dy: offset - (count / 2),
                        damage: 8 + boss.phase,
                        ttl: 14
                    )
                )
            }
            boss.primaryCooldown = boss.phase == 3 ? 3 : 5
        }

        if boss.secondaryCooldown <= 0 {
            for _ in 0..<(boss.phase + 1) {
                hostileShots.append(
                    KernelPanicShot(
                        friendly: false,
                        text: KernelPanicMailSpam.samples[rng.nextInt(in: 0...(KernelPanicMailSpam.samples.count - 1))],
                        x: boss.x - 1,
                        y: clamp(boss.y + rng.nextInt(in: 0...4), lower: 0, upper: KernelPanicConfig.rows - 1),
                        dx: -1,
                        dy: rng.nextInt(in: -1...1),
                        damage: 10 + boss.phase,
                        ttl: 16
                    )
                )
            }
            boss.secondaryCooldown = boss.phase == 3 ? 5 : 7
        }

        if boss.utilityCooldown <= 0 {
            hazards.append(
                KernelPanicHazard(
                    style: .spam,
                    text: rng.nextBool() ? "IWUVYOU" : "MAIL++",
                    x: boss.x - 1,
                    y: clamp(boss.y + rng.nextInt(in: 0...4), lower: 0, upper: KernelPanicConfig.rows - 1),
                    dx: -1,
                    dy: rng.nextBool() ? 1 : -1,
                    width: 7,
                    height: 1,
                    ttl: 12,
                    damage: 12,
                    warningTicks: 0,
                    lowDamage: false
                )
            )
            boss.utilityCooldown = boss.phase == 3 ? 6 : 8
        }
    }

    private func updateWannaCryBoss(_ boss: inout KernelPanicBossRuntime) {
        if boss.teleportCooldown <= 0, boss.phase >= 2 {
            boss.x = rng.nextInt(in: 30...40)
            boss.y = rng.nextInt(in: 2...10)
            boss.teleportCooldown = boss.phase == 3 ? 10 : 15
        }

        if boss.primaryCooldown <= 0 {
            let targetColumn = clamp(player.x + rng.nextInt(in: -2...2), lower: 0, upper: KernelPanicConfig.columns - 1)
            hazards.append(
                KernelPanicHazard(
                    style: .marker,
                    text: "LOCK",
                    x: targetColumn,
                    y: 0,
                    dx: 0,
                    dy: 0,
                    width: 1,
                    height: KernelPanicConfig.rows,
                    ttl: 4,
                    damage: 14,
                    warningTicks: 2,
                    lowDamage: false
                )
            )
            if boss.phase >= 2 {
                let targetRow = clamp(player.y + rng.nextInt(in: -1...1), lower: 0, upper: KernelPanicConfig.rows - 1)
                hazards.append(
                    KernelPanicHazard(
                        style: .marker,
                        text: "LOCK",
                        x: 0,
                        y: targetRow,
                        dx: 0,
                        dy: 0,
                        width: KernelPanicConfig.columns,
                        height: 1,
                        ttl: 4,
                        damage: 14,
                        warningTicks: 2,
                        lowDamage: false
                    )
                )
            }
            boss.primaryCooldown = boss.phase == 3 ? 5 : 7
        }

        if boss.secondaryCooldown <= 0 {
            hazards.append(
                KernelPanicHazard(
                    style: .wall,
                    text: "PAY_NOW",
                    x: KernelPanicConfig.columns - 8,
                    y: rng.nextInt(in: 1...(KernelPanicConfig.rows - 2)),
                    dx: -1,
                    dy: 0,
                    width: 7,
                    height: 1,
                    ttl: 18,
                    damage: 15,
                    warningTicks: 0,
                    lowDamage: false
                )
            )
            if boss.phase >= 2 {
                hazards.append(
                    KernelPanicHazard(
                        style: .wall,
                        text: "###",
                        x: rng.nextInt(in: 18...30),
                        y: 0,
                        dx: 0,
                        dy: 1,
                        width: 3,
                        height: 1,
                        ttl: 14,
                        damage: 13,
                        warningTicks: 0,
                        lowDamage: false
                    )
                )
            }
            boss.secondaryCooldown = boss.phase == 3 ? 6 : 9
        }

        if boss.utilityCooldown <= 0 {
            for _ in 0..<(boss.phase + 1) {
                hazards.append(
                    KernelPanicHazard(
                        style: .cube,
                        text: "[#]",
                        x: boss.x - 1,
                        y: clamp(boss.y + rng.nextInt(in: 0...2), lower: 0, upper: KernelPanicConfig.rows - 1),
                        dx: -1,
                        dy: rng.nextInt(in: -1...1),
                        width: 3,
                        height: 1,
                        ttl: 14,
                        damage: 13,
                        warningTicks: 0,
                        lowDamage: false
                    )
                )
            }
            boss.utilityCooldown = boss.phase == 3 ? 6 : 8
        }
    }

    private func updateStuxnetBoss(_ boss: inout KernelPanicBossRuntime) {
        detailLine = "GLITCH FIELD ACTIVE. FLOOR FIRE ACTIVE."

        if boss.teleportCooldown <= 0 {
            boss.x = rng.nextInt(in: 24...42)
            boss.y = rng.nextInt(in: 1...11)
            boss.teleportCooldown = boss.phase == 3 ? 5 : 8
        }

        if boss.primaryCooldown <= 0 {
            for _ in 0..<(boss.phase == 1 ? 2 : 3) {
                if rng.nextBool() {
                    hazards.append(
                        KernelPanicHazard(
                            style: .marker,
                            text: "SCAN",
                            x: rng.nextInt(in: 6...(KernelPanicConfig.columns - 6)),
                            y: 0,
                            dx: 0,
                            dy: 0,
                            width: 1,
                            height: KernelPanicConfig.rows,
                            ttl: 4,
                            damage: 6,
                            warningTicks: 2,
                            lowDamage: true
                        )
                    )
                } else {
                    hazards.append(
                        KernelPanicHazard(
                            style: .marker,
                            text: "SCAN",
                            x: 0,
                            y: rng.nextInt(in: 1...(KernelPanicConfig.rows - 3)),
                            dx: 0,
                            dy: 0,
                            width: KernelPanicConfig.columns,
                            height: 1,
                            ttl: 4,
                            damage: 6,
                            warningTicks: 2,
                            lowDamage: true
                        )
                    )
                }
            }
            boss.primaryCooldown = boss.phase == 3 ? 3 : 5
        }

        if boss.secondaryCooldown <= 0 {
            hazards.append(
                KernelPanicHazard(
                    style: .segmentation,
                    text: "||||",
                    x: rng.nextInt(in: 18...(KernelPanicConfig.columns - 12)),
                    y: 1,
                    dx: 0,
                    dy: 0,
                    width: 4,
                    height: KernelPanicConfig.rows - 2,
                    ttl: boss.phase == 3 ? 12 : 8,
                    damage: 12,
                    warningTicks: 0,
                    lowDamage: false
                )
            )
            boss.secondaryCooldown = boss.phase == 3 ? 5 : 8
        }

        if boss.utilityCooldown <= 0 {
            for _ in 0..<(boss.phase == 1 ? 1 : 2) {
                hazards.append(
                    KernelPanicHazard(
                        style: .drone,
                        text: "drn",
                        x: boss.x - 1,
                        y: clamp(boss.y + rng.nextInt(in: 0...2), lower: 0, upper: KernelPanicConfig.rows - 1),
                        dx: -1,
                        dy: rng.nextInt(in: -1...1),
                        width: 3,
                        height: 1,
                        ttl: 18,
                        damage: 9,
                        warningTicks: 0,
                        lowDamage: false
                    )
                )
            }
            boss.utilityCooldown = boss.phase == 3 ? 4 : 7
        }

        if boss.specialCooldown <= 0 {
            let strikeRow = clamp(player.y + rng.nextInt(in: -1...1), lower: 0, upper: KernelPanicConfig.rows - 1)
            hazards.append(
                KernelPanicHazard(
                    style: .marker,
                    text: "TRACE",
                    x: 0,
                    y: strikeRow,
                    dx: 0,
                    dy: 0,
                    width: KernelPanicConfig.columns,
                    height: 1,
                    ttl: 4,
                    damage: 7,
                    warningTicks: 2,
                    lowDamage: true
                )
            )
            boss.specialCooldown = boss.phase == 3 ? 4 : 6
        }
    }

    private func detectCollisions() {
        for shotIndex in friendlyShots.indices.reversed() {
            let shot = friendlyShots[shotIndex]
            var consumed = false

            if var boss, rectHit(
                ax: shot.x,
                ay: shot.y,
                aw: max(1, shot.text.count),
                ah: 1,
                bx: boss.x,
                by: boss.y,
                bw: bossArt(for: boss.profile.id).width,
                bh: bossArt(for: boss.profile.id).height
            ) {
                boss.hp -= shot.damage
                self.boss = boss
                consumed = true
                score += 24
            }

            if consumed {
                friendlyShots.remove(at: shotIndex)
            }
        }

        for shotIndex in hostileShots.indices.reversed() {
            let shot = hostileShots[shotIndex]
            if rectHit(
                ax: shot.x,
                ay: shot.y,
                aw: max(1, shot.text.count),
                ah: 1,
                bx: player.x,
                by: player.y,
                bw: 2,
                bh: 1
            ) {
                applyDamage(shot.damage, lowDamage: false)
                hostileShots.remove(at: shotIndex)
            }
        }

        for hazard in hazards {
            guard hazard.warningTicks == 0 else { continue }

            if rectHit(
                ax: player.x,
                ay: player.y,
                aw: 2,
                ah: 1,
                bx: hazard.x,
                by: hazard.y,
                bw: max(1, hazard.width),
                bh: max(1, hazard.height)
            ) {
                applyDamage(hazard.damage, lowDamage: hazard.lowDamage)
            }
        }

        if stage == .stuxnet, player.y >= KernelPanicConfig.rows - 2 {
            applyDamage(4, lowDamage: true)
        }

        if let boss {
            if rectHit(
                ax: player.x,
                ay: player.y,
                aw: 2,
                ah: 1,
                bx: boss.x,
                by: boss.y,
                bw: bossArt(for: boss.profile.id).width,
                bh: bossArt(for: boss.profile.id).height
            ) {
                applyDamage(boss.profile.contactDamage, lowDamage: false)
            }
        }
    }

    private func applyDamage(_ amount: Int, lowDamage: Bool) {
        guard player.invulnerabilityTicks == 0 else { return }

        player.integrity = max(0, player.integrity - amount)
        player.invulnerabilityTicks = lowDamage ? 1 : KernelPanicConfig.playerHitGraceTicks

        if player.integrity == 0 {
            if player.retriesRemaining > 0 {
                player.retriesRemaining -= 1
                player.integrity = KernelPanicConfig.playerMaxHealth
                player.x = 6
                player.y = KernelPanicConfig.rows / 2
                player.invulnerabilityTicks = KernelPanicConfig.playerRespawnGraceTicks
                hostileShots.removeAll()
                hazards.removeAll { $0.style != .segmentation }
                queueStatus("KERNEL RESTORED", detail: "One retry burned. The board is still hostile.")
            } else {
                scene = .gameOver
                queueStatus("KERNEL DOWN", detail: "Press ENTER to reboot the run.")
                updateBestScore()
            }
        }
    }

    private func finishBossEncounter() {
        guard let boss else { return }

        score += boss.profile.maxHealth
        updateBestScore()
        self.boss = nil
        hazards.removeAll()
        hostileShots.removeAll()
        friendlyShots.removeAll()
        player.integrity = max(player.integrity, 72)
        player.invulnerabilityTicks = KernelPanicConfig.playerRespawnGraceTicks

        switch boss.profile.id {
        case .iloveyou:
            stage = .phaseTwoWarmup
            stageTicks = 0
            bossWakeTick = rng.nextInt(in: 76...110)
            phaseLabel = "2"
            queueStatus("MAIL LOOP CUT", detail: boss.profile.defeatLine)

        case .wannacry:
            stage = .phaseThreeFakeout
            stageTicks = 0
            phaseLabel = "3"
            queueStatus("PHASE 3", detail: "IS IT OVER?")

        case .stuxnet:
            stage = .cleared
            scene = .victory
            phaseLabel = "CLR"
            queueStatus("SYSTEM STABLE", detail: boss.profile.defeatLine)
            updateBestScore()
        }
    }

    private func removeExpiredEntities() {
        friendlyShots.removeAll { shot in
            shot.ttl <= 0 ||
            shot.x < -max(shot.text.count, 1) ||
            shot.x > KernelPanicConfig.columns + max(shot.text.count, 1) ||
            shot.y < -1 ||
            shot.y > KernelPanicConfig.rows
        }

        hostileShots.removeAll { shot in
            shot.ttl <= 0 ||
            shot.x < -max(shot.text.count, 1) ||
            shot.x > KernelPanicConfig.columns + max(shot.text.count, 1) ||
            shot.y < -1 ||
            shot.y > KernelPanicConfig.rows
        }

        hazards.removeAll { hazard in
            hazard.ttl <= 0 ||
            hazard.x < -hazard.width - 2 ||
            hazard.x > KernelPanicConfig.columns + 2 ||
            hazard.y < -hazard.height - 2 ||
            hazard.y > KernelPanicConfig.rows + 2
        }
    }

    private func renderBoard() -> [[Character]] {
        var board = Array(
            repeating: Array(repeating: Character(" "), count: KernelPanicConfig.columns),
            count: KernelPanicConfig.rows
        )

        if stage == .phaseThreeFakeout || stage == .stuxnet {
            applyGlitch(to: &board)
        }

        if stage == .stuxnet {
            applyFire(to: &board)
        }

        for hazard in hazards {
            render(hazard: hazard, on: &board)
        }

        for shot in hostileShots {
            place(shot.text, x: shot.x, y: shot.y, on: &board)
        }

        for shot in friendlyShots {
            place(shot.text, x: shot.x, y: shot.y, on: &board)
        }

        if let boss {
            let art = bossArt(for: boss.profile.id).lines
            for (rowOffset, line) in art.enumerated() {
                place(line, x: boss.x, y: boss.y + rowOffset, on: &board)
            }
        }

        let playerGlyph = player.invulnerabilityTicks.isMultiple(of: 2) ? player.facing.glyph : "[]"
        place(playerGlyph, x: player.x, y: player.y, on: &board)

        applySceneText(to: &board)
        return board
    }

    private func render(hazard: KernelPanicHazard, on board: inout [[Character]]) {
        switch hazard.style {
        case .spam, .cube, .drone, .wall:
            place(hazard.text, x: hazard.x, y: hazard.y, on: &board)

        case .beamRow:
            let glyph: Character = hazard.lowDamage ? "-" : "="
            let row = clamp(hazard.y, lower: 0, upper: KernelPanicConfig.rows - 1)
            for column in 0..<KernelPanicConfig.columns {
                board[row][column] = glyph
            }

        case .beamColumn:
            let glyph: Character = hazard.lowDamage ? "|" : "!"
            let column = clamp(hazard.x, lower: 0, upper: KernelPanicConfig.columns - 1)
            for row in 0..<KernelPanicConfig.rows {
                board[row][column] = glyph
            }

        case .marker:
            if hazard.width >= KernelPanicConfig.columns {
                let row = clamp(hazard.y, lower: 0, upper: KernelPanicConfig.rows - 1)
                place("[TRACE]", x: max(0, KernelPanicConfig.columns / 2 - 3), y: row, on: &board)
            } else if hazard.height >= KernelPanicConfig.rows {
                let column = clamp(hazard.x, lower: 0, upper: KernelPanicConfig.columns - 1)
                for row in stride(from: 0, to: KernelPanicConfig.rows, by: 2) {
                    board[row][column] = ":"
                }
                place("LOCK", x: clamp(column - 2, lower: 0, upper: KernelPanicConfig.columns - 4), y: 0, on: &board)
            }

        case .segmentation:
            for row in 0..<min(hazard.height, KernelPanicConfig.rows - hazard.y) {
                place("||||", x: hazard.x, y: hazard.y + row, on: &board)
            }
        }
    }

    private func applyGlitch(to board: inout [[Character]]) {
        let glitchChars: [Character] = ["%", "#", "?", "*", "+"]
        for row in 0..<KernelPanicConfig.rows {
            for column in 0..<KernelPanicConfig.columns {
                guard board[row][column] == " " || board[row][column] == "." else { continue }
                let value = (row * 31 + column * 17 + stageTicks * 7) % 97
                if value == 0 || value == 1 {
                    board[row][column] = glitchChars[(row + column + stageTicks) % glitchChars.count]
                }
            }
        }
    }

    private func applyFire(to board: inout [[Character]]) {
        let fireChars: [Character] = ["^", "~", "^", "~", "!", "^"]
        for row in max(0, KernelPanicConfig.rows - 2)..<KernelPanicConfig.rows {
            for column in 0..<KernelPanicConfig.columns {
                if (column + row + stageTicks).isMultiple(of: 2) {
                    board[row][column] = fireChars[(column + stageTicks) % fireChars.count]
                }
            }
        }

        let fireWordX = max(0, (stageTicks * 3) % max(1, KernelPanicConfig.columns - 8))
        place("FIRE_FIRE", x: fireWordX, y: KernelPanicConfig.rows - 1, on: &board)
    }

    private func applySceneText(to board: inout [[Character]]) {
        switch scene {
        case .title:
            center(
                [
                    "KERNEL PANIC",
                    "",
                    "BATTLE BOX ARMED",
                    "NO LOCK-ON / THREE SHOTS MAX",
                    "",
                    "PRESS ENTER",
                ],
                on: &board
            )

        case .paused:
            center(["TIME FROZEN", "", "P / ENTER / SPACE TO RESUME"], on: &board)

        case .gameOver:
            center(["KERNEL DOWN", "", "ENTER TO REBOOT"], on: &board)

        case .victory:
            center(["SYSTEM STABLE", "", "ENTER TO RUN IT AGAIN"], on: &board)

        case .playing:
            if stage == .phaseThreeFakeout {
                center(["IS IT OVER?"], on: &board, verticalOffset: -3)
            }
        }
    }

    private func center(_ lines: [String], on board: inout [[Character]], verticalOffset: Int = 0) {
        let totalHeight = lines.count
        let startY = max(0, (KernelPanicConfig.rows - totalHeight) / 2 + verticalOffset)
        for (index, line) in lines.enumerated() {
            let startX = max(0, (KernelPanicConfig.columns - line.count) / 2)
            place(line, x: startX, y: startY + index, on: &board)
        }
    }

    private func place(_ text: String, x: Int, y: Int, on board: inout [[Character]]) {
        guard board.indices.contains(y) else { return }

        for (offset, character) in text.enumerated() {
            let column = x + offset
            guard board[y].indices.contains(column) else { continue }
            board[y][column] = character
        }
    }

    private func sceneFooter() -> String {
        switch scene {
        case .title:
            return "MOVE WASD/ARROWS   FIRE SPACE   PAUSE P   HELP H"
        case .paused:
            return "PAUSED"
        case .gameOver:
            return "LAST SCORE \(formattedScore(score))   BEST \(formattedScore(bestScore))"
        case .victory:
            return "TOTAL SCORE \(formattedScore(score))   BEST \(formattedScore(bestScore))"
        case .playing:
            return "MOVE WASD/ARROWS   FIRE SPACE   NO LOCK-ON"
        }
    }

    private func queueStatus(_ status: String, detail: String, ticks: Int = 20) {
        statusLine = status
        detailLine = detail
        statusTicks = ticks
    }

    private func syncMusicCue() {
        switch scene {
        case .title, .gameOver, .victory:
            musicCue = .silence
            return
        case .paused, .playing:
            break
        }

        switch stage {
        case .phaseOneWarmup, .iloveyou:
            musicCue = .phaseOne
        case .phaseTwoWarmup, .wannacry:
            musicCue = .phaseTwo
        case .phaseThreeFakeout, .cleared:
            musicCue = .silence
        case .stuxnet:
            musicCue = .phaseThree
        }
    }

    private func updateBestScore() {
        guard score > bestScore else { return }
        bestScore = score
        UserDefaults.standard.set(score, forKey: KernelPanicPreferences.bestScoreKey)
    }

    private func advanceCurrentPlayableStage() {
        switch stage {
        case .phaseOneWarmup:
            spawnBoss(.iloveyou)
            queueStatus("PHASE SKIPPED", detail: "Boss 1 forced online.")
        case .iloveyou:
            boss?.hp = 0
            finishBossEncounter()
        case .phaseTwoWarmup:
            spawnBoss(.wannacry)
            queueStatus("PHASE SKIPPED", detail: "Boss 2 forced online.")
        case .wannacry:
            boss?.hp = 0
            finishBossEncounter()
        case .phaseThreeFakeout:
            stageTicks = 20
            updateStage()
            queueStatus("PHASE SKIPPED", detail: "The fake silence breaks early.")
        case .stuxnet:
            boss?.hp = 0
            finishBossEncounter()
        case .cleared:
            break
        }
    }

    private func formattedScore(_ value: Int) -> String {
        String(format: "%06d", max(0, min(value, 999_999)))
    }

    private func padded(_ value: Int, width: Int) -> String {
        String(format: "%0\(width)d", value)
    }

    private func fit(_ text: String) -> String {
        if text.count >= KernelPanicConfig.columns {
            return String(text.prefix(KernelPanicConfig.columns))
        }
        return text + String(repeating: " ", count: KernelPanicConfig.columns - text.count)
    }

    #if DEBUG
    var debugVisitedBosses: [KernelPanicBossID] { recentBosses }

    func debugCompleteCurrentStage() {
        switch scene {
        case .title, .gameOver, .victory:
            handlePrimaryAction()
        case .paused:
            scene = .playing
        case .playing:
            advanceCurrentPlayableStage()
        }
    }
    #endif
}

private struct KernelPanicCodePayload {
    static let samples = [
        "ret0;",
        "vec<T>",
        "if(ptr)",
        "nullptr",
        "tmpl<T>",
        "for(;;)",
        "std::{}",
        "move()",
    ]
}

private struct KernelPanicMailSpam {
    static let samples = [
        "iwuvyou",
        "re: hi",
        "mail++",
        "white♡",
        "seen?",
        "read_me",
    ]
}

private struct KernelPanicArtSize {
    let width: Int
    let height: Int
    let lines: [String]
}

private func bossArt(for identifier: KernelPanicBossID) -> KernelPanicArtSize {
    let lines: [String]
    switch identifier {
    case .iloveyou:
        lines = [
            " .-LOVE-MAIL-. ",
            "| ♡  spam  ♡ |",
            "|  IWUVYOU++ |",
            " `-__mail__-' ",
        ]
    case .wannacry:
        lines = [
            " .-WANNACRY-. ",
            "| LOCK |||| |",
            "| PAY  [#]  |",
            "`-__ERROR__-'",
        ]
    case .stuxnet:
        lines = [
            "   .-==-.    ",
            " .<| 00 |>.  ",
            " |:|_[]_|:|  ",
            "  \\_====_/   ",
        ]
    }

    return KernelPanicArtSize(
        width: lines.map(\.count).max() ?? 0,
        height: lines.count,
        lines: lines
    )
}

private func rectHit(ax: Int, ay: Int, aw: Int, ah: Int, bx: Int, by: Int, bw: Int, bh: Int) -> Bool {
    let aRight = ax + aw - 1
    let aBottom = ay + ah - 1
    let bRight = bx + bw - 1
    let bBottom = by + bh - 1

    return ax <= bRight && aRight >= bx && ay <= bBottom && aBottom >= by
}

private func clamp(_ value: Int, lower: Int, upper: Int) -> Int {
    min(max(value, lower), upper)
}

private enum KernelPanicPalette {
    static let ink = Color.black
    static let paper = Color.white
    static let mutedPaper = Color.white.opacity(0.66)
    static let faintPaper = Color.white.opacity(0.18)
    static let glitch = Color.white.opacity(0.5)
    static let accent = Color(red: 1.0, green: 0.79, blue: 0.18)
    static let ember = Color(red: 1.0, green: 0.44, blue: 0.16)
}

private enum KernelPanicCommandID: String {
    case boot = "BOOT"
    case move = "MOVE"
    case purge = "PURGE"
    case pause = "PAUSE"

    var hint: String {
        switch self {
        case .boot:
            return "ENTER"
        case .move:
            return "WASD"
        case .purge:
            return "SPACE"
        case .pause:
            return "P"
        }
    }
}

struct KernelPanicArcade: View {
    @StateObject private var model = KernelPanicGameModel()
    @State private var musicPlayer = KernelPanicMusicPlayer()
    @StateObject private var keyboardMonitor = KernelPanicKeyboardMonitor()

    private let timer = Timer.publish(every: 1.0 / KernelPanicConfig.fps, on: .main, in: .common).autoconnect()

    static func scoreString(_ value: Int) -> String {
        String(format: "%06d", max(0, min(value, 999_999)))
    }

    private var activeCommand: KernelPanicCommandID {
        if model.scene == .paused {
            return .pause
        }

        switch model.scene {
        case .title, .gameOver, .victory:
            return .boot
        case .paused:
            return .pause
        case .playing:
            return model.boss == nil ? .move : .purge
        }
    }

    var body: some View {
        ZStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 16) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("KERNEL PANIC")
                            .font(.system(size: 24, weight: .black, design: .monospaced))
                            .foregroundStyle(KernelPanicPalette.paper)
                        Text("ORIGINAL MONOCHROME BATTLE-SCREEN PANIC")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(KernelPanicPalette.mutedPaper)
                    }

                    Spacer(minLength: 12)

                    HStack(spacing: 16) {
                        kernelStat(label: "PHASE", value: model.phaseLabel)
                        kernelStat(label: "SCORE", value: Self.scoreString(model.score))
                        kernelStat(label: "FACE", value: model.player.facing.facingName)
                    }
                }

                VStack(spacing: 6) {
                    Text(model.portraitArt.joined(separator: "\n"))
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.paper)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 2)

                    HStack(alignment: .center, spacing: 10) {
                        Text(model.portraitLabel)
                            .font(.system(size: 12, weight: .black, design: .monospaced))
                            .foregroundStyle(KernelPanicPalette.paper)

                        if model.boss != nil {
                            KernelPanicBossBar(
                                label: model.boss?.profile.id.rawValue.uppercased() ?? "",
                                value: model.bossHealthFraction
                            )
                            .frame(width: 280)
                        } else {
                            Rectangle()
                                .fill(KernelPanicPalette.faintPaper)
                                .frame(height: 2)
                        }

                        Text("RET \(model.player.retriesRemaining)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(KernelPanicPalette.mutedPaper)
                    }

                    Text(model.combatCaption.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.mutedPaper)
                        .frame(maxWidth: .infinity, alignment: .center)
                }

                KernelPanicPixelPanel(content: {
                    KernelPanicBattleGridView(grid: model.displayGrid)
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
                }, padding: 12)
                .frame(maxWidth: .infinity)
                .frame(height: 290)

                KernelPanicDialoguePanel(
                    status: model.statusLine,
                    detail: model.detailLine,
                    face: model.player.facing.facingName,
                    integrity: model.player.integrity,
                    integrityFraction: model.integrityFraction,
                    retries: model.player.retriesRemaining,
                    footer: model.showHelp ? "H TO CLOSE HELP" : "SPACE PURGES   P PAUSES   H SHOWS HELP"
                )

                HStack(alignment: .center, spacing: 8) {
                    KernelPanicCommandStrip(active: activeCommand)

                    Button(action: model.skipCurrentPhase) {
                        KernelPanicSkipButton(enabled: model.canSkipPhase)
                    }
                    .buttonStyle(.plain)
                    .disabled(!model.canSkipPhase)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(14)
            .background(KernelPanicPalette.ink)
            .overlay(
                Rectangle()
                    .strokeBorder(KernelPanicPalette.paper, lineWidth: 3)
            )
            .overlay(
                Rectangle()
                    .inset(by: 7)
                    .strokeBorder(KernelPanicPalette.faintPaper, lineWidth: 1)
            )

            if model.showHelp {
                Color.black.opacity(0.76)

                KernelPanicPixelPanel(content: {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("HELP // KERNEL PANIC")
                            .font(.system(size: 16, weight: .black, design: .monospaced))
                            .foregroundStyle(KernelPanicPalette.paper)

                        Group {
                            Text("* MOVE WITH WASD OR THE ARROW KEYS.")
                            Text("* PRESS SPACE TO FIRE. THE BUFFER CAPS AT THREE SHOTS.")
                            Text("* FACE THE DIRECTION YOU WANT TO SHOOT LAST.")
                            Text("* PRESS P TO PAUSE AND H TO TOGGLE THIS BOX.")
                            Text("* NONE OF THE BOSSES DO ANYTHING REAL. THEY ONLY PANIC ONSCREEN.")
                        }
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.paper)

                        Text("PRESS H TO DROP BACK INTO THE BOX.")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(KernelPanicPalette.accent)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }, padding: 16)
                .frame(width: 470)
            }
        }
        .onReceive(timer) { date in
            model.tick(at: date)
        }
        .onAppear {
            musicPlayer.play(cue: model.musicCue)
            keyboardMonitor.install(
                onPrimaryAction: model.handlePrimaryAction,
                onSpacePressed: model.handleSpacePressed,
                onSpaceReleased: model.handleSpaceReleased,
                onPauseToggle: model.togglePause,
                onHelpToggle: model.toggleHelp,
                onMoveUp: model.setMoveUp(_:),
                onMoveDown: model.setMoveDown(_:),
                onMoveLeft: model.setMoveLeft(_:),
                onMoveRight: model.setMoveRight(_:)
            )
        }
        .onChange(of: model.musicCue) { cue in
            if model.scene == .paused {
                return
            }
            musicPlayer.play(cue: cue)
        }
        .onChange(of: model.scene) { scene in
            switch scene {
            case .paused:
                musicPlayer.pause()
            case .playing:
                musicPlayer.resume(cue: model.musicCue)
            case .title, .gameOver, .victory:
                musicPlayer.stop()
            }
        }
        .onDisappear {
            musicPlayer.stop()
            keyboardMonitor.remove()
        }
    }

    private func kernelStat(label: String, value: String) -> some View {
        VStack(alignment: .trailing, spacing: 2) {
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(KernelPanicPalette.mutedPaper)
            Text(value)
                .font(.system(size: 14, weight: .black, design: .monospaced))
                .foregroundStyle(KernelPanicPalette.paper)
        }
    }
}

private struct KernelPanicPixelPanel<Content: View>: View {
    @ViewBuilder var content: Content
    var padding: CGFloat = 12

    var body: some View {
        ZStack {
            KernelPanicPalette.ink
            content
                .padding(padding)
        }
        .overlay(
            Rectangle()
                .strokeBorder(KernelPanicPalette.paper, lineWidth: 3)
        )
        .overlay(alignment: .topLeading) {
            Rectangle()
                .fill(KernelPanicPalette.paper)
                .frame(width: 7, height: 7)
        }
        .overlay(alignment: .topTrailing) {
            Rectangle()
                .fill(KernelPanicPalette.paper)
                .frame(width: 7, height: 7)
        }
        .overlay(alignment: .bottomLeading) {
            Rectangle()
                .fill(KernelPanicPalette.paper)
                .frame(width: 7, height: 7)
        }
        .overlay(alignment: .bottomTrailing) {
            Rectangle()
                .fill(KernelPanicPalette.paper)
                .frame(width: 7, height: 7)
        }
    }
}

private enum KernelPanicGlyphTone {
    case plain
    case dim
    case glitch
    case fire
    case kernel

    var color: Color {
        switch self {
        case .plain:
            return KernelPanicPalette.paper
        case .dim:
            return KernelPanicPalette.faintPaper
        case .glitch:
            return KernelPanicPalette.glitch
        case .fire:
            return KernelPanicPalette.ember
        case .kernel:
            return KernelPanicPalette.accent
        }
    }
}

private struct KernelPanicBossBar: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.system(size: 11, weight: .black, design: .monospaced))
                .foregroundStyle(KernelPanicPalette.paper)

            Text("HP")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(KernelPanicPalette.accent)

            KernelPanicMeterBar(
                value: value,
                fillColor: KernelPanicPalette.accent,
                emptyColor: KernelPanicPalette.paper.opacity(0.14),
                strokeColor: KernelPanicPalette.paper
            )
            .frame(height: 12)
        }
    }
}

private struct KernelPanicDialoguePanel: View {
    let status: String
    let detail: String
    let face: String
    let integrity: Int
    let integrityFraction: Double
    let retries: Int
    let footer: String

    var body: some View {
        KernelPanicPixelPanel(content: {
            VStack(alignment: .leading, spacing: 10) {
                Text("* \(detail)")
                    .font(.system(size: 13, weight: .black, design: .monospaced))
                    .foregroundStyle(KernelPanicPalette.paper)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(alignment: .center, spacing: 10) {
                    Text(status.uppercased())
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.mutedPaper)

                    Spacer(minLength: 6)

                    Text("FACE \(face)")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.mutedPaper)
                }

                HStack(alignment: .center, spacing: 10) {
                    Text("KRNL")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.paper)

                    KernelPanicMeterBar(
                        value: integrityFraction,
                        fillColor: KernelPanicPalette.accent,
                        emptyColor: KernelPanicPalette.paper.opacity(0.14),
                        strokeColor: KernelPanicPalette.paper
                    )
                    .frame(width: 140, height: 12)

                    Text("\(integrity) / \(KernelPanicConfig.playerMaxHealth)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.paper)

                    Spacer(minLength: 6)

                    Text("RET \(retries)")
                        .font(.system(size: 11, weight: .black, design: .monospaced))
                        .foregroundStyle(KernelPanicPalette.paper)
                }

                Text(footer)
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundStyle(KernelPanicPalette.mutedPaper)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }, padding: 14)
    }
}

private struct KernelPanicMeterBar: View {
    let value: Double
    let fillColor: Color
    let emptyColor: Color
    let strokeColor: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle()
                    .fill(emptyColor)
                Rectangle()
                    .fill(fillColor)
                    .frame(width: proxy.size.width * max(0, min(value, 1)))
            }
            .overlay(
                Rectangle()
                    .strokeBorder(strokeColor, lineWidth: 2)
            )
        }
    }
}

private struct KernelPanicCommandStrip: View {
    let active: KernelPanicCommandID

    var body: some View {
        HStack(spacing: 8) {
            ForEach(
                [KernelPanicCommandID.boot, .move, .purge, .pause],
                id: \.rawValue
            ) { command in
                KernelPanicCommandCell(
                    title: command.rawValue,
                    hint: command.hint,
                    active: command == active
                )
            }
        }
    }
}

private struct KernelPanicSkipButton: View {
    let enabled: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text("SKIP")
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(enabled ? KernelPanicPalette.ink : KernelPanicPalette.mutedPaper)
            Text("PHASE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(enabled ? KernelPanicPalette.ink.opacity(0.72) : KernelPanicPalette.faintPaper)
        }
        .frame(width: 86)
        .padding(.vertical, 8)
        .background(enabled ? KernelPanicPalette.paper : KernelPanicPalette.ink)
        .overlay(
            Rectangle()
                .strokeBorder(enabled ? KernelPanicPalette.paper : KernelPanicPalette.mutedPaper, lineWidth: 3)
        )
    }
}

private struct KernelPanicCommandCell: View {
    let title: String
    let hint: String
    let active: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 12, weight: .black, design: .monospaced))
                .foregroundStyle(active ? KernelPanicPalette.ink : KernelPanicPalette.paper)
            Text(hint)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(active ? KernelPanicPalette.ink.opacity(0.72) : KernelPanicPalette.mutedPaper)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(active ? KernelPanicPalette.accent : KernelPanicPalette.ink)
        .overlay(
            Rectangle()
                .strokeBorder(active ? KernelPanicPalette.accent : KernelPanicPalette.paper, lineWidth: 3)
        )
    }
}

private struct KernelPanicBattleGridView: View {
    let grid: [[Character]]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(grid.enumerated()), id: \.offset) { _, row in
                rowText(for: row)
                    .font(.system(size: 10, weight: .black, design: .monospaced))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func rowText(for row: [Character]) -> Text {
        let runs = glyphRuns(for: row)
        guard let first = runs.first else {
            return Text("")
        }

        return runs.dropFirst().reduce(
            Text(first.text).foregroundColor(first.color)
        ) { partial, run in
            partial + Text(run.text).foregroundColor(run.color)
        }
    }

    private func glyphRuns(for row: [Character]) -> [(text: String, color: Color)] {
        var runs: [(String, Color)] = []
        var current = ""
        var currentTone: KernelPanicGlyphTone?

        for glyph in row {
            let tone = glyphTone(for: glyph)
            if currentTone == nil || currentTone! != tone {
                if !current.isEmpty, let currentTone {
                    runs.append((current, currentTone.color))
                }
                current = String(glyph)
                currentTone = tone
            } else {
                current.append(glyph)
            }
        }

        if !current.isEmpty, let currentTone {
            runs.append((current, currentTone.color))
        }

        return runs
    }

    private func glyphTone(for glyph: Character) -> KernelPanicGlyphTone {
        switch glyph {
        case " ":
            return .plain
        case ".":
            return .dim
        case "%", "#", "?", "*", "+":
            return .glitch
        case "^", "~", "!":
            return .fire
        case "♡":
            return .plain
        case "<", ">", "[", "]":
            return .kernel
        case ":", "|", "=":
            return .plain
        default:
            return .plain
        }
    }
}

private func kernelPanicPortraitArt(
    scene: KernelPanicScene,
    stage: KernelPanicStage,
    bossID: KernelPanicBossID?
) -> [String] {
    if let bossID {
        switch bossID {
        case .iloveyou:
            return [
                "       .--------.       ",
                "     .`  ____    `.     ",
                "    /_.-`♡  ♡`-._\\    ",
                "    ||  ILOVEYOU  ||    ",
                "    ||  white♡♡  ||    ",
                "    ||  spam++   ||    ",
                "    ||___________||    ",
            ]
        case .wannacry:
            return [
                "      .____________.      ",
                "     / !! WARNING !!\\     ",
                "    / [LOCK][LOCK]  \\    ",
                "    |   PAY_NOW!!!  |     ",
                "    |  [#] [#] [#]  |     ",
                "    |___FILEBLOCK___|     ",
            ]
        case .stuxnet:
            return [
                "        .-====-.        ",
                "      .<| 00  |>.       ",
                "      |||::::|||        ",
                "      |||[##]|||        ",
                "      |||::::|||        ",
                "      '\\_====_/'        ",
            ]
        }
    }

    switch scene {
    case .title:
        return [
            "       __________       ",
            "      / ________ \\      ",
            "     / /  KRNL  \\ \\     ",
            "     | |  <> <> | |     ",
            "     | |  BOOT  | |     ",
            "     |_|________|_|     ",
        ]
    case .paused:
        return [
            "       __________       ",
            "      |  ||  ||  |      ",
            "      |  PAUSED  |      ",
            "      |__||__||__|      ",
        ]
    case .gameOver:
        return [
            "       __________       ",
            "      /  x    x  \\      ",
            "     |   KERNEL   |     ",
            "     |    DOWN    |     ",
            "     |____________|     ",
        ]
    case .victory:
        return [
            "       __________       ",
            "      /  ^    ^  \\      ",
            "     |   STABLE   |     ",
            "     |    CLEAR   |     ",
            "     |____________|     ",
        ]
    case .playing:
        switch stage {
        case .phaseOneWarmup:
            return [
                "       __________       ",
                "      / inbox::::\\      ",
                "     |  signal+++ |     ",
                "     |  white♡♡  |     ",
                "     |____________|     ",
            ]
        case .phaseTwoWarmup:
            return [
                "       __________       ",
                "      / locklock \\      ",
                "     |  note wall |     ",
                "     |  [#] [#]   |     ",
                "     |____________|     ",
            ]
        case .phaseThreeFakeout:
            return [
                "       ..........       ",
                "      ..        ..      ",
                "      ..  ??    ..      ",
                "      ..        ..      ",
                "       ..........       ",
            ]
        case .iloveyou, .wannacry, .stuxnet:
            return []
        case .cleared:
            return [
                "       __________       ",
                "      / stable:: \\      ",
                "     |  field low |     ",
                "     |   all calm |     ",
                "     |____________|     ",
            ]
        }
    }
}

private final class KernelPanicKeyboardMonitor: ObservableObject {
    private var keyDownMonitor: Any?
    private var keyUpMonitor: Any?
    private var onPrimaryAction: (() -> Void)?
    private var onSpacePressed: (() -> Void)?
    private var onSpaceReleased: (() -> Void)?
    private var onPauseToggle: (() -> Void)?
    private var onHelpToggle: (() -> Void)?
    private var onMoveUp: ((Bool) -> Void)?
    private var onMoveDown: ((Bool) -> Void)?
    private var onMoveLeft: ((Bool) -> Void)?
    private var onMoveRight: ((Bool) -> Void)?

    func install(
        onPrimaryAction: @escaping () -> Void,
        onSpacePressed: @escaping () -> Void,
        onSpaceReleased: @escaping () -> Void,
        onPauseToggle: @escaping () -> Void,
        onHelpToggle: @escaping () -> Void,
        onMoveUp: @escaping (Bool) -> Void,
        onMoveDown: @escaping (Bool) -> Void,
        onMoveLeft: @escaping (Bool) -> Void,
        onMoveRight: @escaping (Bool) -> Void
    ) {
        guard keyDownMonitor == nil, keyUpMonitor == nil else { return }

        self.onPrimaryAction = onPrimaryAction
        self.onSpacePressed = onSpacePressed
        self.onSpaceReleased = onSpaceReleased
        self.onPauseToggle = onPauseToggle
        self.onHelpToggle = onHelpToggle
        self.onMoveUp = onMoveUp
        self.onMoveDown = onMoveDown
        self.onMoveLeft = onMoveLeft
        self.onMoveRight = onMoveRight

        keyDownMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handleKeyDown(event) ?? event
        }

        keyUpMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyUp) { [weak self] event in
            self?.handleKeyUp(event) ?? event
        }
    }

    func remove() {
        if let keyDownMonitor {
            NSEvent.removeMonitor(keyDownMonitor)
            self.keyDownMonitor = nil
        }

        if let keyUpMonitor {
            NSEvent.removeMonitor(keyUpMonitor)
            self.keyUpMonitor = nil
        }

        onPrimaryAction = nil
        onSpacePressed = nil
        onSpaceReleased = nil
        onPauseToggle = nil
        onHelpToggle = nil
        onMoveUp = nil
        onMoveDown = nil
        onMoveLeft = nil
        onMoveRight = nil
    }

    deinit {
        remove()
    }

    private func handleKeyDown(_ event: NSEvent) -> NSEvent? {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
            return event
        }

        switch event.keyCode {
        case 13, 126:
            onMoveUp?(true)
            return nil
        case 1, 125:
            onMoveDown?(true)
            return nil
        case 0, 123:
            onMoveLeft?(true)
            return nil
        case 2, 124:
            onMoveRight?(true)
            return nil
        case 49:
            if !event.isARepeat {
                onSpacePressed?()
            }
            return nil
        case 36, 76:
            if !event.isARepeat {
                onPrimaryAction?()
            }
            return nil
        case 35, 53:
            if !event.isARepeat {
                onPauseToggle?()
            }
            return nil
        case 4:
            if !event.isARepeat {
                onHelpToggle?()
            }
            return nil
        default:
            return event
        }
    }

    private func handleKeyUp(_ event: NSEvent) -> NSEvent? {
        guard event.modifierFlags.intersection(.deviceIndependentFlagsMask).isEmpty else {
            return event
        }

        switch event.keyCode {
        case 13, 126:
            onMoveUp?(false)
            return nil
        case 1, 125:
            onMoveDown?(false)
            return nil
        case 0, 123:
            onMoveLeft?(false)
            return nil
        case 2, 124:
            onMoveRight?(false)
            return nil
        case 49:
            onSpaceReleased?()
            return nil
        default:
            return event
        }
    }
}
