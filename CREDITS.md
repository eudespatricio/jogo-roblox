# Créditos, Ativos e Licenças — MURALHA / WALLBREAKER

Registro obrigatório para conformidade de IP, prevenção de *DMCA strikes* e auditoria de distribuição ([`docs/ferramentas.md`](docs/ferramentas.md) §5).

## 1. Bibliotecas & Código de Terceiros

| Ativo | Autor / Fonte | Licença | Uso no Projeto |
|---|---|---|---|
| `vendor/ProfileStore.luau` | MadStudio / tazmondo | Apache-2.0 (`vendor/LICENSE`) | Camada oficial de sessão/DataStore server-side (`MuralhaProfile_v1`) |
| `globalTypes.d.luau` | JohnnyMorganz / Roblox API dump | MIT | Definições de tipos Roblox para `luau-lsp` em `.tools/` (apenas dev/CI) |

## 2. Áudio, Fontes & Assets Procedurais Base (P1 / Playtest V1)

| Ativo | Origem | Licença | Observação |
|---|---|---|---|
| Cues placeholders S8 (`rbxasset://sounds/*`) | Biblioteca interna Roblox Studio | Termos de Uso Roblox | `electronicpingshort.wav`, `snap.mp3`, `impact_water.mp3`, `bass.wav`, `uuhhh.mp3` |
| Síntese CLI (`tools/gen-sfx.py`) | Projeto MURALHA (geração procedural Python + FFmpeg) | Proprietária / CC0 do projeto | Substitutos `.ogg` normalizados a `-14 LUFS` (EBU R128) até entrada de mixagem autoral |
| Geometria procedural (`art/scripts/*.py`) | Projeto MURALHA (Blender 4.5.15 LTS Python API) | Proprietária do projeto | Cena de calibração (`calibration.blend`) e portão pré-fraturado (`gate_fractured.glb`) |
| Tipografia (`Gotham` / `GothamBlack`) | Fontes embutidas Roblox Engine | Termos de Uso Roblox | Padronizada em `VisualTheme.UI` (`sim/visual-contract.luau`) |

## 3. Tabela de Registro Obrigatório para Novos Assets Externos (V1.5 / P2+)

Todo arquivo `.ogg`, `.png`, `.fbx`, `.glb` ou fonte importada de biblioteca externa deve ganhar uma linha aqui **antes do merge**:

| Arquivo em `assets/` ou `art/` | Autor | URL / Origem | Licença (CC0 / CC-BY / Comercial) | Data de Inclusão |
|---|---|---|---|---|
| *(aguardando importação de SFX/OST/Texturas P2+)* | — | — | — | — |
