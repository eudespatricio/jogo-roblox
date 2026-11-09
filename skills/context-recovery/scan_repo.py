#!/usr/bin/env python3
"""Radiografia determinística de repositório (context-recovery, fase 1).

Zero LLM. Lê o disco, o git e (opcionalmente) a AST do Luau e devolve fatos brutos:
topografia de código e docs, idade relativa, símbolos, órfãos de teste e alertas.

Uso:
    python scan_repo.py --root . --out .context/radiografia.md --json .context/radiografia.json
    python scan_repo.py --root . --check          # valida tetos do contexto residente

Requisitos: Python 3.9+, git opcional, luau-ast opcional (--ast caminho).
"""
from __future__ import annotations

import argparse
import json
import os
import re
import subprocess
import sys
from datetime import date
from pathlib import Path

CODE_EXT = {".luau", ".lua"}
DOC_EXT = {".md"}
IGNORE_DIRS = {".git", ".tools", "build", "node_modules", ".context", "skills", "__pycache__"}
CONFIG_EXT = {".toml", ".json", ".yml", ".yaml"}
TEST_HINT = re.compile(r"(^|/)(test|tests|spec|specs)(/|_)|\.test\.|\.spec\.|invariants", re.I)
REQUIRE_RE = re.compile(r"""require\s*\(\s*([^)]*?)\s*\)""")
FUNC_RE = re.compile(r"^\s*(?:local\s+)?function\s+([A-Za-z_][\w.:]*)\s*\(", re.M)

CONTEXT_CAPS = {"ESTADO.md": 80, "MAPA.md": 60, "REJEITADOS.md": 40}


def sh(args: list[str], cwd: Path) -> str:
    try:
        return subprocess.run(
            args,
            cwd=cwd,
            capture_output=True,
            text=True,
            encoding="utf-8",
            errors="replace",
            timeout=20,
            check=False,
        ).stdout.strip()
    except Exception:
        return ""


def git_date(root: Path, rel: str) -> str:
    out = sh(["git", "log", "-1", "--format=%cs", "--", rel], root)
    return out or "-"


def git_has_repo(root: Path) -> bool:
    return sh(["git", "rev-parse", "--is-inside-work-tree"], root) == "true"


def walk_files(root: Path) -> list[Path]:
    files: list[Path] = []
    for base, dirs, names in os.walk(root):
        dirs[:] = [d for d in dirs if d not in IGNORE_DIRS]
        for n in names:
            p = Path(base) / n
            if p.suffix.lower() in CODE_EXT | DOC_EXT | CONFIG_EXT:
                files.append(p)
    return sorted(files)


def loc(p: Path) -> int:
    try:
        return sum(1 for _ in p.open("r", encoding="utf-8", errors="replace"))
    except OSError:
        return 0


def ast_symbols(ast_exe: Path | None, p: Path) -> dict:
    """Extrai funções top-level e requires via luau-ast; fallback regex."""
    text = p.read_text(encoding="utf-8", errors="replace")
    result = {"functions": [], "requires": [], "source": "regex"}
    if ast_exe and ast_exe.exists():
        out = sh([str(ast_exe), str(p)], p.parent)
        if out.startswith("{"):
            try:
                tree = json.loads(out)
                funcs, reqs = [], []

                def visit(node):
                    if isinstance(node, dict):
                        t = node.get("type")
                        if t == "AstStatFunction":
                            nm = node.get("name", {})
                            if nm.get("type") == "AstExprIndexName":
                                funcs.append(nm.get("index", "?"))
                            elif nm.get("type") == "AstExprLocal":
                                funcs.append(nm.get("local", {}).get("name", "?"))
                        elif t == "AstStatLocalFunction":
                            funcs.append(node.get("name", {}).get("name", "?"))
                        elif t == "AstExprCall":
                            fn = node.get("func", {})
                            if fn.get("type") == "AstExprGlobal" and fn.get("global") == "require":
                                args = node.get("args", [])
                                if args and args[0].get("type") == "AstExprConstantString":
                                    reqs.append(args[0].get("value", "?"))
                        for v in node.values():
                            visit(v)
                    elif isinstance(node, list):
                        for v in node:
                            visit(v)

                visit(tree)
                result = {"functions": sorted(set(funcs)), "requires": sorted(set(reqs)), "source": "ast"}
                return result
            except json.JSONDecodeError:
                pass
    result["functions"] = sorted(set(FUNC_RE.findall(text)))
    result["requires"] = sorted(set(REQUIRE_RE.findall(text)))
    return result


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=".")
    ap.add_argument("--out", default=".context/radiografia.md")
    ap.add_argument("--json", default=".context/radiografia.json")
    ap.add_argument("--ast", default="")
    ap.add_argument("--check", action="store_true")
    args = ap.parse_args()

    root = Path(args.root).resolve()
    if args.check:
        bad = 0
        for name, cap in CONTEXT_CAPS.items():
            p = root / ".context" / name
            if not p.exists():
                print(f"FALTA  .context/{name}")
                bad += 1
                continue
            n = loc(p)
            status = "OK " if n <= cap else "ESTOUROU"
            print(f"{status} .context/{name}: {n}/{cap} linhas")
            if n > cap:
                bad += 1
        return 1 if bad else 0

    ast_exe = Path(args.ast).resolve() if args.ast else None
    files = walk_files(root)
    code = [p for p in files if p.suffix.lower() in CODE_EXT]
    docs = [p for p in files if p.suffix.lower() in DOC_EXT]
    configs = [p for p in files if p.suffix.lower() in CONFIG_EXT]

    meta = {}
    for p in files:
        rel = str(p.relative_to(root)).replace("\\", "/")
        meta[rel] = {
            "loc": loc(p),
            "bytes": p.stat().st_size,
            "git_date": git_date(root, rel) if git_has_repo(root) else "-",
            "kind": "code" if p.suffix.lower() in CODE_EXT else "doc" if p.suffix.lower() in DOC_EXT else "config",
        }

    code_sorted = sorted((m for m in meta.items() if m[1]["kind"] == "code"), key=lambda kv: -kv[1]["loc"])
    doc_sorted = sorted((m for m in meta.items() if m[1]["kind"] == "doc"), key=lambda kv: -kv[1]["loc"])

    test_files = [p for p in code if TEST_HINT.search(str(p.relative_to(root)).replace("\\", "/"))]
    tested_text = "\n".join(p.read_text(encoding="utf-8", errors="replace") for p in test_files)
    orphans = []
    for p in code:
        if TEST_HINT.search(str(p.relative_to(root)).replace("\\", "/")):
            continue
        stem = p.stem.split(".")[0]
        if stem and stem not in tested_text:
            orphans.append(str(p.relative_to(root)).replace("\\", "/"))

    symbols = {}
    for p in code:
        rel = str(p.relative_to(root)).replace("\\", "/")
        symbols[rel] = ast_symbols(ast_exe, p)

    latest_code = max((m["git_date"] for m in meta.values() if m["kind"] == "code" and m["git_date"] != "-"), default="-")
    stale_docs = []
    for rel, m in meta.items():
        if m["kind"] == "doc" and m["git_date"] != "-" and latest_code != "-" and m["git_date"] < latest_code:
            stale_docs.append((rel, m["git_date"], latest_code))

    alerts = []
    for rel, m in code_sorted:
        if m["loc"] > 400:
            alerts.append(f"monolito: {rel} com {m['loc']} linhas")
    if not test_files:
        alerts.append("nenhum arquivo de teste encontrado (cobertura de oráculos = 0)")
    for rel in orphans[:10]:
        alerts.append(f"módulo sem referência em teste: {rel}")

    data = {
        "root": str(root),
        "generated": date.today().isoformat(),
        "counts": {"code": len(code), "docs": len(docs), "configs": len(configs), "test_files": len(test_files)},
        "code": code_sorted,
        "docs": doc_sorted,
        "stale_docs": stale_docs,
        "orphans": orphans,
        "symbols": symbols,
        "alerts": alerts,
    }

    out_md = root / args.out
    out_json = root / args.json
    out_md.parent.mkdir(parents=True, exist_ok=True)

    L = []
    L.append("# Radiografia determinística\n")
    L.append(f"Gerado em {data['generated']} · zero LLM · `scan_repo.py`\n")
    L.append("## Resumo\n")
    L.append("| Item | Valor |\n|---|---|")
    L.append(f"| arquivos de código | {len(code)} |")
    L.append(f"| arquivos de documentação | {len(docs)} |")
    L.append(f"| arquivos de configuração | {len(configs)} |")
    L.append(f"| arquivos de teste | {len(test_files)} |")
    L.append(f"| último commit de código | {latest_code} |\n")

    L.append("## Top 10 código (onde moram os monolitos)\n")
    L.append("| Arquivo | Linhas | Bytes | Último commit |\n|---|---:|---:|---|")
    for rel, m in code_sorted[:10]:
        L.append(f"| `{rel}` | {m['loc']} | {m['bytes']} | {m['git_date']} |")
    L.append("")

    L.append("## Documentação (idade vs. código)\n")
    L.append("| Documento | Linhas | Último commit | Defasado? |\n|---|---:|---|---|")
    for rel, m in doc_sorted:
        flag = "SIM" if (rel, m['git_date'], latest_code) in stale_docs else "não"
        L.append(f"| `{rel}` | {m['loc']} | {m['git_date']} | {flag} |")
    L.append("")

    L.append("## Cobertura de oráculos\n")
    if test_files:
        L.append("Testes encontrados: " + ", ".join(f"`{str(p.relative_to(root)).replace(chr(92), '/')}`" for p in test_files) + "\n")
    else:
        L.append("**Nenhum teste.** Toda regra de negócio hoje vive em prosa.\n")
    if orphans:
        L.append("Módulos não referenciados por teste:\n")
        for rel in orphans:
            L.append(f"- `{rel}`")
        L.append("")

    L.append("## Símbolos extraídos\n")
    L.append("| Arquivo | Funções | Requires | Fonte |\n|---|---|---|---|")
    for rel, s in symbols.items():
        fns = ", ".join(s["functions"][:8]) or "-"
        reqs = ", ".join(s["requires"][:6]) or "-"
        L.append(f"| `{rel}` | {fns} | {reqs} | {s['source']} |")
    L.append("")

    L.append("## Alertas\n")
    if alerts:
        for a in alerts:
            L.append(f"- {a}")
    else:
        L.append("- nenhum")
    L.append("")

    out_md.write_text("\n".join(L), encoding="utf-8")
    out_json.write_text(json.dumps(data, indent=2, ensure_ascii=False), encoding="utf-8")
    print(f"ok: {out_md}")
    print(f"ok: {out_json}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
