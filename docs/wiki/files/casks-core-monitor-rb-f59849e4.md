# File: Casks/core-monitor.rb

## Current Role

- Area: Homebrew distribution.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Casks/core-monitor.rb`](../../../Casks/core-monitor.rb) |
| Wiki area | Homebrew distribution |
| Exists in current checkout | True |
| Size | 717 bytes |
| Binary | False |
| Line count | 23 |
| Extension | `.rb` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `4dc3880` | 2026-04-21 | Update GitHub username references |
| `aca5d59` | 2026-04-19 | Add Kernel Panic release payload |
| `210356e` | 2026-04-19 | Add Kernel Panic release payload |
| `b6b878b` | 2026-04-17 | Update core-monitor.rb |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
cask "core-monitor" do
  version :latest
  sha256 :no_check

  url "https://github.com/offyotto/Core-Monitor/releases/latest/download/Core-Monitor.app.zip",
      verified: "github.com/offyotto/Core-Monitor/"
  name "Core-Monitor"
  desc "Native Apple Silicon system monitor with menu bar stats, alerts, and SMC-backed fan control"
  homepage "https://offyotto.github.io/Core-Monitor/"

  depends_on arch: :arm64
  depends_on macos: ">= :monterey"

  app "Core-Monitor.app"

  zap trash: [
    "~/Library/Application Support/Core-Monitor",
    "~/Library/Caches/Core-Monitor",
    "~/Library/Preferences/CoreTools.Core-Monitor.plist",
    "~/Library/Saved Application State/CoreTools.Core-Monitor.savedState"
  ]
end
```
