# Localization

Localization uses `.xcstrings` catalogs for the app and helper Info.plist resources. `scripts/localization/generate_string_catalogs.py` supports catalog generation.

When changing user-facing strings in onboarding, Help, fan mode guidance, helper errors, or diagnostics, update string catalogs and tests where applicable.

Retired alert strings were explicitly removed in history, so do not reintroduce alert copy without deciding whether alerts are a current product surface again.
