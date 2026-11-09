# jogo-roblox

Projeto Roblox com **Rojo**: o codigo vive em arquivos `.luau` aqui no disco, versionados no Git,
e o Rojo sincroniza com o Roblox Studio. Nada de editar script dentro do Studio e perder historico.

## Estado atual

MVP jogavel: um mapa com 30 moedas girando, HUD de contagem, `leaderstats` e persistencia em
`DataStore` (as moedas continuam com o jogador depois de sair).

```
jogo-roblox/
  default.project.json        mapeia pastas do disco -> servicos do Roblox
  rokit.toml                  versao do Rojo
  src/
    shared/Config.luau        numeros e cores do jogo
    server/Main.server.luau   ponto de entrada do servidor
    server/DataService.luau   load/save no DataStore
    server/CoinService.luau   spawn, giro e coleta das moedas
    client/Hud.client.luau    HUD que le o leaderstats
    world/*.model.json        baseplate e spawn
  .tools/rojo.exe             binario local (fora do Git)
```

## Como rodar

1. Abra o **Roblox Studio** e crie um lugar vazio (`Baseplate` serve).
2. No terminal, na pasta do projeto:

   ```powershell
   .\.tools\rojo.exe serve
   ```

3. No Studio: aba **Plugins** -> **Rojo** -> **Connect** (padrao `localhost:34872`).
4. Aperte **Play** (F5). As moedas aparecem, o HUD conta e o save acontece ao sair.

> O plugin do Rojo precisa estar instalado em `%LOCALAPPDATA%\Roblox\Plugins\Rojo.rbxm`.
> Se o Studio ja estava aberto quando ele foi instalado, reinicie o Studio.

Sem plugin? Gere um lugar pronto e abra o arquivo:

```powershell
.\.tools\rojo.exe build default.project.json -o build\jogo.rbxlx
```

## Publicar

1. **File > Publish to Roblox** no Studio.
2. Nome, descricao, icone e thumbnails.
3. **Game Settings**: dispositivos suportados, genero, e deixe **privado** ate testar com amigos.
4. Para monetizar: passes/produtos em `create.roblox.com`, e `MarketplaceService` no codigo.

## Proximos passos (ordem sugerida)

1. Trocar a moeda por uma mecanica central (ver "genero" abaixo).
2. `ProfileStore` no lugar do DataService simples (session locking real).
3. Loja com `MarketplaceService:PromptGamePassPurchase`.
4. Tutorial/onboarding nos primeiros 30 segundos.
5. Analytics + teste com 5 pessoas antes de divulgar.

## Regras que valem desde o dia 1

- Servidor manda, cliente pede. Nunca confie em valor vindo de `RemoteEvent`.
- Todo texto de jogador passa por filtro (`TextChatService` / `TextService`).
- `DataStore` sempre com `pcall` + retry: falha transitoria e normal.
- Teste em **Start Server + 2 Players** desde cedo; bug de multiplayer so aparece ali.
