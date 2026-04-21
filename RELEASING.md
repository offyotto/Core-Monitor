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
5. Let `.github/workflows/release.yml` build, notarize, and publish both `Core-Monitor.app.zip` and `Core-Monitor.dmg`.
6. Confirm the release contains:
- `Core-Monitor.dmg`
- `Core-Monitor.dmg.sha256`
- `Core-Monitor.app.zip`
- `Core-Monitor.app.zip.sha256`
- `core-monitor.rb`
7. Verify the website's main download button resolves to the DMG and the install section still exposes the ZIP fallback.
8. Test the Homebrew install path:

```bash
brew tap --custom-remote offyotto/core-monitor https://github.com/offyotto/Core-Monitor
brew install --cask offyotto/core-monitor/core-monitor
```

## Local dry run

Unsigned CI check:

```bash
xcodebuild test \
  -project Core-Monitor.xcodeproj \
  -scheme Core-Monitor \
  -destination 'platform=macOS' \
  CODE_SIGNING_ALLOWED=NO
```

Signed archive + zip:

```bash
./scripts/release/build_release.sh
```

`build_release.sh` forces a manual `Developer ID Application` signing identity for the archive step so the release path does not depend on whichever automatic-signing identity Xcode happens to prefer locally.
`build_release.sh` now archives with automatic signing and then performs a `developer-id` export so the release artifact keeps the WeatherKit entitlement while still shipping as a Developer ID app.

The repository's `Release` configuration now uses the WeatherKit entitlement. The direct-download path therefore depends on the direct-distribution provisioning profile secret listed above.

Notarize and staple the app:

```bash
APPLE_ID="you@example.com" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
APPLE_TEAM_ID="TEAMID1234" \
./scripts/release/notarize_release.sh build/release/Core-Monitor.app.zip build/release/export/Core-Monitor.app
```

Build the DMG from the stapled app:

```bash
./scripts/release/build_dmg.sh build/release/export/Core-Monitor.app build/release/Core-Monitor.dmg
```

Notarize the DMG:

```bash
APPLE_ID="you@example.com" \
APPLE_APP_SPECIFIC_PASSWORD="xxxx-xxxx-xxxx-xxxx" \
APPLE_TEAM_ID="TEAMID1234" \
./scripts/release/notarize_disk_image.sh build/release/Core-Monitor.dmg
```

## Distribution checklist outside the App Store

- GitHub Releases: already automated in this repo
- GitHub Pages site: keep download/install copy aligned with the DMG-first, ZIP-fallback download path
- Homebrew: keep the custom-tap install path working; a dedicated `homebrew-core-monitor` repo can come later if install volume justifies it
- MacUpdate / AlternativeTo / Apple Silicon directories: submit after each major release and keep screenshots current
- Setapp: viable only after the helper install and first-run flow feel invisible to a non-technical customer; do not prioritize it ahead of release trust and onboarding

## Notes on Setapp

Setapp is attractive for distribution reach, but it is not the first move for Core-Monitor. The app still has a privileged helper path and advanced fan-control behavior that need a calmer first-run experience before a subscription catalog audience will trust it. Treat Setapp as a second-stage distribution channel, not the main launch surface.
