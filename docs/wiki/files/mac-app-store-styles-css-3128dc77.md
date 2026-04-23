# File: Mac-App-Store/styles.css

## Current Role

- Area: Mac App Store edition website.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`Mac-App-Store/styles.css`](../../../Mac-App-Store/styles.css) |
| Wiki area | Mac App Store edition website |
| Exists in current checkout | True |
| Size | 10299 bytes |
| Binary | False |
| Line count | 637 |
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
| `b1e2d06` | 2026-04-20 | Tune Mac App Store support and privacy layout |
| `5a01567` | 2026-04-20 | Fix Mac App Store website merge corruption |
| `054d5bb` | 2026-04-20 | Redesign Mac App Store website |
| `9383a75` | 2026-04-20 | Add Mac App Store review pages |
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
  --line: rgba(29, 29, 31, 0.08);
  --text: #1d1d1f;
  --muted: #6e6e73;
  --accent: #0071e3;
  --shadow-lg: 0 34px 110px rgba(17, 24, 39, 0.14);
  --shadow-md: 0 18px 46px rgba(17, 24, 39, 0.1);
  --radius-xl: 38px;
  --radius-lg: 30px;
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
    linear-gradient(180deg, #f8fafc 0%, #eef2f6 52%, #e7ebf2 100%);
}

img {
  display: block;
  max-width: 100%;
}

a {
  color: inherit;
```
