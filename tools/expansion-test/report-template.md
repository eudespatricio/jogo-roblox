# Relatório de trial de expansão — <nome>

- **Data:** <dd/mm/aaaa>
- **Branch/commit do trial:** `trial/<nome>` · `<hash>`
- **Base da main:** `<hash>`
- **Tipo:** conteúdo | economia | schema | motor | evento | cosmético

## 1. Escopo do trial

O que foi implementado de propósito, e o que ficou de fora.

## 2. Versões

| Versão | Antes | Depois |
|---|---|---|
| `ProfileSchema.SCHEMA_VERSION` | | |
| `TrapCatalog.CONTENT_VERSION` | | |
| `Core.SIM_VERSION` | | |

## 3. Arquivos tocados

| Área | Arquivos | O que mudou |
|---|---|---|
| schema | | |
| catálogo | | |
| serviço | | |
| motor | | |
| testes | | |
| docs | | |

## 4. Evidências

| Prova | Resultado |
|---|---|
| hash base (seed 42) | |
| hash da variante | |
| migração v<n>→v<atual> | |
| migração neutra (hash antigo x migrado) | |
| perfil inválido recusado? | |
| invariantes | |
| acceptance | |
| contrato de perfil | |
| contrato de analytics | |
| contrato de muralha | |
| `doctor.sh` / `check.sh` | |
| `scan_repo.py --check` | |
| CI (se pushado) | |

## 5. Gaps descobertos

| ID | Gap | Risco | Gatilho |
|---|---|---|---|
| | | | |

## 6. Veredito

- O pipeline aguentou? Onde doeu?
- O que precisa fechar antes de um merge real?
- O trial foi limpo? A main ficou limpa?
- Patch/reporte preservado em quê?
