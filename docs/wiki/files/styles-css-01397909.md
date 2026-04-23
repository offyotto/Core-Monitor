# File: styles.css

## Current Role

- Area: Website and documentation.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`styles.css`](../../../styles.css) |
| Wiki area | Website and documentation |
| Exists in current checkout | True |
| Size | 10082 bytes |
| Binary | False |
| Line count | 571 |
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
| `236af94` | 2026-04-18 | Improve AI discovery assets |
| `69cc386` | 2026-04-18 | Add DMG release packaging |
| `3fe35bf` | 2026-04-18 | Add DMG release packaging |
| `5dc29ed` | 2026-04-16 | Add privacy controls and refine Core Monitor presentation |
| `7afc598` | 2026-04-15 | Automate releases and sharpen product positioning |
| `0937c96` | 2026-04-13 | Change hero Mac accent to light blue |
| `ebbdfaf` | 2026-04-13 | Color hero Mac accent pink |
| `3d456a7` | 2026-04-13 | Expand Liquid Glass styling across website |
| `92610b7` | 2026-04-13 | Refine Liquid Glass website header |
| `cc9967f` | 2026-04-13 | Add Liquid Glass header styling |
| `d3df0a3` | 2026-04-08 | Update website UI screenshots |
| `2ff256b` | 2026-04-06 | Remove clipped shadow from rotating hero text |
| `6940b6c` | 2026-04-06 | Fix clipped shadow on rotating hero text |
| `1b55fcf` | 2026-04-06 | Simplify hero text to normal drop shadow |
| `b7cbc17` | 2026-04-06 | Add stronger drop shadow to hero headline |
| `7b74a04` | 2026-04-06 | Make hero text shadow more visible |
| `f666ec0` | 2026-04-06 | Strengthen hero text shadow |
| `5a655a7` | 2026-04-06 | Refine landing page hero and top bar icon |
| `0b5d718` | 2026-04-06 | Extend hero glow across app edges |
| `eb99474` | 2026-04-06 | Make hero app window more visible |
| `8e4cd5f` | 2026-04-06 | Sharpen brand icon corners and extend hero glow |
| `5fd083d` | 2026-04-06 | Extend hero glow around app window |
| `dffa60f` | 2026-04-06 | Refine landing page hero and top bar git push origin main con |
| `48553d4` | 2026-04-06 | Refine landing page hero and top bar icon |
| `f4287b9` | 2026-04-06 | committt |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
:root {
  --bg: #f5f5f7;
  --bg-alt: #fbfbfd;
  --surface: rgba(255, 255, 255, 0.78);
  --surface-strong: rgba(255, 255, 255, 0.92);
  --line: rgba(29, 29, 31, 0.08);
  --line-strong: rgba(29, 29, 31, 0.14);
  --text: #1d1d1f;
  --muted: #6e6e73;
  --accent: #0071e3;
  --accent-soft: rgba(0, 113, 227, 0.12);
  --shadow: 0 28px 80px rgba(15, 17, 23, 0.08);
  --radius-xl: 34px;
  --radius-lg: 24px;
  --radius-md: 18px;
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
    radial-gradient(circle at top, rgba(0, 113, 227, 0.09), transparent 26%),
    radial-gradient(circle at 80% 16%, rgba(255, 255, 255, 0.72), transparent 18%),
    linear-gradient(180deg, #fbfbfd 0%, #f5f5f7 46%, #eef1f5 100%);
}

img,
video {
  display: block;
  max-width: 100%;
```
