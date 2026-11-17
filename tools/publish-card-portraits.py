#!/usr/bin/env python3
"""Publica os 10 retratos 2D (512x768 PNG) dos cards de batalha no Roblox Open Cloud.

Uso:
    python3 tools/publish-card-portraits.py
    python3 tools/publish-card-portraits.py --force
"""

from __future__ import annotations

import argparse
import datetime as dt
import hashlib
import json
import os
import pathlib
import sys
import time

ROOT = pathlib.Path(__file__).resolve().parent.parent
CARDS_DIR = ROOT / "art" / "renders" / "cards"
LEDGER_PATH = ROOT / "art" / "renders" / "_logs" / "opencloud_v09_ledger.json"
KEY_PATH = pathlib.Path.home() / ".config" / "forge3d" / "roblox.key"
FORGE_SITE = (
    pathlib.Path.home()
    / ".local"
    / "share"
    / "uv"
    / "tools"
    / "forge3d"
    / "lib"
    / "python3.12"
    / "site-packages"
)

CREATOR_ID = "11966727684"
CREATOR_TYPE = "user"

CARD_IDS = (
    "bastion_warden",
    "bastion_commander",
    "horde_brute",
    "horde_runner",
    "horde_shieldbearer",
    "boss_iron_ram_colossus",
    "boss_slag_juggernaut",
    "boss_rime_matriarch",
    "boss_powder_baron",
    "boss_rift_titan",
)


def sha256_file(path: pathlib.Path) -> str:
    h = hashlib.sha256()
    with path.open("rb") as fh:
        for chunk in iter(lambda: fh.read(65536), b""):
            h.update(chunk)
    return h.hexdigest()


def load_api_key() -> str:
    env_key = os.environ.get("ROBLOX_API_KEY", "").strip()
    if env_key:
        return env_key
    if KEY_PATH.is_file():
        key = KEY_PATH.read_text(encoding="utf-8").strip()
        if key:
            return key
    raise RuntimeError(f"ROBLOX_API_KEY ausente e {KEY_PATH} nao encontrado")


def load_ledger() -> dict[str, dict]:
    if LEDGER_PATH.is_file():
        return json.loads(LEDGER_PATH.read_text(encoding="utf-8"))
    return {}


def save_ledger(data: dict[str, dict]) -> None:
    LEDGER_PATH.parent.mkdir(parents=True, exist_ok=True)
    tmp = LEDGER_PATH.with_suffix(".json.tmp")
    tmp.write_text(json.dumps(data, indent=2, sort_keys=True) + "\n", encoding="utf-8")
    tmp.replace(LEDGER_PATH)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--force", action="store_true", help="Reenvia mesmo com sha256 igual")
    parser.add_argument("--dry-run", action="store_true", help="Valida arquivos sem enviar")
    args = parser.parse_args()

    sys.path.insert(0, str(FORGE_SITE))
    from forge3d import upload as forge_upload

    api_key = "" if args.dry_run else load_api_key()
    ledger = load_ledger()

    results: dict[str, int] = {}
    for card_id in CARD_IDS:
        png_path = CARDS_DIR / f"{card_id}.png"
        if not png_path.is_file():
            raise FileNotFoundError(f"Retrato ausente: {png_path}")

        file_hash = sha256_file(png_path)
        ledger_key = f"cards.{card_id}"
        prev = ledger.get(ledger_key)
        if (
            not args.force
            and isinstance(prev, dict)
            and prev.get("sha256") == file_hash
            and isinstance(prev.get("asset_id"), int)
            and prev["asset_id"] > 0
        ):
            results[card_id] = prev["asset_id"]
            print(f"[SKIP] {card_id} -> rbxassetid://{prev['asset_id']} (unchanged)")
            continue

        display_name = f"Muralha_Card_{card_id}"
        res = forge_upload.executar(
            png_path,
            asset_type="Image",
            nome=display_name,
            descricao=f"Muralha champion/boss card splash portrait ({card_id})",
            creator_id=CREATOR_ID,
            creator_type=CREATOR_TYPE,
            key=api_key,
            dry_run=args.dry_run,
            intervalo=2.0,
            max_espera=300.0,
            strip_embedded_textures=False,
        )
        asset_id = int(res.get("asset_id") or 0)
        results[card_id] = asset_id
        print(f"[UP] {card_id} -> rbxassetid://{asset_id} ({res.get('moderation', '?')})")

        if not args.dry_run and asset_id > 0:
            ledger[ledger_key] = {
                "asset_id": asset_id,
                "asset_type": "Image",
                "bytes": int(res.get("bytes") or png_path.stat().st_size),
                "display_name": display_name,
                "file": str(png_path),
                "moderation": str(res.get("moderation") or "Reviewing"),
                "sha256": file_hash,
                "ts": dt.datetime.now(dt.timezone.utc).strftime("%Y-%m-%dT%H:%M:%SZ"),
            }
            save_ledger(ledger)
            time.sleep(0.5)

    print("\n=== CARD_PORTRAIT_IDS ===")
    print(json.dumps(results, indent=2, sort_keys=True))
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
