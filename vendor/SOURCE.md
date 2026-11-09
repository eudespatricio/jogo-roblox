# ProfileStore — vendorizado

Código de terceiros. **Não editar**: qualquer mudança vai no wrapper nosso, nunca neste arquivo.

| Campo | Valor |
|---|---|
| Projeto | [MAD STUDIO — ProfileStore](https://github.com/MadStudioRoblox/ProfileStore) |
| Autor | loleris / MAD STUDIO |
| Commit fixado | `45c9847cbcf1fc260369c50eb335aba7c35aecdd` (2025-07-31) |
| Arquivo | `ProfileStore.luau` (2.242 linhas) |
| SHA-256 | `ad43737203688b8e88cab34ebe8c483000c157e53bfb41e35f1b49ee89d0c95f` |
| Licença | Apache-2.0 — texto completo em [`LICENSE`](LICENSE) |
| Mapeamento | `ServerStorage.Vendor.ProfileStore` (ver `default.project.json`) |

## Por que vendorizado

- É um ModuleScript único; não precisa de registry nem de rede no CI.
- O lockfile de um package manager não substitui o pin de commit para auditoria.
- O pacote `pesde/scripts_rojo` seria necessário para ligar dependências Pesde ao Rojo; evitamos
  essa camada até existir uma segunda dependência.

## Como atualizar

1. Conferir o commit novo no repositório oficial e a licença.
2. Trocar `ProfileStore.luau` e `LICENSE`; atualizar commit e SHA-256 nesta tabela.
3. Rodar `bash scripts/check.sh` (build + invariantes) e testar o fluxo de sessão no Studio.
4. Não alterar o módulo para "ajustar" o jogo: o wrapper e o schema v1 ficam em `src/server/data/`
   na P0.

## Status

Vendorizado em 09/11/2026. **Wrapper, schema v1, migração e testes de sessão ainda não existem** —
são P0 e continuam bloqueados até a autorização da fase.
