# Xcode Cloud setup for Core-Monitor

Core-Monitor is ready for the repo-side part of Xcode Cloud:

- The shared scheme is `Core-Monitor`.
- The archive action uses the `Release` configuration.
- The `smc-helper` target is built as a dependency and embedded into `Core-Monitor.app`.
- There are no XCTest targets yet, so the first workflow should archive only.

Xcode Cloud workflows are stored in App Store Connect, not in a repository file. Use this checklist to create the workflow in Xcode or App Store Connect.

## Workflow

Name the workflow:

```text
Archive and Notarize
```

Use these workflow settings:

- Product: `Core-Monitor`
- Repository: this repository
- Branch start condition: run on every push to the branch you use for releases, or all branches if you truly want every push archived
- Environment: Latest stable Xcode and macOS, unless a specific Xcode version is required
- Build action: `Archive`
- Scheme: `Core-Monitor`
- Platform: `macOS`
- Configuration: `Release`
- Post action: `Notarize`
- Distribution: `Direct Distribution`
- Tests: disabled until the project has real XCTest targets

For this app, prefer a push workflow on your release branch over all branches. Notarizing every experimental branch will burn the 25 monthly compute hours quickly and will also submit every branch build to Apple's notary service.

## Signing

Use automatic signing in Xcode Cloud with team:

```text
6VDP675K4L
```

Xcode Cloud needs permission to create or use a cloud-managed Developer ID certificate for direct distribution. If the first archive fails during signing or notarization, check these items in App Store Connect and Apple Developer:

- The main app bundle ID is registered: `CoreTools.Core-Monitor`
- The helper identifier is valid for signing: `ventaphobia.smc-helper`
- The Apple developer account has accepted current agreements
- The Xcode Cloud user/team role is allowed to use cloud signing and notarize software
- The workflow archive action is using direct distribution for macOS, not App Store distribution

## Downloading the build later

After a push triggers the workflow:

1. Open Xcode.
2. Open the Report navigator.
3. Select the Xcode Cloud build.
4. Open the archive or artifacts for the completed build.
5. Download or export the notarized app from the Direct Distribution result.

You can also find the same build from App Store Connect under the app's Xcode Cloud tab.

## Local verification

This command verifies the project still compiles without needing local signing credentials:

```sh
xcodebuild \
  -project Core-Monitor.xcodeproj \
  -scheme Core-Monitor \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  CODE_SIGNING_ALLOWED=NO \
  build
```

This does not notarize. It only confirms the code and packaging steps compile locally.
