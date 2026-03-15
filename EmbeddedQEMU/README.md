# Embedded QEMU

CoreVisor is configured to prefer QEMU binaries that are shipped inside the app bundle resources.

Expected resource layout inside `Contents/Resources/EmbeddedQEMU/`:

- `qemu-system-aarch64` (Apple Silicon)
- `qemu-system-x86_64` (optional fallback)
- `qemu-img`

The binaries must be executable (`chmod +x`).

During development, place these files in `Core-Monitor/Core-Monitor/EmbeddedQEMU/` so Xcode packages them into app resources.

If no bundled QEMU is present, CoreVisor will show:
`Bundled QEMU not found in app resources (EmbeddedQEMU).`
