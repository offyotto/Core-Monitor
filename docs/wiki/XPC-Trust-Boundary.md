# XPC Trust Boundary

The trust boundary is the helper process, not SwiftUI. The app can request fan writes, but the helper must validate the client and input before performing privileged operations.

The helper validates fan IDs, RPMs, SMC key shape, and client authorization. The app manager validates state and user intent, but it cannot be the only protection layer because any XPC caller reaching the Mach service would otherwise be dangerous.

Entitlements, `SMPrivilegedExecutables`, `SMAuthorizedClients`, bundle IDs, Team IDs, helper labels, and signing requirements must remain aligned. The tests around privileged helper requirement strings exist because this alignment has broken before.
