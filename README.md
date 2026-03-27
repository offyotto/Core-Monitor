# Core-Monitor

Core-Monitor is an all-in-one macOS stats and multitasking app. It is meant to stay fairly light while still packing in a lot of utility.

## What It Does

- System monitoring
- Fan control
- SMC-backed hardware features
- CoreVisor / VM management
- Intel and Apple silicon compatibility handling

## Compatibility

- Intel support is working fairly well. It has been tested on a 2015 MacBook Air.
- Apple silicon support is also working, including fan control, CoreVisor, and SMC features on an M2 MacBook Pro 13-inch.
- Some Apple silicon-only features are automatically disabled on Intel Macs.
- Fan curve control on Intel is still not working correctly.

## First Launch on macOS

Because Core-Monitor is not signed with a paid Apple Developer certificate, macOS may block it on first launch with a message saying Apple could not verify that it is free from malware. If you downloaded it from this repo and trust the build, you can allow it manually:

1. Try to open `Core-Monitor` once.
2. When macOS blocks it, press `Done`.
3. Open `System Settings` -> `Privacy & Security`.
4. Scroll to the security section and press `Open Anyway`.
5. Confirm by pressing `Open Anyway` in the follow-up dialog.

### Step 1: macOS blocks the app on first launch

![Core-Monitor blocked on first launch](docs/images/gatekeeper/01-blocked.png)

### Step 2: Open System Settings

![System Settings general view](docs/images/gatekeeper/02-general.png)

### Step 3: In Privacy & Security, press Open Anyway

![Privacy and Security open anyway button](docs/images/gatekeeper/03-open-anyway.png)

### Step 4: Confirm the launch

![Confirm open anyway dialog](docs/images/gatekeeper/04-confirm-open.png)

## Notes

- The app is still rough in places and there is still optimization work left.
- Testing coverage is limited because it has only been validated on a small number of machines so far.
- Bug reports and help improving the project are appreciated.
