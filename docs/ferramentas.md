# Ferramentas e pipeline de qualidade — 09/11/2026

> Objetivo: responder "o que falta para entregar qualidade de ponta?" com o que **existe de fato**
> na máquina, não com uma lista de desejos. O que é ferramenta, o que é processo e o que é armadilha
> está separado de propósito.

---

## 1. Diagnóstico: o que já existe

| Camada | Ferramenta | Estado |
|---|---|---|
| Editor do jogo | **Roblox Studio** (Windows, `version-67c8b1dedbb74fed`) + plugin **Rojo** | ok |
| Código | **Rokit**: Rojo 7.7.1 · StyLua 2.6.0 · Selene 0.32.0 · Luau 0.746 | ok |
| 3D | **Blender 4.5.15 LTS** (`blender4.5`) e 4.2.0 (`blender`) | ok; 4.5 usa libs SM/ICE extraídas sem sudo |
| Tipos | **luau-lsp 1.70.1** | ok, em `~/.local/bin` |
| Scripts | **Lune 0.11.1** · **Pesde 0.7.4** · **rbxcloud 0.17.0** | ok, em `~/.local/bin` |
| Áudio/vídeo | **ffmpeg 7.0.2 static** (já existia) | ok |
| Imagem | **oxipng 10.2.1** | ok |
| GPU | RTX 3060 Laptop 6 GB · **Cycles lista CUDA** | ok (falta render de teste em GPU) |
| WSL | Ubuntu 26.04 · WSL 3.0.3 · WSLg (`DISPLAY=:0`) | ok |
| Git | git + GitHub (repo em `main`) + **git-lfs 3.8.1** | ok; falta configurar `.gitattributes` |
| Formatação/lint | StyLua **sem `stylua.toml`** e com drift; Selene **sem `selene.toml`** | pendente |
| Python | 3.14.4 (WSL) | ok |

Teste feito agora, com o Blender do WSL:

| Engine | 256×256, cena simples | Leitura |
|---|---:|---|
| Workbench | 2,3 s | preview rápido |
| EEVEE Next | 21,9 s | lento no WSLg (GL por software) |
| Cycles (CPU, 8 spp) | 0,3 s | bom para still; CUDA disponível |

Repetindo no **4.5.15 LTS**: Workbench 1,8 s · EEVEE 25,0 s · Cycles 0,4 s; CUDA também aparece.

**Veredito da camada 3D:** o Blender serve para produção headless (modelar, exportar, renderizar
thumbnails). Para modelagem interativa com EEVEE, o WSLg é desconfortável — a alternativa é instalar
o mesmo Blender 4.5 LTS no Windows, onde a GPU aparece inteira, e manter o WSL para batch/render.
O 4.5.15 LTS já está instalado no WSL como `blender4.5`; o `blender` antigo continua 4.2.

---

## 2. O que falta (por prioridade)

| # | Lacuna | Por que importa | Ferramenta | Custo |
|---|---|---|---|---|
| 1 | **Primeiro run do CI no GitHub** | workflow criado e check local verde; falta push/PR | GitHub Actions | 0 |
| 2 | **`.luaurc` strict + settings do editor** | luau-lsp e sourcemap já entram no check; falta o modo strict do projeto | `.luaurc` + `.vscode/settings.json` | 0 |
| 3 | **Primeiro asset real sob LFS** | `.gitattributes` cobre blend/gltf/png/wav/rbxm e `.gitignore` abre exceção em `assets/models` | criar o primeiro asset e commitar | 0 |
| 4 | **`pesde.toml` + ProfileStore** | Pesde instalado; falta inicializar o projeto e fixar a lib | `pesde init` + `pesde add` | 0 |
| 5 | **Pipeline de asset** (pastas, calibração, export) | hoje não há como levar Blender → Rojo de forma repetível | Blender + Studio 3D Importer + LFS | 0 |
| 6 | **2D/UI** | ícones, HUD, thumbnails, paleta | Krita + Inkscape + Figma | 0 |
| 7 | **Áudio/vídeo** | SFX, música, trailer, thumbnail animada | Audacity + FFmpeg + OBS | 0 |
| 8 | **Observabilidade** | D1/ARPDAU/erros sem telemetria não existem | AnalyticsService + schema próprio (GameAnalytics opcional) | 0 |
| 9 | **Publicação** | build → place sem clicar no Studio | rbxcloud 0.17.0 (Open Cloud) | 0 |
| 10 | **Performance/QA** | 60 fps em Android fraco não se adivinha | MicroProfiler + ScriptProfiler + device emulation | 0 |

### 2.1 Instalado em 09/11/2026 (sem sudo)

| Ferramenta | Versão | Onde |
|---|---|---|
| git-lfs | 3.8.1 | `~/.local/bin/git-lfs` |
| luau-lsp | 1.70.1 | `~/.local/bin/luau-lsp` |
| Lune | 0.11.1 | `~/.local/bin/lune` |
| Pesde | 0.7.4 | `~/.local/bin/pesde` |
| rbxcloud | 0.17.0 | `~/.local/bin/rbxcloud` |
| oxipng | 10.2.1 | `~/.local/bin/oxipng` |
| Blender | 4.5.15 LTS | `~/.local/bin/blender4.5` (o `blender` continua 4.2) |

`git lfs install --skip-repo` já foi rodado. O `ffmpeg 7.0.2` já estava em `~/.local/bin`.
Para scripts e agentes, use `source scripts/env.sh` — shell não-login não lê `.bashrc`.

### 2.2 Manual (precisa de sudo)

```bash
sudo apt update
sudo apt install -y krita inkscape audacity imagemagick pngquant optipng
# opcional, pesado:
sudo apt install -y obs-studio
```

No VS Code (Windows ou WSL Remote):

```bash
code --install-extension JohnnyMorganz.luau-lsp
code --install-extension evaera.vscode-rojo
```

Não há `libfuse2` no Ubuntu 26.04; por isso a recomendação é apt, não AppImage.

Nenhuma das dez custa licença. O custo é tempo de setup: **~1 dia** para 1–5, **~1 dia** para 6–7.
O `sudo` do WSL pede senha: sem ele, `git-lfs` e `ffmpeg` entram como binários estáticos em
`~/.local/bin`; Krita/Inkscape via AppImage (ou no Windows).

---

## 3. O kit mínimo desta semana (ordem de execução)

| Passo | Entrega | Tempo |
|---|---|---|
| 1 | `scripts/env.sh` (PATH determinístico: `~/.rokit/bin`, `~/.local/bin`) e `scripts/check.sh` | 1 h |
| 2 | `stylua.toml` + `selene.toml`; `stylua sim` uma vez (commit só de estilo; `src/` legado fica fora) | 2 h |
| 3 | `.github/workflows/ci.yml`: build + StyLua + Selene + invariantes + tetos | 2 h |
| 4 | `luau-lsp` no `rokit.toml`, `sourcemap.json` no check, `.luaurc` strict, `.vscode/settings.json` | 1 h |
| 5 | `git-lfs` no WSL + `.gitattributes` para binários + revisar `.gitignore` (hoje ignora `*.rbxm`) | 1 h |
| 6 | `pesde.toml` + `tazmondo/profilestore@1.0.5` (ou vendor oficial) + lockfile | 1 h |
| 7 | `art/` com `src/`, `export/`, `renders/`, `calibration.blend` e convenção de nomes | 3 h |
| 8 | Krita, Inkscape, FFmpeg, Audacity, OBS | 2 h |
| 9 | `docs/qualidade.md` com budgets e Definition of Done | 2 h |

O passo 7 é o que transforma "temos Blender" em "temos pipeline". Sem ele, cada asset vira uma
decisão nova de escala, eixo, nome e pivô.

---

## 4. Pipeline 3D: Blender (WSL) → Studio (Windows) → Rojo

### 4.1 Calibração (fazer uma vez, antes de qualquer asset)

O Blender é **Z-up** e usa unidades métricas; o Studio é **Y-up** e usa **studs**. Se isso não for
fixado, todo asset nasce torto ou no tamanho errado.

1. No Blender: `Scene > Units > Unit System = None`, `Rotation = Degrees`.
2. Escala: **1 unidade Blender = 1 stud**.
3. Criar `art/calibration.blend`: um cubo 4×1×2, uma seta apontando para a frente e um texto "FRENTE".
4. Exportar em `.gltf` e `.fbx`; importar no Studio com o **3D Importer**; conferir tamanho, eixo e
   pivô. O importador aceita `.fbx`, `.gltf` e `.obj` ([doc oficial](https://create.roblox.com/docs/en-us/art/modeling/3d-importer)).
5. Salvar o preset de importação do Studio como `MURALHA_Default`.

A doc oficial de Blender para Roblox cobre units/axes: [create.roblox.com/docs/art/blender](https://create.roblox.com/docs/art/blender).

### 4.2 Convenção de asset

| Tipo | Prefixo | Pivô | Escala | Triângulos (alvo) | Textura |
|---|---|---|---:|---:|---:|
| Armadilha | `TRAP_` | base, Z=0 | 1 | ≤ 1.500 | 512² |
| Segmento de muralha | `WALL_` | base, Z=0 | 1 | ≤ 500 | 256² |
| Comandante | `CMD_` | pés, Z=0 | 1 | ≤ 6.000 | 1024² |
| Prop de cenário | `PROP_` | base, Z=0 | 1 | ≤ 2.000 | 512² |
| Efeito | `VFX_` | origem | 1 | — | 256² (flipbook) |

Regras: aplicar transforms; sem escala negativa; nomes `PREFIXO_nome_variante` em minúsculas; um
material por mesh quando possível; sem nós procedurais no export (bake para textura).

### 4.3 Export e versionamento

- **Estático/PBR:** `.gltf`/`.glb` (mais limpo) — o Studio importa com PBR.
- **Rig/animação:** `.fbx` (o importador lê armature/skin/animation).
- Fonte: `art/src/*.blend` (LFS). Export: `art/export/*.gltf` (LFS). Importado: `assets/models/*.rbxm`
  (LFS) mapeado pelo Rojo para `ReplicatedStorage.Assets`.
- **Atenção:** o `.gitignore` atual ignora `*.rbxm` e `*.rbxmx` (linhas 8–9). Para versionar modelos
  importados, abrir exceção (`!assets/models/**/*.rbxm`) ou mudar a política — decidir antes do
  primeiro asset.
- Texturas: `art/textures/*.png` (LFS), 512/1024, sem alpha desnecessário; `pngquant`/`optipng` no
  check.

### 4.4 O que não fazer

- Não modelar no Studio e no Blender ao mesmo tempo (duas fontes de verdade).
- Não commitar `.rbxl` de build (já ignorado) nem `.blend1` (adicionar ao `.gitignore`).
- Não usar FBX com escala 100 (o importador já lida com escala; calibrar uma vez).
- Não criar LOD manual antes de medir o custo no device fraco.

---

## 5. 2D, UI, áudio e vídeo

| Necessidade | Ferramenta | Nota |
|---|---|---|
| UI/HUD, ícones, thumbnails | **Figma** (layout) + **Krita** (raster) + **Inkscape** (vetor) | exportar 1×/2×/3×; 9-slice no Studio |
| Texturas/pintura | **Krita**; **Material Maker** (opcional, procedural) | PBR: albedo, normal, roughness, metalness |
| SFX | **Audacity** + **jsfxr/BFXR** (8-bit) + Freesound (licença) | normalizar; OGG; SFX curtos |
| Música | **LMMS**/Ardour (opcional) ou licenciada | guardar licença em `CREDITS.md` |
| Vídeo/trailer | **FFmpeg** + **OBS** | cortes, legendas, thumbnail animada |
| Batch de imagem | **ImageMagick** + `pngquant` | redimensionar, otimizar, gerar ícones |

Licenças: manter `CREDITS.md` com fonte, autor e licença de cada fonte/textura/áudio. Qualidade de
ponta inclui não tomar strike.

---

## 6. Orçamentos de qualidade (proposta inicial, calibrar no 1º asset)

| Métrica | Alvo | Onde medir |
|---|---:|---|
| Batalha no servidor | ≤ 2 ms (hoje 1,3 ms) | `sim/poc.luau` |
| Frame no cliente | 60 fps em Android baixo | MicroProfiler / device emulation |
| Draw calls na cena | ≤ 500 | MicroProfiler |
| Triângulos por armadilha | ≤ 1.500 | Blender / Studio |
| Textura por armadilha | ≤ 512² | Blender / Studio |
| Partículas por armadilha | ≤ 3 emitters · ≤ 150 partículas | Studio |
| Tempo até a 1ª ação | ≤ 30 s | telemetria do funil |
| Primeira vitória | ≤ 60 s | telemetria |
| Join em 4G | ≤ 15 s | device real |
| Sessão | ≥ 8 min | Creator Analytics |

Sem orçamento, "qualidade" vira gosto. Com orçamento, vira critério de aceite.

---

## 7. Automação e confiança de código

### 7.1 O que entra no `scripts/check.sh`

```bash
mkdir -p build
rojo build default.project.json -o build/place.rbxl
stylua --check sim
luau-lsp analyze --platform=standard sim
luau sim/invariants.luau
luau sim/poc.luau
rojo sourcemap default.project.json -o sourcemap.json
python3 skills/context-recovery/scan_repo.py --root . --check
```

O [`scripts/check.sh`](../scripts/check.sh) já existe, roda esses passos e usa `scripts/env.sh` para o
PATH. Shell não-login não encontrava `rojo`/`blender`; isso era bug de reprodutibilidade, não detalhe.

### 7.2 CI (GitHub Actions)

- Runner Ubuntu; instalar Rokit; `rokit install`; rodar `scripts/check.sh`.
- Artefato: `build/place.rbxl`.
- Cache de `~/.rokit` e `~/.pesde`.
- Publicação com `rbxcloud` fica para depois (exige API key/segredo e um lugar de destino).

### 7.3 Tipos e lint

**StyLua está resolvido.** `stylua.toml` fixa coluna 100 e tabs; `stylua sim` formatou os três
arquivos com drift (`sim/audit-*.luau`, `sim/poc.luau`) e `stylua --check sim` passa. O `src/`
legado fica fora por `.styluaignore` até a P1.

**Selene está bloqueado, não é falta de config.** O `selene 0.32.0` (release de 01/10/2026) não
parseia atribuição composta do Luau: `total += 1` e `s -= ...` viram 82 parse errors em `sim/`.
Não há flag de Luau no CLI. Por isso o gate usa `luau-lsp analyze`, que entende a sintaxe.

- `luau-lsp` 1.70.1 + `rojo sourcemap` + `.luaurc` com `strict` (o `.luaurc` ainda falta).
- `stylua.toml` (coluna 100, tabs) — feito.
- `.vscode/settings.json`: format on save com StyLua, Luau LSP, sourcemap.

#### 7.3.1 Selene: por que não entrou no CI

| Evidência | Resultado |
|---|---|
| `selene sim` | 13 errors, 1 warning, **82 parse errors** |
| `sim/poc.luau:26` | `total += 1` → `unexpected token '+'` |
| `sim/audit-mul32.luau:7` | `s -= 4294967296` → `unexpected token '-'` |
| `selene generate-roblox-std` | gera `roblox.yml`, mas não corrige o parser |

Decisão: reavaliar quando o Selene suportar compound assignment; até lá, o lint é `luau-lsp analyze`
+ `stylua --check` + os invariantes.

### 7.4 Dependências

- **Pesde 0.7.4** (set/2026) está instalado e é o package manager ativo; **Wally 0.3.2** é de 2023.
- ProfileStore: `pesde add tazmondo/profilestore` (1.0.5) ou vendorizar o módulo oficial com commit
  fixado. A segunda opção é mais conservadora; a primeira dá lockfile.
- Evitar framework grande no MVP (Flamework/Knit/Replica). Escolher **uma** lib de UI e **uma** de
  networking só quando a P1 começar; trocar depois custa caro.

---

## 8. O que não instalar agora (armadilhas)

| Armadilha | Por quê |
|---|---|
| Wally | último release 2023; Pesde é o sucessor ativo |
| `run-in-roblox` | último release 2020; não é caminho para 2026 |
| Aftman | arquivado; Rokit já é o padrão do repo |
| Maya/3ds Max/ZBrush/Substance | custo e complexidade desproporcionais ao low-poly |
| `roblox-ts` | o projeto é Luau; migrar agora é reescrever |
| Framework de UI + networking + DI no dia 1 | acoplamento antes de ter UI e rede |
| Docker para "simular Roblox" | não simula Studio; o gargalo é o cliente |
| Dezenas de plugins do Studio | cada plugin é superfície de bug e de segurança |

---

## 9. O que "qualidade de ponta" significa neste jogo

Não é realismo: é **legibilidade e resposta**.

1. **Silhueta** de cada armadilha/comandante legível a 200 px (teste do thumbnail).
2. **Paleta** âmbar/ferro × verde-água, consistente em modelo, UI e VFX.
3. **Resposta** em ≤ 100 ms para toque (colocar, upgrade, cancelar).
4. **Replay** de 8 s que explica a derrota em 3 cortes de câmera.
5. **UI** de 2 fontes, 8 cores, 9-slice, safe area de celular.
6. **Som** com camadas (impacto, destruição, vitória) e mixagem -14 LUFS.
7. **60 fps** no aparelho mais fraco que o público usa.

Ferramenta nenhuma entrega isso sozinha; o que entrega é **orçamento + checklist + playtest**.

---

## 10. Fontes e versões

- [Roblox — 3D Importer](https://create.roblox.com/docs/en-us/art/modeling/3d-importer) (FBX/glTF/OBJ) · [Blender no Roblox](https://create.roblox.com/docs/art/blender) (units/axes)
- [luau-lsp 1.70.1](https://github.com/JohnnyMorganz/luau-lsp/releases/tag/1.70.1) (27/09/2026)
- [Pesde 0.7.4](https://github.com/pesde-pkg/pesde/releases/tag/v0.7.4%2Bregistry.0.2.3) (09/09/2026) · [Wally 0.3.2](https://github.com/UpliftGames/wally/releases/tag/v0.3.2) (2023)
- [Lune 0.11.1](https://github.com/lune-org/lune/releases/tag/v0.11.1) (21/10/2026)
- [rbxcloud 0.17.0](https://github.com/Sleitnick/rbxcloud/releases/tag/v0.17.0) (2025)
- [ProfileStore no Pesde](https://pesde.dev/packages/tazmondo/profilestore) (1.0.5) · [ProfileStore oficial](https://github.com/MadStudioRoblox/ProfileStore)
- [run-in-roblox 0.3.0](https://github.com/rojo-rbx/run-in-roblox/releases/tag/v0.3.0) (2020 — não usar)
