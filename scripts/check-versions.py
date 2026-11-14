#!/usr/bin/env python3
"""Gate de versoes (GAP-007): fonte executavel x bloco de docs/versoes.md.

Compara `ProfileSchema.SCHEMA_VERSION`, `TrapCatalog.CONTENT_VERSION`,
`Core.SIM_VERSION`, o hash de referencia da seed 42 (`sim/acceptance.luau`)
e `AnalyticsTypes.SCHEMA_VERSION` (taxonomia, P2)
com o bloco documentado. Falha o processo se qualquer valor divergir.

Uso:
    python3 scripts/check-versions.py            # valida e imprime o resumo
    python3 scripts/check-versions.py --values   # valida e imprime "schema content sim hash analytics"
"""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DOC = ROOT / "docs" / "versoes.md"
SCHEMA_SOURCE = ROOT / "src" / "shared" / "data" / "ProfileSchema.luau"
CONTENT_SOURCE = ROOT / "src" / "shared" / "data" / "TrapCatalog.luau"
SIM_SOURCE = ROOT / "src" / "shared" / "sim" / "core.luau"
HASH_SOURCE = ROOT / "sim" / "acceptance.luau"
ANALYTICS_SOURCE = ROOT / "src" / "shared" / "analytics" / "AnalyticsTypes.luau"

START = "<!-- VERSOES:INICIO -->"
END = "<!-- VERSOES:FIM -->"
KEYS = ("schema", "content", "sim", "hash", "analytics")


def fail(message: str) -> None:
    print(f"FALHA: {message}", file=sys.stderr)
    raise SystemExit(1)


def read(path: Path) -> str:
    try:
        return path.read_text(encoding="utf-8")
    except OSError as exc:
        fail(f"nao consegui ler {path.relative_to(ROOT)}: {exc}")
    raise AssertionError("inalcancavel")


def source_version(path: Path, pattern: str, label: str) -> int:
    matches = re.findall(pattern, read(path), flags=re.MULTILINE)
    if len(matches) != 1:
        fail(
            f"{label}: esperava 1 ocorrencia em {path.relative_to(ROOT)}, "
            f"achei {len(matches)}"
        )
    return int(matches[0])


def doc_block() -> dict[str, int]:
    text = read(DOC)
    if text.count(START) != 1 or text.count(END) != 1:
        fail(
            f"{DOC.relative_to(ROOT)}: precisa de exatamente um {START} "
            f"e um {END}"
        )
    body = text.split(START, 1)[1].split(END, 1)[0]
    values: dict[str, int] = {}
    for raw in body.splitlines():
        line = raw.strip()
        if not line:
            continue
        match = re.fullmatch(r"([a-z]+)=(\d+)", line)
        if match is None:
            fail(f"{DOC.relative_to(ROOT)}: linha invalida no bloco: {raw!r}")
        key, value = match.group(1), int(match.group(2))
        if key not in KEYS:
            fail(f"{DOC.relative_to(ROOT)}: chave desconhecida no bloco: {key}")
        if key in values:
            fail(f"{DOC.relative_to(ROOT)}: chave repetida no bloco: {key}")
        values[key] = value
    missing = [key for key in KEYS if key not in values]
    if missing:
        fail(f"{DOC.relative_to(ROOT)}: bloco sem {', '.join(missing)}")
    return values


def collect() -> dict[str, int]:
    return {
        "schema": source_version(
            SCHEMA_SOURCE,
            r"ProfileSchema\.SCHEMA_VERSION\s*=\s*(\d+)",
            "SCHEMA_VERSION",
        ),
        "content": source_version(
            CONTENT_SOURCE,
            r"TrapCatalog\.CONTENT_VERSION\s*=\s*(\d+)",
            "CONTENT_VERSION",
        ),
        "sim": source_version(
            SIM_SOURCE,
            r"Core\.SIM_VERSION\s*=\s*(\d+)",
            "SIM_VERSION",
        ),
        "hash": source_version(
            HASH_SOURCE,
            r"\br\.hash\s*==\s*(\d+)",
            "hash de referencia (seed 42)",
        ),
        "analytics": source_version(
            ANALYTICS_SOURCE,
            r"AnalyticsTypes\.SCHEMA_VERSION\s*=\s*(\d+)",
            "AnalyticsTypes.SCHEMA_VERSION",
        ),
    }


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--values",
        action="store_true",
        help='imprime "schema content sim hash analytics" e cala o resumo',
    )
    args = parser.parse_args()

    source = collect()
    docs = doc_block()
    divergences = [
        f"{key}: fonte={source[key]} docs={docs[key]}"
        for key in KEYS
        if source[key] != docs[key]
    ]
    if divergences:
        fail(
            "versao divergente entre fonte e docs/versoes.md -> "
            + "; ".join(divergences)
        )

    if args.values:
        print(" ".join(str(source[key]) for key in KEYS))
    else:
        print(
            "OK: versoes fonte x docs: "
            f"schema={source['schema']} content={source['content']} "
            f"sim={source['sim']} hash={source['hash']} "
            f"analytics={source['analytics']}"
        )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
