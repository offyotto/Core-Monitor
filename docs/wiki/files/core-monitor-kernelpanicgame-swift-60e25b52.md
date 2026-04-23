# File: Core-Monitor/KernelPanicGame.swift

## Current Role

- Implements the Kernel Panic parody game model and SwiftUI arcade surface.
- This is intentionally fictional and must not drift into real malware behavior.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Core-Monitor/KernelPanicGame.swift`](../../../Core-Monitor/KernelPanicGame.swift) |
| Wiki area | Kernel Panic / Weird Mode |
| Exists in current checkout | True |
| Size | 77953 bytes |
| Binary | False |
| Line count | 2392 |
| Extension | `.swift` |

## Imports

`AppKit`, `Combine`, `SwiftUI`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| enum | `KernelPanicBossID` | 4 |
| enum | `KernelPanicMechanic` | 12 |
| struct | `KernelPanicBossProfile` | 27 |
| enum | `KernelPanicScene` | 83 |
| enum | `KernelPanicStage` | 91 |
| enum | `KernelPanicConfig` | 101 |
| enum | `KernelPanicDirection` | 114 |
| struct | `KernelPanicPlayer` | 150 |
| struct | `KernelPanicShot` | 160 |
| enum | `KernelPanicHazardStyle` | 172 |
| struct | `KernelPanicHazard` | 183 |
| struct | `KernelPanicBossRuntime` | 199 |
| struct | `KernelPanicInputState` | 215 |
| struct | `KernelPanicRNG` | 223 |
| class | `KernelPanicGameModel` | 246 |
| func | `tick` | 400 |
| func | `handlePrimaryAction` | 405 |
| func | `handleSpacePressed` | 418 |
| func | `handleSpaceReleased` | 428 |
| func | `setMoveUp` | 432 |
| func | `setMoveDown` | 434 |
| func | `setMoveLeft` | 435 |
| func | `setMoveRight` | 436 |
| func | `togglePause` | 437 |
| func | `toggleHelp` | 452 |
| func | `skipCurrentPhase` | 456 |
| func | `startCampaign` | 461 |
| func | `step` | 486 |
| func | `updatePlayer` | 508 |
| func | `attemptFire` | 544 |
| func | `updateShots` | 569 |
| func | `updateHazards` | 583 |
| func | `updateStage` | 639 |
| func | `spawnPhaseOneNoise` | 679 |
| func | `spawnPhaseTwoNoise` | 709 |
| func | `spawnBoss` | 743 |
| func | `updateBoss` | 781 |
| func | `updateILOVEYOUBoss` | 814 |
| func | `updateWannaCryBoss` | 875 |
| func | `updateStuxnetBoss` | 983 |
| func | `detectCollisions` | 1097 |
| func | `applyDamage` | 1177 |
| func | `finishBossEncounter` | 1201 |
| func | `removeExpiredEntities` | 1236 |
| func | `renderBoard` | 1262 |
| func | `render` | 1302 |
| func | `applyGlitch` | 1340 |
| func | `applyFire` | 1353 |
| func | `applySceneText` | 1367 |
| func | `center` | 1398 |
| func | `place` | 1407 |
| func | `sceneFooter` | 1417 |
| func | `queueStatus` | 1432 |
| func | `syncMusicCue` | 1438 |
| func | `updateBestScore` | 1459 |
| func | `advanceCurrentPlayableStage` | 1465 |
| func | `formattedScore` | 1491 |
| func | `padded` | 1495 |
| func | `fit` | 1499 |
| func | `debugCompleteCurrentStage` | 1509 |
| struct | `KernelPanicCodePayload` | 1522 |
| struct | `KernelPanicMailSpam` | 1535 |
| struct | `KernelPanicArtSize` | 1546 |
| func | `bossArt` | 1552 |
| func | `rectHit` | 1585 |
| func | `clamp` | 1594 |
| enum | `KernelPanicPalette` | 1598 |
| enum | `KernelPanicCommandID` | 1608 |
| struct | `KernelPanicArcade` | 1628 |
| func | `kernelStat` | 1819 |
| struct | `KernelPanicPixelPanel` | 1831 |
| enum | `KernelPanicGlyphTone` | 1868 |
| struct | `KernelPanicBossBar` | 1891 |
| struct | `KernelPanicDialoguePanel` | 1916 |
| struct | `KernelPanicMeterBar` | 1978 |
| struct | `KernelPanicCommandStrip` | 2001 |
| struct | `KernelPanicSkipButton` | 2020 |
| struct | `KernelPanicCommandCell` | 2042 |
| struct | `KernelPanicBattleGridView` | 2066 |
| func | `rowText` | 2080 |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
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
```
