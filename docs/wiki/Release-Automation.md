# Release Automation

The release path is source-controlled through GitHub Actions and scripts under `scripts/release/`. Public artifacts should be tested, Developer ID signed, notarized, stapled where applicable, and published as stable `Core-Monitor.dmg` and `Core-Monitor.app.zip` names with checksums.

`RELEASING.md` is the operational checklist. `build_release.sh`, `build_dmg.sh`, `notarize_release.sh`, `notarize_disk_image.sh`, and `generate_homebrew_cask.sh` implement the local/CI release pieces.

Release trust is product trust for a privileged-helper utility. Do not treat signing, notarization, entitlements, helper embedding, or cask updates as optional polish.
