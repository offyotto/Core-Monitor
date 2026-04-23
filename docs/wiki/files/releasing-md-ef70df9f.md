# File: RELEASING.md

## Current Role

- Source-controlled release checklist for test-first, signed, notarized DMG/ZIP distribution and Homebrew cask publishing.
- Use this before tags or public artifacts because release trust is central to a privileged-helper utility.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`RELEASING.md`](../../../RELEASING.md) |
| Wiki area | Repository support |
| Exists in current checkout | True |
| Size | 5403 bytes |
| Binary | False |
| Line count | 114 |
| Extension | `.md` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `171c3c6` | 2026-04-22 | Install archive provisioning profile for release CI |
| `4dc3880` | 2026-04-21 | Update GitHub username references |
| `69cc386` | 2026-04-18 | Add DMG release packaging |
| `3fe35bf` | 2026-04-18 | Add DMG release packaging |
| `675fabf` | 2026-04-17 | Ship 14.0.5 helper recovery release |
| `5b26198` | 2026-04-17 | Align release asset and add Homebrew guide |
| `8bfc685` | 2026-04-16 | Stabilize signing and WeatherKit release packaging |
| `ef6fa04` | 2026-04-16 | Fix Homebrew install docs |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
# Releasing Core-Monitor

Core-Monitor is not a throwaway unsigned zip anymore. The release path in this repository is built around three requirements:

1. Every public build should pass the macOS test suite first.
2. Every downloadable app should be Developer ID signed and notarized.
3. Every channel should point to the same stable artifact names: `Core-Monitor.dmg` for normal installs and `Core-Monitor.app.zip` for archive-friendly installs.

## Release channels

- GitHub Releases: primary source of truth, public changelog, checksums, and pinned Homebrew cask artifact.
- Website: the main download buttons should point to `releases/latest/download/Core-Monitor.dmg`, and the install section should also surface `releases/latest/download/Core-Monitor.app.zip`.
- Homebrew: this repository acts as a custom tap; users should tap it first, then install `offyotto/core-monitor/core-monitor`.
- Direct support/install docs: README, website, and release notes should present DMG as the standard drag-to-Applications path and ZIP as the fallback/manual path.

## GitHub Actions secrets

The release workflow expects these repository or organization secrets:

- `BUILD_CERTIFICATE_BASE64`: base64-encoded Developer ID Application `.p12`
- `P12_PASSWORD`: password for the `.p12`
- `KEYCHAIN_PASSWORD`: temporary keychain password used on the runner
- `WEATHERKIT_PROVISIONING_PROFILE_BASE64`: base64-encoded `Mac Team Direct Provisioning Profile: CoreTools.Core-Monitor`
- `APPLE_TEAM_ID`: Apple Developer team id when using Apple ID notarization
- For notarization, configure one of these:
- `APP_STORE_CONNECT_API_KEY_BASE64`
- `APP_STORE_CONNECT_KEY_ID`
- `APP_STORE_CONNECT_ISSUER_ID`
- Or both:
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`

Do not rely on a bare `NOTARYTOOL_PROFILE` secret on GitHub Actions. A profile name alone does not recreate the runner keychain entry. Either provide Apple ID credentials so the workflow can create the profile on the runner, or provide an App Store Connect API key.

## Standard release flow

1. Update the changelog-worthy product copy in the README and website if the release shifts positioning or install instructions.
2. Make sure the marketing version and build number in Xcode are correct.
3. Tag the commit with a release tag such as `v14.0.0`.
4. Push the branch and tag.
```
