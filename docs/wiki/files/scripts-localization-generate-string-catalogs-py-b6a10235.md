# File: scripts/localization/generate_string_catalogs.py

## Current Role

- Area: Developer and release scripts.
- This page records the file's current repository role, source metadata, and recent commit history.
- Review nearby tests and commit pages before changing this file.

## Metadata

| Field | Value |
| --- | --- |
| Source path | [`scripts/localization/generate_string_catalogs.py`](../../../scripts/localization/generate_string_catalogs.py) |
| Wiki area | Developer and release scripts |
| Exists in current checkout | True |
| Size | 13814 bytes |
| Binary | False |
| Line count | 460 |
| Extension | `.py` |

## Imports

`argparse`, `json`, `re`, `subprocess`, `sys`, `tempfile`, `time`, `urllib`

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
| None detected |  |  |

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
| `29afd92` | 2026-04-18 | Ship 14.0.7 localization update |

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.

## Source Excerpt

```text
#!/usr/bin/env python3

from __future__ import annotations

import argparse
import json
import re
import subprocess
import sys
import tempfile
import time
import urllib.parse
import urllib.request
from collections import OrderedDict
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path


DEFAULT_LANGUAGES: "OrderedDict[str, str]" = OrderedDict(
    [
        ("af", "af"),
        ("am", "am"),
        ("ar", "ar"),
        ("as", "as"),
        ("ay", "ay"),
        ("az", "az"),
        ("be", "be"),
        ("bg", "bg"),
        ("bm", "bm"),
        ("bn", "bn"),
        ("bo", "bo"),
        ("bs", "bs"),
        ("ca", "ca"),
        ("ceb", "ceb"),
        ("co", "co"),
        ("cs", "cs"),
        ("cy", "cy"),
        ("da", "da"),
        ("de", "de"),
        ("dv", "dv"),
```
