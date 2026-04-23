# Security Model

Security-sensitive areas are privileged helper behavior, XPC communication, fan control and SMC access, permission handling, local data exposure, signing, entitlements, and release packaging.

Security issues should be reported privately per `SECURITY.md`. General UI bugs and unsupported hardware issues belong in normal issue flow.

The strongest rule is simple: never trust the app process alone for privileged operations. Validate inside the helper. Keep helper diagnostics privacy-preserving. Keep notarized release and signing state reproducible.
