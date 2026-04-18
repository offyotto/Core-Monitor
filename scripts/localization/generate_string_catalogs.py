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
        ("el", "el"),
        ("eo", "eo"),
        ("es", "es"),
        ("et", "et"),
        ("eu", "eu"),
        ("fa", "fa"),
        ("fi", "fi"),
        ("fil", "tl"),
        ("fr", "fr"),
        ("fy", "fy"),
        ("ga", "ga"),
        ("gd", "gd"),
        ("gl", "gl"),
        ("gn", "gn"),
        ("gu", "gu"),
        ("ha", "ha"),
        ("haw", "haw"),
        ("he", "he"),
        ("hi", "hi"),
        ("hmn", "hmn"),
        ("hr", "hr"),
        ("ht", "ht"),
        ("hu", "hu"),
        ("hy", "hy"),
        ("id", "id"),
        ("ig", "ig"),
        ("is", "is"),
        ("it", "it"),
        ("ja", "ja"),
        ("jv", "jw"),
        ("ka", "ka"),
        ("kk", "kk"),
        ("km", "km"),
        ("kn", "kn"),
        ("ko", "ko"),
        ("ku", "ku"),
        ("ky", "ky"),
        ("la", "la"),
        ("lb", "lb"),
        ("lo", "lo"),
        ("lt", "lt"),
        ("lv", "lv"),
        ("mg", "mg"),
        ("mi", "mi"),
        ("mk", "mk"),
        ("ml", "ml"),
        ("mn", "mn"),
        ("mr", "mr"),
        ("ms", "ms"),
        ("mt", "mt"),
        ("my", "my"),
        ("ne", "ne"),
        ("nl", "nl"),
        ("nb", "no"),
        ("ny", "ny"),
        ("or", "or"),
        ("pa", "pa"),
        ("pl", "pl"),
        ("ps", "ps"),
        ("pt", "pt"),
        ("ro", "ro"),
        ("ru", "ru"),
        ("rw", "rw"),
        ("sd", "sd"),
        ("si", "si"),
        ("sk", "sk"),
        ("sl", "sl"),
        ("sm", "sm"),
        ("sn", "sn"),
        ("so", "so"),
        ("sq", "sq"),
        ("sr", "sr"),
        ("st", "st"),
        ("su", "su"),
        ("sv", "sv"),
        ("sw", "sw"),
        ("ta", "ta"),
        ("te", "te"),
        ("tg", "tg"),
        ("th", "th"),
        ("tr", "tr"),
        ("uk", "uk"),
        ("ur", "ur"),
        ("uz", "uz"),
        ("vi", "vi"),
        ("xh", "xh"),
        ("yi", "yi"),
        ("yo", "yo"),
        ("zh-Hans", "zh-CN"),
        ("zh-Hant", "zh-TW"),
        ("zu", "zu"),
    ]
)

PLACEHOLDER_RE = re.compile(r"%(?:\d+\$)?(?:@|lld|ld|d|f|\.?\d*f|%)+")
PURE_TECHNICAL_RE = re.compile(r"^[\s0-9%°./,:;()\-+@\"'•[\]{}]+$")
SENTINEL = "@@COREMON_SEP@@"
TOKEN_PREFIX = "ZXQ"
TOKEN_RE = re.compile(rf"{TOKEN_PREFIX}(?:PH|TM)\d{{4}}QXZ")
PROTECTED_TERMS = (
    "Core-Monitor",
    "Core Monitor",
    "Touch Bar",
    "WeatherKit",
    "AppleSMC",
    "macOS",
    "MacBook",
    "GitHub",
    "JSON",
    "RPM",
    "CPU",
    "GPU",
    "SMC",
    "Wi-Fi",
    "SF Symbol",
)


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate machine-translated string catalogs for Core-Monitor."
    )
    parser.add_argument("--project", default="Core-Monitor.xcodeproj")
    parser.add_argument("--scheme", default="Core-Monitor")
    parser.add_argument("--root", default=".")
    parser.add_argument("--workers", type=int, default=6)
    parser.add_argument(
        "--languages",
        nargs="*",
        help="Optional list of Xcode language codes to generate. Defaults to 100+ locales.",
    )
    return parser.parse_args()


def log(message: str) -> None:
    print(message, flush=True)


def export_catalog_sources(root: Path, project: str, scheme: str) -> dict[str, dict]:
    def load_catalog(export_root: Path, relative_path: str) -> dict:
        export_path = export_root / relative_path
        if export_path.exists():
            return json.loads(export_path.read_text())

        repo_path = root / relative_path
        if repo_path.exists():
            log(f"Using existing {relative_path} because Xcode did not export it.")
            return json.loads(repo_path.read_text())

        raise FileNotFoundError(f"Missing catalog source: {relative_path}")

    with tempfile.TemporaryDirectory(prefix="coremonitor-loc-export-") as temp_dir:
        log("Exporting source strings from Xcode…")
        subprocess.run(
            [
                "xcodebuild",
                "-exportLocalizations",
                "-project",
                project,
                "-scheme",
                scheme,
                "-localizationPath",
                temp_dir,
            ],
            cwd=root,
            check=True,
            stdout=subprocess.DEVNULL,
        )
        xcloc = Path(temp_dir) / "en.xcloc" / "Source Contents"
        return {
            "Core-Monitor/Localizable.xcstrings": load_catalog(
                xcloc, "Core-Monitor/Localizable.xcstrings"
            ),
            "Core-Monitor/App-InfoPlist.xcstrings": load_catalog(
                xcloc, "Core-Monitor/App-InfoPlist.xcstrings"
            ),
            "smc-helper/InfoPlist.xcstrings": load_catalog(
                xcloc, "smc-helper/InfoPlist.xcstrings"
            ),
        }


def source_value(key: str, entry: dict) -> str:
    english = (
        entry.get("localizations", {})
        .get("en", {})
        .get("stringUnit", {})
        .get("value")
    )
    return english if english is not None else key


def should_translate(key: str, entry: dict, value: str) -> bool:
    if entry.get("shouldTranslate") is False:
        return False
    if not value.strip():
        return False
    if PURE_TECHNICAL_RE.fullmatch(value):
        return False
    if not re.search(r"[A-Za-z]", value):
        return False
    if len(value) <= 4 and value.upper() == value:
        return False
    if value in PROTECTED_TERMS:
        return False
    return True


def protect_text(text: str) -> tuple[str, dict[str, str]]:
    mapping: dict[str, str] = {}
    next_index = 0

    def make_token(kind: str) -> str:
        nonlocal next_index
        token = f"{TOKEN_PREFIX}{kind}{next_index:04d}QXZ"
        next_index += 1
        return token

    def protect_match(match: re.Match[str], kind: str) -> str:
        token = make_token(kind)
        mapping[token] = match.group(0)
        return token

    protected = PLACEHOLDER_RE.sub(lambda match: protect_match(match, "PH"), text)

    for term in sorted(PROTECTED_TERMS, key=len, reverse=True):
        protected = re.sub(
            re.escape(term),
            lambda match: protect_match(match, "TM"),
            protected,
        )

    return protected, mapping


def restore_text(text: str, mapping: dict[str, str]) -> str:
    restored = text
    for token, original in mapping.items():
        restored = restored.replace(token, original)
    return restored


def translate_batch(translator_code: str, batch: list[str]) -> list[str]:
    joined = f"\n{SENTINEL}\n".join(batch)
    url = (
        "https://translate.googleapis.com/translate_a/single"
        f"?client=gtx&sl=en&tl={urllib.parse.quote(translator_code)}"
        f"&dt=t&q={urllib.parse.quote(joined)}"
    )
    with urllib.request.urlopen(url, timeout=30) as response:
        payload = json.loads(response.read().decode("utf-8"))
    translated = "".join(part[0] for part in payload[0])
    return translated.split(f"\n{SENTINEL}\n")


def translate_language(
    language_code: str,
    translator_code: str,
    items: list[tuple[str, str]],
) -> tuple[str, dict[str, str]]:
    translated: dict[str, str] = {}
    pending: list[tuple[str, str]] = []
    current_size = 0

    def flush() -> None:
        nonlocal pending, current_size
        if not pending:
            return

        payload = [text for _, text in pending]
        for attempt in range(3):
            try:
                outputs = translate_batch(translator_code, payload)
                if len(outputs) != len(payload):
                    raise RuntimeError("batch delimiter mismatch")
                for (key, _), translated_text in zip(pending, outputs):
                    translated[key] = translated_text
                pending = []
                current_size = 0
                return
            except Exception:
                if attempt == 2:
                    for key, protected_text in pending:
                        translated[key] = protected_text
                    pending = []
                    current_size = 0
                    return
                time.sleep(1.5 * (attempt + 1))

    for key, protected_text in items:
        projected = current_size + len(protected_text) + len(SENTINEL) + 4
        if pending and projected > 2400:
            flush()
        pending.append((key, protected_text))
        current_size += len(protected_text) + len(SENTINEL) + 4

    flush()
    return language_code, translated


def build_catalogs(
    catalogs: dict[str, dict],
    languages: OrderedDict[str, str],
    workers: int,
) -> dict[str, dict]:
    prepared_catalogs: dict[str, dict] = {}
    all_translatables: OrderedDict[str, tuple[str, dict[str, str]]] = OrderedDict()

    for catalog_path, catalog in catalogs.items():
        for key, entry in catalog["strings"].items():
            value = source_value(key, entry)
            localizations = entry.setdefault("localizations", {})
            localizations["en"] = {
                "stringUnit": {
                    "state": "translated",
                    "value": value,
                }
            }

            if should_translate(key, entry, value):
                protected_text, mapping = protect_text(value)
                all_translatables[(catalog_path + "::" + key)] = (protected_text, mapping)

        prepared_catalogs[catalog_path] = catalog

    items = list(all_translatables.items())
    protected_items = [(item_key, text) for item_key, (text, _) in items]
    mappings = {item_key: mapping for item_key, (_, mapping) in items}

    log(f"Generating translations for {len(languages)} locales…")
    locale_outputs: dict[str, dict[str, str]] = {}
    with ThreadPoolExecutor(max_workers=workers) as executor:
        futures = {
            executor.submit(
                translate_language,
                language_code,
                translator_code,
                protected_items,
            ): language_code
            for language_code, translator_code in languages.items()
        }

        completed = 0
        for future in as_completed(futures):
            language_code, translated_map = future.result()
            fixed_map: dict[str, str] = {}
            for key, value in translated_map.items():
                restored = restore_text(value, mappings[key])
                if TOKEN_RE.search(restored):
                    restored = restore_text(all_translatables[key][0], mappings[key])
                fixed_map[key] = restored
            locale_outputs[language_code] = fixed_map
            completed += 1
            log(f"  [{completed}/{len(languages)}] {language_code}")

    for catalog_path, catalog in prepared_catalogs.items():
        for key, entry in catalog["strings"].items():
            value = source_value(key, entry)
            if entry.get("shouldTranslate") is False:
                continue

            full_key = catalog_path + "::" + key
            if full_key not in all_translatables:
                for language_code in languages:
                    entry.setdefault("localizations", {})[language_code] = {
                        "stringUnit": {
                            "state": "translated",
                            "value": value,
                        }
                    }
                continue

            for language_code in languages:
                translated_value = locale_outputs[language_code].get(full_key, value)
                entry.setdefault("localizations", {})[language_code] = {
                    "stringUnit": {
                        "state": "translated",
                        "value": translated_value,
                    }
                }

    return prepared_catalogs


def write_catalogs(root: Path, catalogs: dict[str, dict]) -> None:
    for relative_path, catalog in catalogs.items():
        destination = root / relative_path
        destination.parent.mkdir(parents=True, exist_ok=True)
        destination.write_text(
            json.dumps(catalog, ensure_ascii=False, indent=2, sort_keys=True) + "\n"
        )
        log(f"Wrote {destination.relative_to(root)}")


def parse_languages(args: argparse.Namespace) -> OrderedDict[str, str]:
    if not args.languages:
        return DEFAULT_LANGUAGES

    requested = OrderedDict()
    for code in args.languages:
        if code not in DEFAULT_LANGUAGES:
            raise SystemExit(f"Unsupported language code: {code}")
        requested[code] = DEFAULT_LANGUAGES[code]
    return requested


def main() -> int:
    args = parse_args()
    root = Path(args.root).resolve()
    languages = parse_languages(args)
    catalogs = export_catalog_sources(root, args.project, args.scheme)
    localized_catalogs = build_catalogs(catalogs, languages, args.workers)
    write_catalogs(root, localized_catalogs)
    log(f"Done. Generated {len(languages)} locales.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
