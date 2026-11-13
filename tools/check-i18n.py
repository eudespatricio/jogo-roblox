#!/usr/bin/env python3
"""Valida assets/i18n/LocalizationTable.csv (PT-BR, EN, ES): completude, placeholders e teto mobile."""

from __future__ import annotations

import csv
import pathlib
import re
import sys

ROOT = pathlib.Path(__file__).resolve().parent.parent
CSV_PATH = ROOT / "assets" / "i18n" / "LocalizationTable.csv"
EXPECTED_HEADER = ["Key", "Context", "Example", "Source", "en", "es"]
LOCALES = ("Source", "en", "es")
FMT_RE = re.compile(r"%[0-9.]*[dfsxX%]")

PREFIX_LIMITS = (
    ("cta_", 12),
    ("mode_", 10),
    ("trap_name_", 14),
    ("unit_", 14),
    ("ping_", 18),
    ("toast_", 36),
    ("verb_", 38),
    ("diag_", 44),
)


def max_len_for(key: str) -> int | None:
    for prefix, limit in PREFIX_LIMITS:
        if key.startswith(prefix):
            return limit
    return None


def main() -> int:
    if not CSV_PATH.is_file():
        print(f"FAIL: arquivo ausente: {CSV_PATH}", file=sys.stderr)
        return 1

    with CSV_PATH.open("r", encoding="utf-8", newline="") as handle:
        reader = csv.DictReader(handle)
        if reader.fieldnames != EXPECTED_HEADER:
            print(
                f"FAIL: cabecalho esperado {EXPECTED_HEADER}, encontrado {reader.fieldnames}",
                file=sys.stderr,
            )
            return 1

        seen: set[str] = set()
        errors: list[str] = []
        rows = list(reader)

        if len(rows) < 40:
            errors.append(f"poucas chaves: {len(rows)} < 40")

        for idx, row in enumerate(rows, start=2):
            key = (row.get("Key") or "").strip()
            if not key:
                errors.append(f"linha {idx}: Key vazia")
                continue
            if key in seen:
                errors.append(f"linha {idx}: Key duplicada '{key}'")
            seen.add(key)

            placeholders: dict[str, list[str]] = {}
            limit = max_len_for(key)
            for loc in LOCALES:
                val = (row.get(loc) or "").strip()
                if not val:
                    errors.append(f"{key} [{loc}]: traducao vazia")
                    continue
                if limit is not None and len(val) > limit:
                    errors.append(
                        f"{key} [{loc}]: '{val}' excede teto mobile ({len(val)} > {limit})"
                    )
                placeholders[loc] = FMT_RE.findall(val)

            if len(placeholders) == len(LOCALES):
                base_fmt = placeholders["Source"]
                for loc in ("en", "es"):
                    if placeholders[loc] != base_fmt:
                        errors.append(
                            f"{key} [{loc}]: placeholders {placeholders[loc]} != Source {base_fmt}"
                        )

    if errors:
        for err in errors:
            print("FAIL:", err, file=sys.stderr)
        return 1

    print(f"I18N_OK keys={len(seen)} locales=pt-BR,en-US,es-419")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
