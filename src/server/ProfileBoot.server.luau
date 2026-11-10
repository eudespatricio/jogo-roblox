--!strict
-- Liga o perfil (ProfileService + schema v2/contentVersion) aos jogadores do servidor.
-- Studio usa ProfileStore.Mock por padrao; o atributo booleano `ProfileStoreMock` em
-- ServerStorage forca o modo (true = Mock, false = DataStore real, precisa de API Services).
-- Atributo `ProfileSelfTest = true` (so no Studio) roda o teste de sessao automatico:
-- carrega, salva, recarrega e confere que nao duplicou. Roteiro: docs/teste-sessao-studio.md.

local Players = game:GetService("Players")
-- Sem avatar visivel (GDD §1): o cliente usa camera scriptable e o servidor nao spawna
-- personagem. O build/raid acontece na muralha, nao no corpo do jogador.
Players.CharacterAutoLoads = false
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerStorage = game:GetService("ServerStorage")

local ProfileService = require(script.Parent:WaitForChild("data"):WaitForChild("ProfileService"))
local ProfileRegistry = require(script.Parent:WaitForChild("data"):WaitForChild("ProfileRegistry"))
local AnalyticsService =
	require(script.Parent:WaitForChild("analytics"):WaitForChild("AnalyticsService"))
local ProfileSchema = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("data"):WaitForChild("ProfileSchema")
)
local TrapCatalog = require(
	ReplicatedStorage:WaitForChild("Shared"):WaitForChild("data"):WaitForChild("TrapCatalog")
)

local vendorFolder = ServerStorage:FindFirstChild("Vendor")
local vendorModule = vendorFolder and vendorFolder:FindFirstChild("ProfileStore")
if vendorModule == nil then
	error("ProfileStore vendorizado ausente em ServerStorage.Vendor (ver vendor/SOURCE.md)")
end
local ProfileStore = require(vendorModule :: ModuleScript)

local function resolveUseMock(): boolean
	local override = ServerStorage:GetAttribute("ProfileStoreMock")
	if override == true then
		return true
	elseif override == false then
		return false
	end
	return RunService:IsStudio()
end

local useMock = resolveUseMock()
local modeName = "DataStore"
if useMock then
	modeName = "Mock"
end
local store = ProfileStore.New(ProfileSchema.STORE_NAME, ProfileSchema.template())
local sessionStore: any = store
if useMock then
	sessionStore = store.Mock
end
print(string.format("[perfil] store=%s modo=%s", ProfileSchema.STORE_NAME, modeName))

local service = ProfileService.new({
	store = sessionStore,
	schema = ProfileSchema,
	now = function(): number
		return os.time()
	end,
	wait = function(seconds: number)
		task.wait(seconds)
	end,
	attempts = 3,
	retryDelay = 0.5,
	onStart = function(session, info)
		-- A S7 precisa do `days_since_last_seen` calculado ANTES de noteSeen sobrescrever
		-- lastSeenAt; guarda o info e o AnalyticsBoot consome no beginSession.
		if type(session.Key) == "string" then
			AnalyticsService.noteProfileStart(session.Key, info)
		end
		print(
			string.format(
				"[perfil] carregado key=%s schema=v%d content=v%d migrado=%s dias_desde_ultimo_acesso=%s",
				info.key,
				session.Data.schemaVersion,
				session.Data.contentVersion,
				tostring(info.migrated),
				tostring(info.daysSinceLastSeen)
			)
		)
	end,
	onEnd = function(session)
		print("[perfil] sessao encerrada key=" .. tostring(session.Key))
	end,
	onError = function(message, key)
		warn("[perfil] " .. message .. " (key=" .. tostring(key) .. ")")
	end,
})

local selfTestDone = false
local storeStatePrinted = false

local function profileKey(player: Player): string
	return ProfileSchema.keyFor(player.UserId)
end

local function utcStamp(seconds: number): string
	if seconds <= 0 then
		return "nunca"
	end
	local ok, formatted = pcall(os.date, "!%Y-%m-%dT%H:%M:%SZ", seconds)
	if ok and type(formatted) == "string" then
		return formatted
	end
	return "epoch=" .. tostring(seconds)
end

-- Diagnostico do Modo B: sem API Services o ProfileStore usa o mock interno DELE e nada e
-- salvo. Sem este aviso, o teste passaria com data store de mentira.
local function printStoreState()
	if storeStatePrinted then
		return
	end
	storeStatePrinted = true
	local state = ProfileStore.DataStoreState
	if type(state) ~= "string" then
		state = "NotReady"
	end
	print("[perfil] datastore=" .. state)
	if not useMock and state ~= "Access" then
		warn(
			"[perfil] MODO B INVALIDO: API Services indisponivel (datastore="
				.. state
				.. "); nada sera salvo. Publique o lugar e ligue o acesso do Studio."
		)
	end
end

-- Teste de sessao automatico (Studio, atributo ProfileSelfTest). Imprime evidencia no Output.
local function runSelfTest(player: Player, key: string)
	selfTestDone = true
	print("[selftest] inicio · modo=" .. modeName)
	local checks: { { name: string, passed: boolean, detail: string } } = {}
	local function record(name: string, passed: boolean, detail: string)
		table.insert(checks, { name = name, passed = passed, detail = detail })
		local status = "OK  "
		if not passed then
			status = "FALHA"
		end
		print(string.format("[selftest] %s %s · %s", status, name, detail))
	end

	local session = ProfileRegistry.get(player)
	if session == nil then
		record("perfil carregado", false, "sem sessao para o jogador")
	else
		local data = session.Data
		local sessionsBefore = data.stats.sessions
		local seenBefore = data.stats.lastSeenAt
		local goldBefore = data.gold
		local jsonOk, jsonErr = ProfileSchema.isJsonSafe(data)
		record(
			"carregou e migrou",
			data.schemaVersion == ProfileSchema.SCHEMA_VERSION
				and data.contentVersion == TrapCatalog.CONTENT_VERSION
				and jsonOk,
			string.format(
				"schema=v%d content=v%d gold=%d sessions=%d json=%s",
				data.schemaVersion,
				data.contentVersion,
				goldBefore,
				sessionsBefore,
				tostring(jsonErr)
			)
		)
		local validOk, validErr = ProfileSchema.validate(data)
		record("sem PII e so campos do schema", validOk, tostring(validErr))

		-- Espera o bastante para lastSeenAt mudar (a granularidade e 1 segundo)
		task.wait(1.1)
		local ended = service.endSession(key)
		-- EndSession salva e so depois libera o lock; sem esperar, StartSessionAsync acusa
		-- "already loaded in this session" (o controller ainda tentaria de novo).
		task.wait(1)
		record("EndSession no leave", ended, "activeCount=" .. tostring(service.activeCount()))

		local again, err = service.startSession(key)
		task.wait(0.1)
		if again == nil then
			record("recarregou do store", false, tostring(err))
		else
			ProfileRegistry.set(player, again)
			again:AddUserId(player.UserId)
			local after = again.Data
			record(
				"recarregou e nao duplicou",
				service.activeCount() == 1,
				"activeCount=" .. tostring(service.activeCount())
			)
			record(
				"sessions incrementou",
				after.stats.sessions == sessionsBefore + 1,
				string.format("%d -> %d", sessionsBefore, after.stats.sessions)
			)
			record(
				"lastSeenAt avancou",
				after.stats.lastSeenAt > seenBefore,
				utcStamp(seenBefore) .. " -> " .. utcStamp(after.stats.lastSeenAt)
			)
			record("gold persistiu", after.gold == goldBefore, tostring(after.gold))
			local afterOk, afterErr = ProfileSchema.validate(after)
			record("perfil salvo valido", afterOk, tostring(afterErr))
		end
	end

	local passed = 0
	for _, item in ipairs(checks) do
		if item.passed then
			passed += 1
		end
	end
	if passed == #checks and #checks > 0 then
		print(string.format("[selftest] PASSOU (%d/%d)", passed, #checks))
	else
		warn(string.format("[selftest] FALHOU (%d/%d)", passed, #checks))
	end
end

local function maybeSelfTest(player: Player, key: string)
	if selfTestDone or not RunService:IsStudio() then
		return
	end
	if ServerStorage:GetAttribute("ProfileSelfTest") ~= true then
		return
	end
	task.spawn(runSelfTest, player, key)
end

-- Grant de QA da S4 (somente Studio + Mock): ServerStorage.QaStarterGold/QaLeaguePoints
-- preenchem um perfil zerado para testar colocar/remover/upgrade e a catapulta (liga 5).
-- Nao roda fora do Studio, nao roda em DataStore real e nunca sobrescreve perfil com progresso.
local function applyQaGrant(data: any): boolean
	if not RunService:IsStudio() or not useMock then
		return false
	end
	local changed = false
	local gold = ServerStorage:GetAttribute("QaStarterGold")
	if type(gold) == "number" and gold % 1 == 0 and gold > 0 and data.gold == 0 then
		data.gold = math.min(gold, ProfileSchema.MAX_GOLD)
		changed = true
	end
	local points = ServerStorage:GetAttribute("QaLeaguePoints")
	if type(points) == "number" and points % 1 == 0 and points > 0 and data.league.points == 0 then
		data.league.points = math.min(points, ProfileSchema.MAX_COUNTER)
		changed = true
	end
	if changed then
		print(
			string.format(
				"[qa] grant gold=%d liga=%d (Studio/Mock; QaStarterGold/QaLeaguePoints)",
				data.gold,
				TrapCatalog.leagueOf(data.league.points)
			)
		)
	end
	return changed
end

local function loadPlayer(player: Player)
	local key = profileKey(player)
	local session, err = service.startSession(key)
	if session == nil then
		warn("[perfil] nao conseguiu abrir sessao (" .. tostring(err) .. "); recusando o jogador")
		player:Kick("Nao conseguimos carregar seu perfil agora. Entre de novo em alguns segundos.")
		return
	end
	if player.Parent ~= Players then
		service.endSession(key)
		return
	end
	session:AddUserId(player.UserId)
	local contentOk, contentErr, contentChanged = TrapCatalog.ensureProfileContent(session.Data)
	if not contentOk then
		warn("[perfil] conteudo recusado (" .. tostring(contentErr) .. "); devolvendo o lock")
		service.endSession(key)
		player:Kick("Seu perfil usa uma versao de conteudo mais nova. Atualize o jogo.")
		return
	end
	if contentChanged and type(session.Save) == "function" then
		local saveOk, saveErr = pcall(function()
			session:Save()
		end)
		if not saveOk then
			warn("[perfil] save pos-migracao de conteudo falhou: " .. tostring(saveErr))
		end
	end
	if contentChanged then
		print(string.format("[perfil] conteudo migrado content=v%d", session.Data.contentVersion))
	end
	applyQaGrant(session.Data)
	ProfileRegistry.set(player, session)
	player:SetAttribute("ProfileSchemaVersion", session.Data.schemaVersion)
	player:SetAttribute("ProfileContentVersion", session.Data.contentVersion)
	printStoreState()
	maybeSelfTest(player, key)
end

Players.PlayerAdded:Connect(function(player)
	task.spawn(loadPlayer, player)
end)

Players.PlayerRemoving:Connect(function(player)
	ProfileRegistry.clear(player)
	service.endSession(profileKey(player))
end)

-- Shutdown: fecha as sessoes para o ProfileStore gravar e liberar o lock.
game:BindToClose(function()
	for player in pairs(ProfileRegistry.all()) do
		service.endSession(profileKey(player))
	end
	task.wait(2)
end)

-- Jogadores que ja estavam no servidor (Play Solo no Studio).
for _, player in Players:GetPlayers() do
	task.spawn(loadPlayer, player)
end
