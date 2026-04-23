#!/usr/bin/env python3
"""Generate the Core-Monitor repository wiki.

The output is intentionally verbose and source-derived. It creates:
- curated feature and architecture pages
- one page per tracked file
- one page per commit reachable from local branches, remote branches, or tags
- removed/deleted-path indexes and retired-feature pages

Run from the repository root:
    python3 scripts/docs/generate_wiki.py
"""

from __future__ import annotations

import collections
import datetime as dt
import hashlib
import os
import re
import shutil
import subprocess
from dataclasses import dataclass
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
WIKI = ROOT / "docs" / "wiki"
TODAY = dt.date.today().isoformat()


def git(args: list[str]) -> str:
    return subprocess.check_output(
        ["git", *args],
        cwd=ROOT,
        text=True,
        errors="replace",
    )


def slugify(value: str, limit: int = 130) -> str:
    slug = re.sub(r"[^A-Za-z0-9]+", "-", value).strip("-").lower()
    if not slug:
        slug = hashlib.sha1(value.encode("utf-8", "replace")).hexdigest()[:12]
    return slug[:limit].strip("-")


def md_escape(value: object) -> str:
    text = str(value)
    return text.replace("|", "\\|").replace("\n", " ")


def write_page(relative: str, title: str, body: str) -> None:
    path = WIKI / relative
    path.parent.mkdir(parents=True, exist_ok=True)
    clean_body = body.strip() + "\n"
    path.write_text(f"# {title}\n\n{clean_body}", encoding="utf-8")


def file_link(relative: str, label: str | None = None) -> str:
    target = relative.replace(" ", "%20")
    return f"[{label or relative}]({target})"


def source_link(path: str) -> str:
    return f"[`{path}`](../../{path.replace(' ', '%20')})"


def is_binary(path: Path) -> bool:
    try:
        chunk = path.read_bytes()[:4096]
    except OSError:
        return True
    return b"\0" in chunk


def read_text(path: Path, max_chars: int = 240_000) -> str:
    try:
        data = path.read_text(encoding="utf-8", errors="replace")
    except OSError:
        return ""
    return data[:max_chars]


@dataclass
class Change:
    status: str
    path: str
    old_path: str | None = None
    added: int | None = None
    deleted: int | None = None


@dataclass
class CommitInfo:
    sha: str
    short: str
    author: str
    email: str
    date: str
    iso_date: str
    subject: str
    body: str
    parents: list[str]
    refs: list[str]
    changes: list[Change]
    insertions: int
    deletions: int


def collect_refs() -> dict[str, list[str]]:
    refs: dict[str, list[str]] = collections.defaultdict(list)
    raw = git(["for-each-ref", "--format=%(objectname)%09%(refname:short)", "refs/heads", "refs/remotes", "refs/tags"])
    for line in raw.splitlines():
        if not line.strip():
            continue
        sha, name = line.split("\t", 1)
        refs[sha].append(name)
    return refs


def collect_numstat(sha: str) -> tuple[dict[str, tuple[int | None, int | None]], int, int]:
    stats: dict[str, tuple[int | None, int | None]] = {}
    insertions = 0
    deletions = 0
    raw = git(["show", "--numstat", "--format=", "--find-renames", "--find-copies", "--root", sha])
    for line in raw.splitlines():
        parts = line.split("\t")
        if len(parts) < 3:
            continue
        added_raw, deleted_raw, path_raw = parts[0], parts[1], parts[-1]
        added = None if added_raw == "-" else int(added_raw)
        deleted = None if deleted_raw == "-" else int(deleted_raw)
        if added is not None:
            insertions += added
        if deleted is not None:
            deletions += deleted
        stats[path_raw] = (added, deleted)
    return stats, insertions, deletions


def collect_commit_changes(sha: str) -> tuple[list[Change], int, int]:
    numstats, insertions, deletions = collect_numstat(sha)
    raw = git(["diff-tree", "--no-commit-id", "--name-status", "-r", "-M", "-C", "--root", sha])
    changes: list[Change] = []
    for line in raw.splitlines():
        if not line.strip():
            continue
        parts = line.split("\t")
        status = parts[0]
        old_path = None
        if status.startswith(("R", "C")) and len(parts) >= 3:
            old_path = parts[1]
            path = parts[2]
        else:
            path = parts[-1]
        added, deleted = numstats.get(path, (None, None))
        changes.append(Change(status=status, path=path, old_path=old_path, added=added, deleted=deleted))
    return changes, insertions, deletions


def collect_commits() -> list[CommitInfo]:
    refs_by_sha = collect_refs()
    shas = [line.strip() for line in git(["rev-list", "--reverse", "--branches", "--tags", "--remotes"]).splitlines() if line.strip()]
    commits: list[CommitInfo] = []
    for sha in shas:
        raw = git([
            "show",
            "-s",
            "--date=short",
            "--format=%H%x1f%h%x1f%an%x1f%ae%x1f%ad%x1f%aI%x1f%s%x1f%b",
            sha,
        ])
        parts = raw.split("\x1f", 7)
        if len(parts) < 8:
            continue
        full, short, author, email, date, iso_date, subject, body = [part.strip() for part in parts]
        parents = git(["show", "-s", "--format=%P", sha]).strip().split()
        changes, insertions, deletions = collect_commit_changes(sha)
        commits.append(
            CommitInfo(
                sha=full,
                short=short,
                author=author,
                email=email,
                date=date,
                iso_date=iso_date,
                subject=subject,
                body=body,
                parents=parents,
                refs=sorted(refs_by_sha.get(full, [])),
                changes=changes,
                insertions=insertions,
                deletions=deletions,
            )
        )
    return commits


def collect_files() -> list[str]:
    return [line.strip() for line in git(["ls-files"]).splitlines() if line.strip()]


def infer_area(path: str) -> str:
    lower = path.lower()
    if lower.startswith("core-monitor/"):
        if "touchbar" in lower or "pockwidgetsources" in lower or "pkwidget" in lower:
            return "Touch Bar and Pock widget runtime"
        if "weather" in lower:
            return "Weather and location"
        if "fan" in lower or "smc" in lower or "helper" in lower:
            return "Fan control, SMC, or helper"
        if "menubar" in lower or "menu-bar" in lower:
            return "Menu bar"
        if "alert" in lower:
            return "Legacy alert system"
        if "dashboard" in lower or "contentview" in lower or "monitoringdashboard" in lower:
            return "Dashboard"
        if "kernelpanic" in lower or "easteregg" in lower:
            return "Kernel Panic / Weird Mode"
        if "privacy" in lower:
            return "Privacy controls"
        if "launch" in lower or "startup" in lower or "welcome" in lower:
            return "Startup and onboarding"
        if "assets.xcassets" in lower or "audio" in lower:
            return "App assets"
        return "Core app"
    if lower.startswith("core-monitortests/"):
        return "Tests"
    if lower.startswith("smc-helper"):
        return "Privileged helper target"
    if lower.startswith(".github"):
        return "GitHub automation"
    if lower.startswith("scripts/"):
        return "Developer and release scripts"
    if lower.startswith("docs/") or lower.endswith(".html") or lower in {"styles.css", "index.html", "robots.txt", "sitemap.xml"}:
        return "Website and documentation"
    if lower.startswith("mac-app-store"):
        return "Mac App Store edition website"
    if lower.startswith("casks/"):
        return "Homebrew distribution"
    return "Repository support"


KNOWN_NOTES: dict[str, list[str]] = {
    "Core-Monitor/SystemMonitor.swift": [
        "Owns the live sampling loop for CPU, memory, battery, disk, network, thermal, SMC, and supplemental control data.",
        "Publishes `SystemMonitorSnapshot` as the shared point-in-time model used by dashboard, menu bar, trends, and support surfaces.",
        "Keeps expensive process sampling adaptive so detailed process enumeration is hot only while detailed UI asks for it.",
    ],
    "Core-Monitor/FanController.swift": [
        "Owns user-facing fan modes, Smart/Manual/Custom behavior, custom preset persistence, and shutdown restoration semantics.",
        "Separates system-owned automatic control from Core-Monitor-owned managed profiles so UI copy can explain helper requirements accurately.",
        "Transforms temperature, wattage, fan ranges, and preset settings into helper write targets.",
    ],
    "Core-Monitor/SMCHelperManager.swift": [
        "Owns app-side helper installation, reachability probes, stale-helper repair, and trusted XPC calls.",
        "Tracks helper state as missing, unknown, checking, reachable, or unreachable instead of a weak installed/not-installed flag.",
        "Is a security-sensitive boundary because it decides when privileged fan writes are attempted.",
    ],
    "smc-helper/main.swift": [
        "Implements the privileged helper process, AppleSMC reads/writes, fan manual/auto commands, and XPC service mode.",
        "Validates clients, fan IDs, RPM values, and four-character SMC keys inside the privileged process.",
        "Includes Apple Silicon fan-control mode-key probing and `Ftst` fallback behavior based on agoodkind/macos-smc-fan research.",
    ],
    "Core-Monitor/Core_MonitorApp.swift": [
        "Contains the NSApplicationDelegate, single-instance policy, dashboard window controller, activation policy, startup routing, and shutdown hooks.",
        "Keeps a menu bar utility alive while still opening a visible dashboard for onboarding and explicit dashboard requests.",
        "Runs best-effort cleanup when the app terminates, including returning fan control to automatic where applicable.",
    ],
    "Core-Monitor/ContentView.swift": [
        "Large SwiftUI dashboard shell containing the main sidebar, overview surfaces, system cards, fan panel, Touch Bar settings, and about/help-adjacent UI.",
        "A high-risk file because visual refactors can cross monitoring, fan control, helper diagnostics, and onboarding behavior.",
        "Current architecture docs flag this as a pressure point that should keep shrinking into dedicated subviews.",
    ],
    "Core-Monitor/MenuBarExtraView.swift": [
        "Builds the rich menu bar popovers for CPU, memory, disk, network, temperature, and combined menu actions.",
        "Uses the shared snapshot and trend histories so menu bar status does not invent a parallel telemetry model.",
        "Regression risk is layout-driven: small visual changes can hide actions or stale-state messaging.",
    ],
    "Core-Monitor/MenuBarSettings.swift": [
        "Defines menu bar visibility presets and validates item enablement so the app remains reachable.",
        "Persists user menu bar density choices and broadcasts configuration changes to controllers.",
    ],
    "Core-Monitor/TouchBarCustomizationCompatibility.swift": [
        "Owns persisted Touch Bar layouts, pinned apps, pinned folders, custom commands, themes, presentation mode, and legacy migration.",
        "The versioned persisted structs are the compatibility boundary for old user layouts.",
    ],
    "Core-Monitor/WeatherService.swift": [
        "Owns WeatherKit capability detection, optional location access, fallback coordinates, attribution, and view-model state.",
        "Startup behavior is intentionally permission-safe: location prompting should only happen after explicit user intent.",
    ],
    "Core-Monitor/HelperDiagnosticsExporter.swift": [
        "Builds exportable JSON reports for helper signing, helper installation, launch-at-login, menu bar reachability, and recovery recommendations.",
        "This is the preferred support artifact when fan control or helper trust fails.",
    ],
    "Core-Monitor/AlertEngine.swift": [
        "Legacy pure alert-evaluation logic retained for tests and possible future alert reintroduction.",
        "The current UI removed the old alerts screen surface; do not extend this path casually.",
    ],
    "Core-Monitor/KernelPanicGame.swift": [
        "Implements the Kernel Panic parody game model and SwiftUI arcade surface.",
        "This is intentionally fictional and must not drift into real malware behavior.",
    ],
    "README.md": [
        "Primary public positioning page for GitHub users, installers, and AI/search discovery.",
        "Current README describes macOS 13+, helper-optional monitoring, DMG/ZIP/Homebrew installs, fan modes, Touch Bar customization, and Mac App Store edition differences.",
    ],
    "RELEASING.md": [
        "Source-controlled release checklist for test-first, signed, notarized DMG/ZIP distribution and Homebrew cask publishing.",
        "Use this before tags or public artifacts because release trust is central to a privileged-helper utility.",
    ],
}


def extract_symbols(text: str) -> list[tuple[str, str, int]]:
    pattern = re.compile(
        r"^\s*(?:@[A-Za-z0-9_()\".,: =]+\s+)*(?:public|private|internal|open|final|fileprivate|@MainActor|@Observable|\s)*"
        r"\b(struct|class|enum|protocol|extension|func)\s+([A-Za-z_][A-Za-z0-9_.$]*)",
        re.MULTILINE,
    )
    symbols: list[tuple[str, str, int]] = []
    for match in pattern.finditer(text):
        line = text.count("\n", 0, match.start()) + 1
        symbols.append((match.group(1), match.group(2), line))
    return symbols


def extract_imports(text: str) -> list[str]:
    return sorted(set(re.findall(r"^\s*import\s+([A-Za-z0-9_]+)", text, flags=re.MULTILINE)))


def recent_file_history(path: str, limit: int = 25) -> list[tuple[str, str, str]]:
    raw = git(["log", "--all", "--follow", f"--max-count={limit}", "--date=short", "--format=%h%x09%ad%x09%s", "--", path])
    rows = []
    for line in raw.splitlines():
        parts = line.split("\t", 2)
        if len(parts) == 3:
            rows.append((parts[0], parts[1], parts[2]))
    return rows


def change_area_summary(changes: list[Change]) -> list[str]:
    areas = collections.Counter(infer_area(change.path) for change in changes)
    return [f"{area}: {count} file(s)" for area, count in areas.most_common()]


def status_name(status: str) -> str:
    if status.startswith("R"):
        return "Renamed"
    if status.startswith("C"):
        return "Copied"
    return {
        "A": "Added",
        "M": "Modified",
        "D": "Deleted",
        "T": "Type changed",
        "U": "Unmerged",
    }.get(status, status)


def generate_commit_pages(commits: list[CommitInfo]) -> dict[str, str]:
    links: dict[str, str] = {}
    for commit in commits:
        filename = f"commits/{commit.short}-{slugify(commit.subject, 90)}.md"
        links[commit.sha] = filename
        changed_rows = []
        for change in commit.changes:
            path_text = change.path
            if change.old_path:
                path_text = f"{change.old_path} -> {change.path}"
            changed_rows.append(
                f"| {md_escape(status_name(change.status))} | `{md_escape(path_text)}` | "
                f"{'' if change.added is None else change.added} | {'' if change.deleted is None else change.deleted} |"
            )
        if not changed_rows:
            changed_rows.append("| Metadata-only or merge | No direct file diff recorded |  |  |")

        parent_text = ", ".join(f"`{parent[:12]}`" for parent in commit.parents) if commit.parents else "Root commit"
        refs_text = ", ".join(f"`{ref}`" for ref in commit.refs) if commit.refs else "No direct branch/tag ref"
        body_text = commit.body.strip() or "No extended commit message body."
        area_bullets = "\n".join(f"- {line}" for line in change_area_summary(commit.changes)) or "- No file areas detected."
        write_page(
            filename,
            f"Commit {commit.short}: {commit.subject}",
            f"""
## Metadata

| Field | Value |
| --- | --- |
| Full SHA | `{commit.sha}` |
| Author | {md_escape(commit.author)} <{md_escape(commit.email)}> |
| Date | {md_escape(commit.date)} |
| ISO date | `{md_escape(commit.iso_date)}` |
| Parents | {parent_text} |
| Direct refs | {refs_text} |
| Files changed | {len(commit.changes)} |
| Insertions | {commit.insertions} |
| Deletions | {commit.deletions} |

## Commit Message

{body_text}

## Area Summary

{area_bullets}

## Changed Files

| Status | Path | Added | Deleted |
| --- | --- | ---: | ---: |
{os.linesep.join(changed_rows)}

## Reading Notes

- This page is generated from local git metadata so it is best used with the exact repository clone that produced the wiki.
- Merge commits may show little or no direct diff even though they pull a full branch of work into the reachable history.
- Deleted paths are also cross-linked from the removed-parts index when the status is `Deleted`.
""",
        )
    return links


def generate_file_pages(files: list[str]) -> dict[str, str]:
    links: dict[str, str] = {}
    for tracked in files:
        path_hash = hashlib.sha1(tracked.encode("utf-8", "replace")).hexdigest()[:8]
        page = f"files/{slugify(tracked, 130)}-{path_hash}.md"
        links[tracked] = page
        path = ROOT / tracked
        exists = path.exists()
        size = path.stat().st_size if exists else 0
        binary = not exists or is_binary(path)
        text = "" if binary else read_text(path)
        lines = 0 if binary else text.count("\n") + (1 if text else 0)
        imports = extract_imports(text)
        symbols = extract_symbols(text)
        notes = KNOWN_NOTES.get(tracked, [])
        history = recent_file_history(tracked)

        import_text = ", ".join(f"`{item}`" for item in imports[:20]) if imports else "None detected."
        symbol_rows = [
            f"| {kind} | `{md_escape(name)}` | {line} |"
            for kind, name, line in symbols[:80]
        ]
        if not symbol_rows:
            symbol_rows.append("| None detected |  |  |")

        note_text = "\n".join(f"- {note}" for note in notes)
        if not note_text:
            note_text = (
                f"- Area: {infer_area(tracked)}.\n"
                f"- This page records the file's current repository role, source metadata, and recent commit history.\n"
                f"- Review nearby tests and commit pages before changing this file."
            )

        history_rows = [
            f"| `{short}` | {date} | {md_escape(subject)} |"
            for short, date, subject in history
        ]
        if not history_rows:
            history_rows.append("| No reachable history found |  |  |")

        nested_source_link = f"[`{tracked}`](../../../{tracked.replace(' ', '%20')})"
        preview = ""
        if text and tracked.endswith((".md", ".txt", ".sh", ".py", ".swift", ".m", ".h", ".plist", ".yml", ".yaml", ".rb", ".html", ".css", ".xml", ".xcstrings")):
            excerpt = "\n".join(text.splitlines()[:40])
            preview = f"\n## Source Excerpt\n\n```text\n{excerpt[:6000]}\n```\n"

        write_page(
            page,
            f"File: {tracked}",
            f"""
## Current Role

{note_text}

## Metadata

| Field | Value |
| --- | --- |
| Source path | {nested_source_link} |
| Wiki area | {md_escape(infer_area(tracked))} |
| Exists in current checkout | {exists} |
| Size | {size} bytes |
| Binary | {binary} |
| Line count | {lines} |
| Extension | `{path.suffix or '(none)'}` |

## Imports

{import_text}

## Declarations

| Kind | Name | Line |
| --- | --- | ---: |
{os.linesep.join(symbol_rows)}

## Recent Change History

| Commit | Date | Subject |
| --- | --- | --- |
{os.linesep.join(history_rows)}

## Maintenance Notes

- Prefer focused changes that respect the ownership described above.
- If this file touches helper trust, SMC writes, startup, or permissions, update the relevant support docs and tests.
- If this file is generated or an asset manifest, verify the producing workflow instead of hand-editing generated payloads.
{preview}
""",
        )
    return links


def collect_deleted_paths(commits: list[CommitInfo]) -> dict[str, list[CommitInfo]]:
    deleted: dict[str, list[CommitInfo]] = collections.defaultdict(list)
    for commit in commits:
        for change in commit.changes:
            if change.status == "D":
                deleted[change.path].append(commit)
            elif change.status.startswith("R") and change.old_path:
                deleted[change.old_path].append(commit)
    return deleted


def deleted_category(path: str) -> str:
    lower = path.lower()
    if ".deriveddata" in lower or "modulecache" in lower or "compilationcache" in lower or "sdkstatcaches" in lower:
        return "Removed generated Xcode cache"
    if "embeddedqemu" in lower or "corevisor" in lower or lower.startswith("libs/") or "qemu" in lower:
        return "Removed CoreVisor / virtualization payload"
    if "alert" in lower:
        return "Retired alerts surface"
    if "benchmark" in lower or "leaderboard" in lower or "qualityrating" in lower:
        return "Retired benchmark / leaderboard feature"
    if "appupdater" in lower or "appcast" in lower or lower.endswith(".delta"):
        return "Retired updater delta feed"
    if lower.startswith("topbar/"):
        return "Removed old topbar extension"
    if "workflow" in lower or ".github/" in lower:
        return "Removed CI workflow"
    if lower.endswith((".mov", ".mp4", ".png", ".mp3")):
        return "Removed or replaced media"
    if "dashboardlaunchdiagnostics" in lower or "tamper" in lower:
        return "Retired diagnostics / tamper path"
    if "xcodeproj" in lower or ".app/contents" in lower:
        return "Removed old project or bundled app artifact"
    return "Other removed path"


REMOVED_GROUPS: dict[str, tuple[str, str, list[str]]] = {
    "retired-alerts-surface": (
        "Retired Alerts Screen Surface",
        "The old Alerts screen UI was removed while core alert models/evaluation logic remained as legacy or future-facing support code.",
        ["Core-Monitor/AlertsView.swift", "Core-Monitor/AlertsPresentation.swift"],
    ),
    "retired-corevisor": (
        "Removed CoreVisor And Virtualization Support",
        "CoreVisor/QEMU assets and views were removed as the product narrowed back to Apple Silicon monitoring, thermals, menu bar, Touch Bar, and fan control.",
        ["Core-Monitor/CoreVisorManager.swift", "Core-Monitor/CoreVisorSetupView.swift", "EmbeddedQEMU/README.md", "EmbeddedQEMU/qemu-system-aarch64"],
    ),
    "retired-benchmarking": (
        "Removed Benchmark, Leaderboard, And Quality Rating",
        "Benchmark and leaderboard surfaces were removed with the old updater payload, reducing scope outside the core monitoring product.",
        ["Core-Monitor/BenchmarkEngine.swift", "Core-Monitor/BenchmarkResult.swift", "Core-Monitor/BenchmarkView.swift", "Core-Monitor/LeaderboardView.swift", "Core-Monitor/QualityRatingEngine.swift"],
    ),
    "retired-updater-deltas": (
        "Removed Appcast And Delta Update Feed",
        "Sparkle-style appcast and delta downloads were deleted when release distribution shifted toward signed DMG/ZIP artifacts and Homebrew cask metadata.",
        ["Core-Monitor/AppUpdater.swift", "appcast.xml", "downloads/Core-Monitor112100-11250.delta"],
    ),
    "retired-topbar-extension": (
        "Removed Old Topbar Extension",
        "The old widget-extension style topbar project was removed during repository cleanup, leaving the active Core-Monitor app and its Pock/Touch Bar integrations.",
        ["topbar/AppIntent.swift", "topbar/topbar.swift", "topbar/topbarBundle.swift", "topbar/topbarControl.swift"],
    ),
    "retired-launchpad-glass": (
        "Removed Companion Launchpad And Glass UI Experiments",
        "Early companion launchpad and glass/motion files were deleted before the current dashboard/menu bar architecture stabilized.",
        ["Core-Monitor/CompanionLaunchpadManager.swift", "Core-Monitor/LaunchpadGlassView.swift", "Core-Monitor/MotionEffects.swift"],
    ),
    "retired-diagnostics-tamper": (
        "Removed Diagnostics And Tamper Experiments",
        "Dashboard launch diagnostics and SMC tamper detector files were removed as helper health, diagnostics export, and service alerts became the support path.",
        ["Core-Monitor/DashboardLaunchDiagnostics.swift", "Core-Monitor/SMCTamperDetector.swift"],
    ),
    "media-replacements": (
        "Removed Or Replaced Media Assets",
        "Website videos, screenshots, and Kernel Panic soundtrack files were removed or replaced as release media moved from older assets to current DMG/site/audio payloads.",
        ["docs/videos/install-walkthrough.mov", "docs/images/install-walkthrough-shot.png", "Core-Monitor/KernelPanicAudio/kernelpanic_phase1.mp3"],
    ),
    "ci-workflow-cleanup": (
        "Removed CI Workflow Experiments",
        "Older CodeQL and Objective-C/Xcode workflows were removed while the repository moved toward focused GitHub Actions CI and release workflows.",
        [".github/workflows/codeql.yml", ".github/workflows/objective-c-xcode.yml"],
    ),
    "generated-cache-cleanup": (
        "Removed Generated Build Cache",
        "Tracked Xcode DerivedData, module cache, SDK stat cache, and build-output files were removed because they are generated artifacts and should not live in source control.",
        [".deriveddata/CompilationCache.noindex/generic/lock", ".deriveddata/ModuleCache.noindex/modules.timestamp"],
    ),
}


def generate_removed_pages(deleted: dict[str, list[CommitInfo]], commit_links: dict[str, str]) -> None:
    for slug, (title, narrative, paths) in REMOVED_GROUPS.items():
        rows = []
        for path in paths:
            commits = deleted.get(path, [])
            if commits:
                commit_text = ", ".join(file_link(f"../{commit_links[c.sha]}", c.short) for c in commits[:8])
                date_text = ", ".join(sorted({c.date for c in commits}))
            else:
                commit_text = "No exact deletion entry found in current reachable history."
                date_text = ""
            rows.append(f"| `{md_escape(path)}` | {date_text} | {commit_text} |")
        write_page(
            f"removed/{slug}.md",
            title,
            f"""
## Summary

{narrative}

## Paths

| Removed path | Removal date(s) | Commit(s) |
| --- | --- | --- |
{os.linesep.join(rows)}

## What To Remember

- Removal does not always mean the concept disappeared completely; some behavior moved into a narrower owner.
- If resurrecting any of this code, first verify the current product scope, helper trust model, release process, and App Store constraints.
- The complete deleted-path index lists generated-cache removals separately from product-feature removals.
""",
        )

    grouped: dict[str, list[tuple[str, list[CommitInfo]]]] = collections.defaultdict(list)
    for path, path_commits in sorted(deleted.items()):
        grouped[deleted_category(path)].append((path, path_commits))

    all_rows = []
    for category, entries in sorted(grouped.items()):
        all_rows.append(f"\n## {category}\n")
        all_rows.append("| Removed path | Commit(s) |")
        all_rows.append("| --- | --- |")
        for path, path_commits in entries:
            commit_text = ", ".join(file_link(f"../{commit_links[c.sha]}", c.short) for c in path_commits[:6])
            if len(path_commits) > 6:
                commit_text += f" plus {len(path_commits) - 6} more"
            all_rows.append(f"| `{md_escape(path)}` | {commit_text} |")

    write_page(
        "removed/All-Deleted-Paths.md",
        "All Deleted Paths",
        f"""
This page records every deleted or renamed-away path detected from reachable branch, remote, and tag history.

Deleted path count: **{len(deleted)}**

{os.linesep.join(all_rows)}
""",
    )

    group_links = "\n".join(
        f"- {file_link(f'{slug}.md', title)}"
        for slug, (title, _narrative, _paths) in REMOVED_GROUPS.items()
    )
    category_rows = "\n".join(f"| {md_escape(category)} | {len(entries)} |" for category, entries in sorted(grouped.items()))
    write_page(
        "removed/Removed-Parts-Index.md",
        "Removed Parts Index",
        f"""
## Retired Feature Pages

{group_links}

## Deleted Path Categories

| Category | Paths |
| --- | ---: |
{category_rows}

## Complete Deleted Path Ledger

See {file_link('All-Deleted-Paths.md', 'All Deleted Paths')}.

## Interpretation

- Product removals include the retired alerts screen, CoreVisor/QEMU, benchmark/leaderboard surfaces, updater deltas, the old topbar extension, old diagnostics experiments, and replaced media.
- Repository hygiene removals include Xcode caches, packaged app artifacts, old generated projects, and stale workflow files.
- The current product is narrower and clearer: Apple Silicon monitoring, local dashboard/menu bar status, optional helper-backed fan control, Touch Bar widgets, WeatherKit when entitled, support diagnostics, and signed release distribution.
""",
    )


def generate_indexes(commits: list[CommitInfo], files: list[str], file_links: dict[str, str], commit_links: dict[str, str]) -> None:
    file_rows = [
        f"| {source_link(path)} | {md_escape(infer_area(path))} | {file_link(file_links[path], 'wiki page')} |"
        for path in files
    ]
    write_page(
        "File-Index.md",
        "File Index",
        f"""
Tracked file count: **{len(files)}**

| Source path | Area | Wiki page |
| --- | --- | --- |
{os.linesep.join(file_rows)}
""",
    )

    commit_rows = [
        f"| {idx} | {commit.date} | {file_link('../' + commit_links[commit.sha], commit.short)} | {md_escape(commit.subject)} | {len(commit.changes)} | {commit.insertions} | {commit.deletions} |"
        for idx, commit in enumerate(commits, start=1)
    ]
    write_page(
        "history/Every-Commit-Index.md",
        "Every Commit Index",
        f"""
Reachable commit count: **{len(commits)}**

This index covers commits reachable from local branches, remote branches, and tags. It intentionally excludes the stash ref so temporary local recovery commits do not become canonical history.

| # | Date | Commit | Subject | Files | + | - |
| ---: | --- | --- | --- | ---: | ---: | ---: |
{os.linesep.join(commit_rows)}
""",
    )

    by_date: dict[str, list[CommitInfo]] = collections.defaultdict(list)
    for commit in commits:
        by_date[commit.date].append(commit)
    timeline_parts = []
    for date in sorted(by_date):
        timeline_parts.append(f"## {date}\n")
        for commit in by_date[date]:
            timeline_parts.append(f"- {file_link('../' + commit_links[commit.sha], commit.short)} - {commit.subject}")
        timeline_parts.append("")
    write_page(
        "history/Chronological-Change-Log.md",
        "Chronological Change Log",
        "\n".join(timeline_parts),
    )

    tags = [line.strip() for line in git(["tag", "--list", "--sort=creatordate"]).splitlines() if line.strip()]
    branches = [line.strip() for line in git(["branch", "--all", "--verbose", "--no-abbrev"]).splitlines() if line.strip()]
    tag_lines = "\n".join(f"- `{tag}`" for tag in tags) or "- No tags detected."
    branch_lines = "\n".join(f"- `{branch}`" for branch in branches) or "- No branches detected."
    write_page(
        "history/Branches-And-Tags.md",
        "Branches And Tags",
        f"""
## Tags

{tag_lines}

## Branches And Remote Refs

{branch_lines}

## Notes

- Release tags show the long version arc from early `v1`/`v2` style tags through the current v14 series.
- Several `codex/*` branches document iterative repair, release, website, AI discovery, and App Store work.
- `origin/main` is ahead of local `main` in this checkout; this wiki is generated from all reachable local, remote, and tag commits, not only the current branch.
""",
    )


FEATURE_PAGES: list[tuple[str, str, str]] = [
    (
        "Start-Here.md",
        "Start Here",
        """
Use this wiki as the long-form map for Core-Monitor. The shortest path is: read Product Overview, Runtime Architecture, Monitoring Pipeline, Fan Control, Privileged Helper, Menu Bar, Dashboard, Touch Bar, Release Automation, Removed Parts Index, File Index, and Every Commit Index.

The wiki has two layers. Curated pages explain how the app works and why current boundaries exist. Generated file and commit pages preserve exhaustive detail: every tracked file gets a page and every reachable commit gets a page.

The current checkout already contained modified source files when this wiki was generated, so the wiki output was written under `docs/wiki/` without changing the active Swift files.
""",
    ),
    (
        "Product-Overview.md",
        "Product Overview",
        """
Core-Monitor is a native macOS utility focused on Apple Silicon monitoring, thermal awareness, menu bar visibility, dashboard inspection, optional helper-backed fan control, Touch Bar widgets, and support diagnostics.

The product stance is monitoring-first. Sensor reads should work without elevated privileges. The privileged helper is only for fan writes and helper-backed SMC operations that require root-level access. That split is important for trust: normal users can launch and monitor without installing anything privileged, while users who explicitly want fan control can install the helper and see diagnostics when trust or signing state is wrong.

Current public docs describe signed DMG, signed ZIP, and Homebrew cask installs. The repository also contains a separate Mac App Store website path for a sandboxed edition that intentionally excludes helper, AppleSMC/private-framework paths, and non-App-Store behavior.

The app includes a "Weird Mode" Kernel Panic parody game and optional WeatherKit/Touch Bar features, but those are secondary surfaces. The durable core is system monitoring, thermals, fan state, local privacy, menu bar reachability, and a supportable release process.
""",
    ),
    (
        "Source-Map.md",
        "Source Map",
        """
The active app target lives under `Core-Monitor/`. The privileged helper target lives under `smc-helper/`. Tests live under `Core-MonitorTests/`. Public docs, website assets, and support pages live under `docs/`, root HTML/CSS files, and `Mac-App-Store/`. Release scripts live under `scripts/release/`, localization tooling under `scripts/localization/`, and the custom Homebrew cask under `Casks/`.

High-risk source files are `SystemMonitor.swift`, `FanController.swift`, `SMCHelperManager.swift`, `smc-helper/main.swift`, `Core_MonitorApp.swift`, `ContentView.swift`, and `MenuBarExtraView.swift`. They coordinate sampling, fan writes, helper trust, startup, dashboard UI, and menu bar UI.

The Pock/Touch Bar compatibility layer is split across `CoreMonTouchBarController.swift`, `TouchBarCustomizationCompatibility.swift`, `TouchBarUtilityWidgets.swift`, `GroupViews.swift`, `PKCoreMonWidgets.swift`, `PKWidget*`, and `PockWidgetSources/`.

Generated file pages in this wiki give per-file imports, declarations, recent history, and maintenance notes. Start at File Index when tracing ownership.
""",
    ),
    (
        "Runtime-Architecture.md",
        "Runtime Architecture",
        """
The runtime is a menu bar utility with a dashboard window. `Core_MonitorApp.swift` installs the application delegate, creates long-lived coordinator state, handles duplicate launches, sets activation policy, installs menu bar items, and opens the dashboard when onboarding or explicit user actions require it.

`AppCoordinator` owns shared app objects such as `SystemMonitor`, `FanController`, menu bar coordination, Touch Bar attachment, and dashboard navigation. SwiftUI surfaces should read from these shared objects rather than creating parallel samplers or independent fan state.

`SystemMonitor` is the telemetry source of truth. It publishes `SystemMonitorSnapshot`, trend series, and lightweight convenience accessors. Dashboard and menu bar surfaces read from the snapshot and history buffers. Detailed process sampling is adaptive and reason-driven to avoid constant expensive enumeration.

Fan control is split: `FanController` decides product behavior and target RPMs, `SMCHelperManager` manages helper install/reachability/XPC, and `smc-helper/main.swift` performs privileged AppleSMC writes after validating clients and input.
""",
    ),
    (
        "App-Startup-And-Lifecycle.md",
        "App Startup And Lifecycle",
        """
Startup is controlled by `Core_MonitorApp.swift`, `WelcomeGuideProgress.swift`, `StartupManager.swift`, `DashboardShortcutManager.swift`, and `AppCoordinator.swift`.

The app must satisfy two conflicting goals: behave like a quiet menu bar utility for returning users, and show a visible dashboard/onboarding surface for first launch or explicit dashboard requests. The current delegate disables automatic termination, handles duplicate launches, purges deprecated defaults, determines welcome-guide presentation, installs global shortcuts/observers, creates menu bar items, and opens the dashboard if needed.

Activation policy matters. The app can be accessory-style for menu bar operation, but it must temporarily promote visibility when the dashboard is shown so the window does not vanish behind other apps or launch invisibly.

Shutdown is also functional: fan modes that Core-Monitor owns should be returned to system automatic best-effort before process exit. That cleanup is part of the trust model.
""",
    ),
    (
        "Dashboard-Architecture.md",
        "Dashboard Architecture",
        """
The dashboard is mainly in `ContentView.swift`, `MonitoringDashboardViews.swift`, `FanCurveEditorView.swift`, `FanModeGuidanceCard.swift`, `MenuBarConfigurationSection.swift`, `LaunchAtLoginSection.swift`, `PrivacyControlsSection.swift`, `WeatherLocationAccessSection.swift`, `HelpView.swift`, and support cards such as helper diagnostics.

`ContentView.swift` remains oversized and mixes shell, sidebar, overview cards, system pages, fan controls, Touch Bar customization, helper support, and about surfaces. The architecture docs already call it a pressure point. New UI work should prefer extracting small dedicated views rather than growing it.

Dashboard data should come from `SystemMonitorSnapshot`, `FanController`, `SMCHelperManager`, and settings objects. Avoid ad hoc timers or local telemetry state in SwiftUI views. Detailed process panels should request detailed sampling while visible and release that reason when hidden.

`DashboardWindowLayout.swift` owns safe window sizing and frame reset rules; use it instead of hardcoding dashboard geometry.
""",
    ),
    (
        "Menu-Bar-Architecture.md",
        "Menu Bar Architecture",
        """
Menu bar behavior is centered on `MenubarController.swift`, `MenuBarSettings.swift`, `MenuBarExtraView.swift`, `MenuBarStatusSummary.swift`, and `MenuBarConfigurationSection.swift`.

`MenuBarSettings` defines presets and persistence, including safety rules that keep at least one visible item so the app remains reachable. `MenuBarController` owns NSStatusItem creation and update. `MenuBarExtraView` builds rich popovers for CPU, memory, disk, network, temperature, and the combined menu surface.

The menu bar is not a separate monitoring system. It should read the shared snapshot and history buffers. This keeps dashboard, menu bar, trends, alert status, and support diagnostics consistent.

The default product direction is readable thermal-first status, not maximum density. Presets exist to let users choose compact, balanced, or dense layouts without turning first launch into a noisy wall of numbers.
""",
    ),
    (
        "Monitoring-Pipeline.md",
        "Monitoring Pipeline",
        """
`SystemMonitor.swift` samples CPU, performance/efficiency cores, memory, disk, battery, power, network, fan speed, temperatures, SMC values, volume, brightness, thermal state, and top processes. The output is folded into `SystemMonitorSnapshot` and trend series in `MonitoringSnapshot.swift`.

Fast interactive monitoring uses a roughly one-second cadence. Basic/background mode backs off. Supplemental data such as disk stats and controls uses refresh gates so slower or heavier reads do not run every sample.

Important APIs include `host_statistics`, `host_processor_info`, `vm_statistics64`, `IOPSCopyPowerSourcesInfo`, IORegistry queries for AppleSmartBattery, sysctl, IOKit AppleSMC calls, CoreAudio volume APIs, and process enumeration helpers.

All monitoring should remain local. Avoid adding telemetry, network reporting, or account dependencies to the core pipeline.
""",
    ),
    (
        "Snapshot-Trends-And-Freshness.md",
        "Snapshot Trends And Freshness",
        """
`MonitoringSnapshot.swift` defines the shared data model, trend ranges, freshness states, trend points, process activity snapshots, and top-process snapshot containers.

The app uses freshness classification to distinguish waiting, live, delayed, and stale samples. That matters because a system monitor is worse than useless when stale numbers look live. Dashboard and menu bar surfaces should surface last-update and cadence context when telemetry lags.

Trend series cover short and longer windows so users can interpret sustained load instead of only a point-in-time reading. CPU temperature, GPU temperature, total power, primary fan speed, memory usage, swap usage, and network throughput all fit the same history model.

When adding a metric, prefer adding it to `SystemMonitorSnapshot` and the trend model rather than threading individual properties through each UI.
""",
    ),
    (
        "CPU-GPU-Memory-Disk-Network.md",
        "CPU GPU Memory Disk Network",
        """
CPU load comes from host CPU counters and per-processor load info. Apple Silicon performance and efficiency core utilization uses logical-core grouping from sysctl when available.

GPU temperature is SMC-backed and depends on chip-specific keys. The app probes several known keys and falls back when a sensor is unavailable. GPU utilization is not the same as GPU temperature and should not be implied unless a real utilization source exists.

Memory stats come from VM statistics: used, wired, compressed, free, page-ins, page-outs, swap, and derived pressure. UI should explain pressure and swap in user terms, not only percentages.

Disk stats are gated because filesystem capacity and process-level disk activity do not need the same cadence as CPU load. Network throughput uses byte deltas over time, not a raw absolute counter.
""",
    ),
    (
        "Battery-Power-And-Thermals.md",
        "Battery Power And Thermals",
        """
Battery data is modeled in `BatteryInfo` and formatted through `BatteryDetailFormatter`. Data includes charge, source, status, cycle count, health, voltage, amperage, power watts, temperature, capacities, and time remaining where macOS provides it.

Power data is used both for user-facing visibility and fan-control heuristics. Smart and custom fan modes can treat high watt draw as an effective temperature boost, which lets Core-Monitor respond to sustained load before raw temperature alone catches up.

Thermal readings come from SMC keys and ProcessInfo thermal state. The app must be honest about missing sensors: unsupported keys should show unavailable/fallback messaging rather than pretending exact measurements exist.
""",
    ),
    (
        "SMC-And-Apple-Silicon.md",
        "SMC And Apple Silicon",
        """
Core-Monitor reads AppleSMC values for thermals and fans. SMC value types handled in current docs and helper code include fixed-point and numeric forms such as `sp78`, `fpe2`, `flt`, `ui8`, and `ui16`.

Apple Silicon fan write behavior is not identical across machines. The helper probes mode-key formats (`F%dMd` vs `F%dmd`) and checks whether `Ftst` exists. It attempts direct manual-mode writes first and uses the force-test fallback only when required.

SMC code is duplicated in spirit across read-only app sampling and privileged helper write/read commands. Keep write-side validation in the helper, not only in the app, because the helper is the privileged boundary.
""",
    ),
    (
        "Fan-Control.md",
        "Fan Control",
        """
`FanController.swift` owns fan modes: Smart, System/Silent, Balanced, Performance, Max, Manual, Custom, and Automatic/System restoration.

Managed modes require the helper because they write fan targets. Monitoring itself does not. Smart mode blends the hottest CPU/GPU reading with system power draw. Balanced and Performance pin fans near fixed percentages of maximum. Manual writes a fixed RPM. Custom follows a persisted curve.

The UI should always explain who owns the fan curve: macOS firmware or Core-Monitor. If Core-Monitor owns it, quitting or switching to automatic should hand control back to the system best-effort.

Fan behavior can lag visibly on Apple Silicon. The guide copy intentionally warns users that a write can succeed before RPM changes are immediately obvious.
""",
    ),
    (
        "Custom-Fan-Curves.md",
        "Custom Fan Curves",
        """
Custom presets are modeled by `CustomFanPreset` and edited through `FanCurveEditorView.swift`. A preset includes a sensor source, curve points, optional update interval, smoothing step, RPM bounds, per-fan offsets, and optional power boost.

The editor constrains point movement, temperature range, speed range, nearest-handle selection, template application, and validation. Tests under `CustomFanPresetTests` and related curve editor geometry coverage protect these rules.

Custom curves are high-risk because they turn user configuration into hardware behavior. Validate bad JSON, invalid curve order, impossible RPM ranges, and fallback defaults defensively.
""",
    ),
    (
        "Privileged-Helper.md",
        "Privileged Helper",
        """
The helper is `smc-helper`, installed as `ventaphobia.smc-helper` under `/Library/PrivilegedHelperTools` with a LaunchDaemon plist. The app bundles it under `Contents/Library/LaunchServices` and blesses it through ServiceManagement.

`SMCHelperManager` is app-side. It detects missing/stale installs, blesses or repairs, probes XPC reachability, executes fan commands, reads SMC values, and exposes status messages.

`smc-helper/main.swift` is helper-side. It can run command-line commands such as `set`, `auto`, and `read`, or run as an NSXPC service. It opens AppleSMC, validates inputs, writes fan mode/target keys, and exposes control metadata.

The helper is optional. Documentation and UI should keep the monitoring-without-helper path clear.
""",
    ),
    (
        "XPC-Trust-Boundary.md",
        "XPC Trust Boundary",
        """
The trust boundary is the helper process, not SwiftUI. The app can request fan writes, but the helper must validate the client and input before performing privileged operations.

The helper validates fan IDs, RPMs, SMC key shape, and client authorization. The app manager validates state and user intent, but it cannot be the only protection layer because any XPC caller reaching the Mach service would otherwise be dangerous.

Entitlements, `SMPrivilegedExecutables`, `SMAuthorizedClients`, bundle IDs, Team IDs, helper labels, and signing requirements must remain aligned. The tests around privileged helper requirement strings exist because this alignment has broken before.
""",
    ),
    (
        "Helper-Diagnostics.md",
        "Helper Diagnostics",
        """
`HelperDiagnosticsExporter.swift` creates a JSON support report. It captures app version/build, bundle ID, macOS version, Mac model/chip, signing information, bundled and installed helper paths, helper install/connectivity state, fan-control backend metadata, launch-at-login status, menu bar reachability, and recovery recommendations.

The diagnostics report deliberately excludes telemetry, account data, shell history, historical sensor logs, and unrelated file contents. It is point-in-time support context.

Use it when helper install, fan writes, signing mismatch, launch-at-login, or menu bar visibility are involved. It is surfaced in the System tab and the welcome-guide readiness panel.
""",
    ),
    (
        "Touch-Bar-Architecture.md",
        "Touch Bar Architecture",
        """
Touch Bar support combines AppKit `NSTouchBar`, custom NSViews, Pock-style widget wrappers, and SwiftUI configuration UI.

`CoreMonTouchBarController` presents and rebuilds items. `TouchBarCustomizationCompatibility` persists layouts, pinned apps, pinned folders, custom command widgets, themes, presets, and compatibility migrations. `TouchBarUtilityWidgets`, `GroupViews`, `WeatherTouchBarView`, `NowPlayingTouchBarView`, and Pock widget sources render the visible strip.

The point of the Touch Bar layer is persistent quick access above other apps: live status, weather, launchers, folders, and scripts without dragging users back to the dashboard.

Private Touch Bar presentation code must be treated carefully because it can depend on undocumented AppKit behavior.
""",
    ),
    (
        "Touch-Bar-Customization.md",
        "Touch Bar Customization",
        """
The customization surface lets users combine built-in widgets, pinned apps, pinned folders, and custom shell command widgets. The active ordered layout is stored and previewed before application.

Pinned apps store path, display name, and bundle identifier when available. Pinned folders store path and display name. Custom command widgets store title, SF Symbol, command, and width. Tapping a command launches `/bin/zsh -lc`.

Persistence uses versioned configuration structs so older layouts can migrate forward. Any change to layout storage should include compatibility tests.
""",
    ),
    (
        "Weather-And-Location.md",
        "Weather And Location",
        """
Weather is optional and WeatherKit-dependent. `WeatherService.swift` abstracts providers and location access. `WeatherLocationAccessSection.swift`, `WeatherTouchBarItem.swift`, `WeatherTouchBarView.swift`, and the Pock Weather widget consume the model.

The critical behavior is permission gating. Weather should not trigger a location prompt at launch. The user must explicitly opt in. Builds without WeatherKit entitlement should show clear capability messaging instead of a vague failure.

Weather attribution is loaded separately and should respect appearance. Fallback coordinates and dormant states are tested because launch-time prompts were a real regression.
""",
    ),
    (
        "Privacy-And-Permissions.md",
        "Privacy And Permissions",
        """
The product promise is local-first monitoring. Sensor reads stay on the Mac. No account is required. The helper is optional. Weather location access is opt-in. Helper diagnostics are explicit export files, not background telemetry.

Privacy-sensitive areas include top-process sampling, disk process activity, battery/power information, helper diagnostics, location access, and custom command widgets.

UI copy should avoid implying that Core-Monitor uploads data. If future network features are added, they must be opt-in and documented in README, Help, and this wiki.
""",
    ),
    (
        "Onboarding-And-Help.md",
        "Onboarding And Help",
        """
The welcome guide explains launch behavior, menu bar reachability, Touch Bar features, helper readiness, diagnostics export, and first-run completion. `WelcomeGuideProgress` centralizes the seen flag so startup and the sheet agree.

The Help view includes searchable support sections. Search tests cover keyword matching so common queries such as helper, location, weather, alerts, login items, and menu bar recovery lead to relevant guidance.

The final onboarding path is intentionally readiness-oriented: users can see whether menu bar, launch-at-login, and helper states are ready instead of guessing.
""",
    ),
    (
        "Legacy-Alerts.md",
        "Legacy Alerts",
        """
Alert models, evaluation, and manager code remain in the repository, but the old Alerts screen surface was removed. That makes the current alert stack legacy or dormant, not a primary product surface.

`AlertEngine.swift`, `AlertModels.swift`, and `AlertManager.swift` still matter because tests and helper/service status concepts reference alert-style evaluation. However, current architecture docs warn not to extend this path unless alerts are intentionally reintroduced.

Removed alert UI files are documented in the Removed Parts section.
""",
    ),
    (
        "Kernel-Panic-Weird-Mode.md",
        "Kernel Panic Weird Mode",
        """
Kernel Panic is the app's fictional parody game. It lives in `KernelPanicGame.swift`, `KernelPanicMusicPlayer.swift`, `EasterEggLab.swift`, and bundled audio assets.

The game references historical malware names only as fictional boss themes. It must never implement real malware behavior, encryption, propagation, persistence, privilege escalation, scanning, or destructive payloads.

Release 14.08 centered on this feature, including bundled CC0 phase music and documentation in `docs/THIRD_PARTY_AUDIO.md`.
""",
    ),
    (
        "Testing-Strategy.md",
        "Testing Strategy",
        """
The macOS test target covers helper diagnostics, alert evaluation, fan presets, dashboard layout, weather, menu bar settings, top process sampling, launch environment, single-instance policy, formatters, disk stats refresh, localization/platform copy, and Touch Bar customization.

Run the full suite with `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.

For high-risk edits, add focused tests near the owner: helper trust, fan curve validation, startup/onboarding state, weather permission gating, menu bar reachability, and sampling policy.
""",
    ),
    (
        "Release-Automation.md",
        "Release Automation",
        """
The release path is source-controlled through GitHub Actions and scripts under `scripts/release/`. Public artifacts should be tested, Developer ID signed, notarized, stapled where applicable, and published as stable `Core-Monitor.dmg` and `Core-Monitor.app.zip` names with checksums.

`RELEASING.md` is the operational checklist. `build_release.sh`, `build_dmg.sh`, `notarize_release.sh`, `notarize_disk_image.sh`, and `generate_homebrew_cask.sh` implement the local/CI release pieces.

Release trust is product trust for a privileged-helper utility. Do not treat signing, notarization, entitlements, helper embedding, or cask updates as optional polish.
""",
    ),
    (
        "Mac-App-Store-Edition.md",
        "Mac App Store Edition",
        """
The Mac App Store edition is a distinct, sandbox-compatible product lane. Public README copy says it keeps read-only monitoring features that fit App Store rules and excludes helper, fan control, AppleSMC access, private-framework paths, and other elevated or non-App-Store behavior.

The repository contains `Mac-App-Store/` pages and mirrored docs under `docs/Mac-App-Store/` for support and privacy pages.

Do not assume a feature from the direct-download edition can ship in the App Store edition. Fan writes, privileged helper behavior, private Touch Bar paths, and direct AppleSMC access need separate review or exclusion.
""",
    ),
    (
        "Website-SEO-And-AI-Discovery.md",
        "Website SEO And AI Discovery",
        """
The repository includes a GitHub Pages website, structured data, screenshots, videos, `robots.txt`, `sitemap.xml`, `llms.txt`, and `llms-full.txt`. The AI discovery playbook documents how the project wants recommendation systems to understand the app.

There is current copy drift to watch: README describes macOS 13+, while `llms-full.txt` still says macOS 12 or later. Treat README, code launch gate, and release docs as the compatibility source of truth until discovery files are refreshed.

Keep public claims concrete: Apple Silicon, macOS, local-first, open source, menu bar, dashboard, thermals, power, battery, optional helper fan control, Touch Bar, and signed release artifacts.
""",
    ),
    (
        "Localization.md",
        "Localization",
        """
Localization uses `.xcstrings` catalogs for the app and helper Info.plist resources. `scripts/localization/generate_string_catalogs.py` supports catalog generation.

When changing user-facing strings in onboarding, Help, fan mode guidance, helper errors, or diagnostics, update string catalogs and tests where applicable.

Retired alert strings were explicitly removed in history, so do not reintroduce alert copy without deciding whether alerts are a current product surface again.
""",
    ),
    (
        "Assets-And-Media.md",
        "Assets And Media",
        """
Assets include app icons, accent colors, Pock weather/status icons, website screenshots, Gatekeeper walkthrough images, videos, and Kernel Panic audio.

Several media files were replaced or removed across history, including old walkthrough videos, screenshots, MP3 soundtrack files replaced by M4A assets, and stale UI images.

Keep source-control size in mind. App bundles, DerivedData, module caches, and generated build products have been removed before and should stay out of normal commits.
""",
    ),
    (
        "Security-Model.md",
        "Security Model",
        """
Security-sensitive areas are privileged helper behavior, XPC communication, fan control and SMC access, permission handling, local data exposure, signing, entitlements, and release packaging.

Security issues should be reported privately per `SECURITY.md`. General UI bugs and unsupported hardware issues belong in normal issue flow.

The strongest rule is simple: never trust the app process alone for privileged operations. Validate inside the helper. Keep helper diagnostics privacy-preserving. Keep notarized release and signing state reproducible.
""",
    ),
    (
        "Developer-Workflow.md",
        "Developer Workflow",
        """
Before editing, read `docs/ARCHITECTURE.md`, relevant feature files, and nearby tests. Prefer the smallest owner of behavior, add focused tests, build, run relevant tests, and inspect user-visible UI directly.

Do not hide broad refactors inside high-risk files. If a change crosses monitoring, helper, fan control, and UI boundaries, document the reason in the commit message and worklog.

Standard test command: `xcodebuild -project Core-Monitor.xcodeproj -scheme Core-Monitor -destination 'platform=macOS' CODE_SIGNING_ALLOWED=NO test`.
""",
    ),
    (
        "Troubleshooting.md",
        "Troubleshooting",
        """
If the app runs but menu bar items are missing, check macOS System Settings -> Menu Bar before assuming launch failed. If first launch is invisible, inspect welcome-guide state and activation policy.

If fan writes fail, export Helper Diagnostics from the System tab, check whether the helper is missing/reachable/unreachable, verify signing requirements, and confirm the installed helper/LaunchDaemon paths match the current app build.

If Weather fails, check WeatherKit entitlement capability and whether the user has explicitly granted location access. If sensors are missing, distinguish unsupported SMC keys from sampling failures.
""",
    ),
    (
        "Glossary.md",
        "Glossary",
        """
SMC: Apple System Management Controller interface used for thermals and fan values.

Helper: The privileged `smc-helper` process that performs fan writes and selected SMC reads.

Snapshot: A point-in-time `SystemMonitorSnapshot` containing the current telemetry model.

Freshness: The classification that tells whether telemetry is waiting, live, delayed, or stale.

Pock: The Touch Bar widget ecosystem/source layout that Core-Monitor adapts for status and weather widgets.

Direct-download edition: Signed/notarized DMG or ZIP build outside the Mac App Store, with helper/fan-control support.

Mac App Store edition: Sandboxed edition with read-only monitoring scope and no privileged helper/fan-control path.
""",
    ),
]


def generate_feature_pages(files: list[str], commits: list[CommitInfo]) -> None:
    for filename, title, body in FEATURE_PAGES:
        write_page(filename, title, body)

    write_page(
        "Wiki-Manifest.md",
        "Wiki Manifest",
        f"""
Generated: **{TODAY}**

| Metric | Count |
| --- | ---: |
| Tracked source files | {len(files)} |
| Reachable commits | {len(commits)} |
| Curated feature pages | {len(FEATURE_PAGES)} |

## Generation Method

- Source files come from `git ls-files`.
- Commit pages come from `git rev-list --reverse --branches --tags --remotes`.
- Stash refs are intentionally excluded from canonical commit pages.
- Deleted path data comes from commit diffs across the same reachable commit set.
- Existing modified source files in the working tree are not changed by the generator.
""",
    )


def generate_sidebar(files: list[str], commits: list[CommitInfo]) -> None:
    feature_links = "\n".join(f"- {file_link(filename, title)}" for filename, title, _ in FEATURE_PAGES[:24])
    write_page(
        "_Sidebar.md",
        "Sidebar",
        f"""
## Core

- {file_link('Home.md', 'Home')}
- {file_link('Start-Here.md', 'Start Here')}
- {file_link('Product-Overview.md', 'Product Overview')}
- {file_link('Runtime-Architecture.md', 'Runtime Architecture')}
- {file_link('Monitoring-Pipeline.md', 'Monitoring Pipeline')}
- {file_link('Fan-Control.md', 'Fan Control')}
- {file_link('Privileged-Helper.md', 'Privileged Helper')}
- {file_link('Touch-Bar-Architecture.md', 'Touch Bar')}
- {file_link('Release-Automation.md', 'Release Automation')}
- {file_link('Security-Model.md', 'Security Model')}

## Exhaustive Indexes

- {file_link('File-Index.md', f'File Index ({len(files)})')}
- {file_link('history/Every-Commit-Index.md', f'Every Commit ({len(commits)})')}
- {file_link('history/Chronological-Change-Log.md', 'Chronological Change Log')}
- {file_link('removed/Removed-Parts-Index.md', 'Removed Parts')}
- {file_link('removed/All-Deleted-Paths.md', 'All Deleted Paths')}
- {file_link('history/Branches-And-Tags.md', 'Branches And Tags')}
- {file_link('Wiki-Manifest.md', 'Wiki Manifest')}

## More Feature Pages

{feature_links}
""",
    )


def generate_home(files: list[str], commits: list[CommitInfo], deleted_count: int) -> None:
    write_page(
        "Home.md",
        "Core-Monitor Wiki",
        f"""
Generated on **{TODAY}** from the local Core-Monitor repository.

This wiki is intentionally exhaustive:

- **{len(FEATURE_PAGES)}** curated feature and architecture pages
- **{len(files)}** tracked-file pages
- **{len(commits)}** reachable commit pages
- **{deleted_count}** deleted or renamed-away paths in the removed-parts ledger

## Start Reading

- {file_link('Start-Here.md', 'Start Here')}
- {file_link('Product-Overview.md', 'Product Overview')}
- {file_link('Runtime-Architecture.md', 'Runtime Architecture')}
- {file_link('Monitoring-Pipeline.md', 'Monitoring Pipeline')}
- {file_link('Fan-Control.md', 'Fan Control')}
- {file_link('Privileged-Helper.md', 'Privileged Helper')}
- {file_link('Touch-Bar-Architecture.md', 'Touch Bar Architecture')}
- {file_link('Release-Automation.md', 'Release Automation')}
- {file_link('removed/Removed-Parts-Index.md', 'Removed Parts Index')}
- {file_link('history/Every-Commit-Index.md', 'Every Commit Index')}
- {file_link('File-Index.md', 'File Index')}

## Scope

The wiki covers the active macOS app, privileged helper, monitoring pipeline, fan control, menu bar, dashboard, Touch Bar, WeatherKit, onboarding, Help, support diagnostics, release automation, Mac App Store edition, website, tests, assets, retired parts, and commit-level history.

## Important Interpretation Notes

- Generated file pages reflect the current checkout plus git history.
- Generated commit pages reflect local, remote, branch, and tag reachable commits; stash commits are excluded.
- Some old docs intentionally document historical drift. For example, current README/release code position the app as macOS 13+, while `llms-full.txt` still says macOS 12 or later.
- Existing working-tree source modifications outside `docs/wiki/` were not overwritten.
""",
    )


def main() -> None:
    if WIKI.exists():
        shutil.rmtree(WIKI)
    WIKI.mkdir(parents=True, exist_ok=True)

    files = collect_files()
    commits = collect_commits()
    commit_links = generate_commit_pages(commits)
    file_links = generate_file_pages(files)
    deleted = collect_deleted_paths(commits)

    generate_feature_pages(files, commits)
    generate_removed_pages(deleted, commit_links)
    generate_indexes(commits, files, file_links, commit_links)
    generate_home(files, commits, len(deleted))
    generate_sidebar(files, commits)

    page_count = len(list(WIKI.rglob("*.md")))
    print(f"Generated {page_count} wiki pages in {WIKI}")
    print(f"Tracked files: {len(files)}")
    print(f"Reachable commits: {len(commits)}")
    print(f"Deleted paths: {len(deleted)}")


if __name__ == "__main__":
    main()
