# Assets — MURALHA / WALLBREAKER

Diretório-fonte de áudio, UI 2D e modelos `.rbxm` gerenciados via Git LFS (`.gitattributes`) e sincronizados para Luau pelo **Asphalt** (`asphalt.toml`).

## Estrutura

- `assets/audio/sfx/` — 36 cues SFX mono 44.1 kHz `.ogg` (`-14 LUFS`, gerados/normalizados via `tools/gen-sfx.py` + `ffmpeg`).
- `assets/audio/bgm/` — stems verticais e temas por Ato estéreos 44.1 kHz `.ogg` (`-14 LUFS`, `120`/`132 BPM`).
- `assets/audio/stingers/` — stingers quantizados (Vitória, Derrota, Boss Intro, Finisher 8s).
- `assets/ui/` — ícones 2D, badges e texturas 9-slice (`pngquant`/`oxipng`, 1x/2x/3x).
- `assets/i18n/LocalizationTable.csv` — tabela oficial Roblox Studio (`PT-BR` / `EN` / `ES`), validada no CI via `python3 tools/check-i18n.py`.
- `assets/models/` — modelos `.rbxm`/`.rbxmx` importados do Blender via Studio (exceção no `.gitignore`).

## Comandos

```bash
source scripts/env.sh
asphalt sync debug    # valida manifesto localmente (.asphalt-debug/)
asphalt sync studio   # injeta assets locais no Roblox Studio sem upload
ASPHALT_API_KEY=... asphalt sync cloud  # gera asphalt.lock.toml para producao
```

Todo arquivo de terceiros deve ser registrado em [`../CREDITS.md`](../CREDITS.md).
