# File: docs/Mac-App-Store/styles.css

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`docs/Mac-App-Store/styles.css`](../../../docs/Mac-App-Store/styles.css) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 13457 bytes |
| Binary | False |
| Line count | 815 |
| Extension | `.css` |

## Imports

None detected.

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `054d5bb` | 2026-04-20 | Redesign Mac App Store website |
| `8475a60` | 2026-04-20 | Refine App Store site scope and mobile layout |
| `e5a80e9` | 2026-04-19 | Refine App Store support page |
| `d6c6910` | 2026-04-19 | Add App Store support page |
| `6eed791` | 2026-04-19 | Add App Store privacy policy page |
| `7883b46` | 2026-04-19 | Add Mac App Store landing page |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
:root {
  --bg: #eef2f6;
  --surface: rgba(255, 255, 255, 0.7);
  --surface-strong: rgba(255, 255, 255, 0.84);
  --surface-soft: rgba(255, 255, 255, 0.56);
  --line: rgba(29, 29, 31, 0.08);
  --line-strong: rgba(29, 29, 31, 0.14);
  --text: #1d1d1f;
  --muted: #6e6e73;
  --accent: #0071e3;
  --shadow-lg: 0 34px 110px rgba(17, 24, 39, 0.14);
  --shadow-md: 0 18px 46px rgba(17, 24, 39, 0.1);
  --radius-xl: 38px;
  --radius-lg: 30px;
  --radius-md: 24px;
}

* {
  box-sizing: border-box;
}

html {
  scroll-behavior: smooth;
}

body {
  margin: 0;
  min-height: 100vh;
  color: var(--text);
  font-family: "SF Pro Display", "SF Pro Text", -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif;
  background:
    radial-gradient(circle at 12% 18%, rgba(0, 113, 227, 0.15), transparent 24%),
    radial-gradient(circle at 88% 14%, rgba(255, 159, 67, 0.18), transparent 22%),
    radial-gradient(circle at 86% 80%, rgba(124, 92, 255, 0.12), transparent 24%),
    linear-gradient(180deg, #f8fafc 0%, #eef2f6 52%, #e7ebf2 100%);
}

body::before,
body::after {
  content: "";
```
