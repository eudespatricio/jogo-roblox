# Estação de trabalho — manual operacional (09/11/2026)

> Objetivo: qualquer pessoa (ou agente) reconstruir, verificar e usar a estação sem depender de
> memória. O **porquê** de cada ferramenta e os orçamentos de qualidade estão em
> [`ferramentas.md`](ferramentas.md). Este arquivo é o **como**.

---

## 0. Checklist antes de trabalhar

```bash
cd ~/jogo-roblox
source scripts/env.sh          # PATH de ~/.rokit/bin e ~/.local/bin
bash scripts/doctor.sh         # a estação está completa? (não altera nada)
bash scripts/check.sh          # gate: build + StyLua + luau-lsp + invariantes + contexto
```

Depois:

1. Abrir o **Roblox Studio** (Windows) e o plugin **Rojo**.
2. No WSL: `rojo serve` (escuta `127.0.0.1:34872`).
3. No plugin: conectar em `localhost:34872`. **Nunca** `--address 0.0.0.0`.
4. Para arte: `art/calibration.blend` e [`../art/README.md`](../art/README.md).

---

## 1. Inventário

| Ferramenta | Versão | Onde | Papel | Obrigatória |
|---|---|---|---|---|
| git | 2.x | `/usr/bin/git` | versionamento | sim |
| git-lfs | 3.8.1 | `~/.local/bin/git-lfs` | binários grandes | sim |
| Python | 3.14.4 | `/usr/bin/python3` | scanner/script | sim |
| Rojo | 7.7.1 | `~/.rokit/bin/rojo` | build/sync Studio | sim |
| StyLua | 2.6.0 | `~/.rokit/bin/stylua` | formato | sim |
| Selene | 0.32.0 | `~/.rokit/bin/selene` | lint **bloqueado** (ver §7) | não |
| Luau | 0.746 | `~/.rokit/bin/luau` | executar sim/oráculo | sim |
| luau-lsp | 1.70.1 | `~/.local/bin/luau-lsp` | tipos/editor/CI | sim |
| Lune | 0.11.1 | `~/.local/bin/lune` | scripts headless | não |
| Pesde | 0.7.4 | `~/.local/bin/pesde` | pacotes Luau | não |
| rbxcloud | 0.17.0 | `~/.local/bin/rbxcloud` | Open Cloud/publicação | não |
| ffmpeg | 7.0.2 static | `~/.local/bin/ffmpeg` | áudio/vídeo/thumb | sim |
| oxipng | 10.2.1 | `~/.local/bin/oxipng` | otimizar PNG | não |
| Blender | 4.5.15 LTS | `~/.local/bin/blender4.5` | 3D/render | sim |
| Blender legado | 4.2.0 | `~/.local/bin/blender` | compatibilidade | não |
| Krita | 6.0.1 | `/usr/bin/krita` | textura/UI raster | não |
| Inkscape | 1.4.3 | `/usr/bin/inkscape` | vetor/ícones | não |
| Audacity | 3.7.7 | `/usr/bin/audacity` | edição de áudio | não |
| ImageMagick | 7.1.2 | `/usr/bin/magick` | batch de imagem | não |
| pngquant | 4.0.3 | `/usr/bin/pngquant` | compressão PNG | não |
| optipng | 7.9.1 | `/usr/bin/optipng` | compressão PNG | não |
| OBS | 32.1.0 | `/usr/bin/obs` | captura/trailer | não |
| Roblox Studio | `version-67c8b1…` | Windows | editor/publicação | sim |
| Plugin Rojo | — | `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm` | sync | sim |

Hardware: RTX 3060 Laptop 6 GB (Cycles CUDA), WSL 3.0.3, Ubuntu 26.04, ~868 GB livres.

---

## 2. Configs do repo

| Arquivo | Para quê |
|---|---|
| `.luaurc` | `languageMode = strict` para todo Luau |
| `stylua.toml` | coluna 100, tabs, LF |
| `.styluaignore` | mantém `src/` legado fora do formato |
| `.vscode/settings.json` | Luau LSP + sourcemap + StyLua on save |
| `scripts/env.sh` | PATH determinístico |
| `scripts/doctor.sh` | auditoria da estação |
| `scripts/check.sh` | gate de qualidade |
| `.github/workflows/ci.yml` | CI no GitHub |
| `.gitattributes` | LFS (blend/gltf/png/wav/rbxm…) |
| `.gitignore` | builds, `roblox.yml`, renders; exceção em `assets/models` |

---

## 3. Reconstruir do zero (WSL novo)

### 3.1 Pacotes com sudo

```bash
sudo apt update
sudo apt install -y krita inkscape audacity imagemagick pngquant optipng
# opcional, pesado:
sudo apt install -y obs-studio
```

### 3.2 Rokit + ferramentas fixadas

```bash
cd ~/jogo-roblox
bash scripts/setup-wsl.sh          # instala Rokit e roda o oráculo
```

### 3.3 Ferramentas CLI sem sudo

```bash
bash scripts/install-tools.sh      # git-lfs, luau-lsp, Lune, Pesde, rbxcloud, oxipng
```

### 3.4 Blender 4.5 LTS (sem sudo)

```bash
mkdir -p ~/.local/blender
curl -fL https://download.blender.org/release/Blender4.5/blender-4.5.15-linux-x64.tar.xz -o /tmp/blender.tar.xz
tar -xJf /tmp/blender.tar.xz -C ~/.local/blender
```

O Blender 4.5 precisa de `libSM`/`libICE`, que o Ubuntu 26.04 não traz por padrão. Sem sudo:

```bash
mkdir -p ~/.local/lib/blender45
cd /tmp
apt-get download libsm6 libice6
for d in ./*.deb; do dpkg -x "$d" ~/.local/lib/blender45; done
```

E o wrapper `~/.local/bin/blender4.5`:

```bash
#!/usr/bin/env bash
BL="$HOME/.local/blender/blender-4.5.15-linux-x64"
export LD_LIBRARY_PATH="$HOME/.local/lib/blender45/usr/lib/x86_64-linux-gnu:$BL/lib:${LD_LIBRARY_PATH:-}"
exec "$BL/blender" "$@"
```

### 3.5 Extensões do VS Code

```bash
code --install-extension JohnnyMorganz.luau-lsp
code --install-extension JohnnyMorganz.stylua
code --install-extension evaera.vscode-rojo
```

### 3.6 Conferir

```bash
source scripts/env.sh
bash scripts/doctor.sh
bash scripts/check.sh
```

---

## 4. Blender: calibração e export

A cena de calibração existe em `art/calibration.blend`; o gerador é
`art/scripts/make_calibration.py`. Regenerar:

```bash
blender4.5 -b --factory-startup --python art/scripts/make_calibration.py
```

O que ela prova: **1 unidade = 1 stud**, cubo 1×1×1, barra 4 studs no X, seta em `-Y` (frente no
Blender). No Studio, a seta deve apontar para `-Z`. Importação: **File → Import 3D** →
`art/export/calibration.glb`, **Scale Unit = Studs**, **World Forward = Front**, **World Up = Top**.
Detalhes e convenção de nomes em [`../art/README.md`](../art/README.md).

---

## 5. Editor e tipos

- `.luaurc` deixa o projeto em **strict**. `luau-lsp analyze --platform=standard sim` roda no check.
- `.vscode/settings.json` liga sourcemap automático (`default.project.json`), tipos Roblox e StyLua
  ao salvar. As extensões precisam estar instaladas no VS Code (Windows ou WSL Remote).
- O sourcemap é gerado por `rojo sourcemap default.project.json -o sourcemap.json` (ignorado pelo git).

---

## 6. Git, LFS e CI

```bash
git lfs install --skip-repo     # uma vez por máquina
git lfs status
bash scripts/check.sh
```

- LFS cobre `.blend`, `.blend1`, `.fbx`, `.gltf`, `.glb`, `.obj`, `.rbxm`, `.rbxmx`, `.png`, `.jpg`,
  `.webp`, `.psd`, `.kra`, `.xcf`, `.wav`, `.mp3`, `.ogg`, `.ttf`, `.otf`.
- `.gitignore` abre exceção para `assets/models/**/*.rbxm` (modelos importados).
- CI: `.github/workflows/ci.yml`; runs #1 e #2 verdes em 09/11/2026.

Se o push falhar com `refusing to allow a Personal Access Token to create or update workflow`:

1. usar **SSH** (`git remote set-url origin git@github.com:…`), ou
2. criar PAT com **Workflows: Read and write** (fine-grained) / escopo `workflow` (classic) e trocar a
   credencial salva.

---

## 7. Troubleshooting

| Sintoma | Causa | Correção |
|---|---|---|
| `rojo: command not found` / `blender: command not found` | shell não-login não lê `.bashrc` | `source scripts/env.sh` |
| `stylua --check` falha | arquivo recém-editado | `stylua sim` (ou `stylua .` se não for legado) |
| Selene com dezenas de `parse_error` | Selene 0.32 não entende `+=`/`-=` do Luau | usar `luau-lsp analyze`; Selene fora do CI |
| Blender 4.5: `libSM.so.6: cannot open shared object` | faltam libSM/libICE | repetir §3.4 (extrair debs + wrapper) |
| EEVEE lento no WSL | WSLg renderiza por software | usar Cycles/Workbench headless, ou Blender no Windows |
| Studio não conecta no Rojo | endereço/firewall | `rojo serve` em `127.0.0.1:34872`; plugin em `localhost:34872`; não usar `0.0.0.0` |
| push rejeitado por workflow | PAT sem escopo | SSH ou PAT com `workflow` |
| CI vermelho e local verde | versão/ambiente do runner | abrir o log do step `Check`; o runner instala as mesmas versões |
| `doctor.sh` acusa ferramenta | PATH ou instalação | `source scripts/env.sh`; `scripts/install-tools.sh`; apt |

---

## 8. O que ainda falta (não é a estação)

1. ProfileStore vendorizado; wrapper + schema v1 da camada de dados (P0). `pesde.toml` fica para a 2ª dependência.
2. Primeiro asset real de armadilha (calibração já feita).
3. Teste de produto de 3 semanas antes da P1 — ver [`revisao-direcao.md`](revisao-direcao.md).
