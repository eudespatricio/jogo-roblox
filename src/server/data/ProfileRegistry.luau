--!strict
-- Registro de sessoes ativas por Player. Modulo compartilhado entre ProfileBoot (que carrega)
-- e WallController/Main (que usam o perfil). Sem API do Roblox alem do tipo `Player`; o
-- contrato headless nao carrega este arquivo.

local ProfileRegistry = {}

export type Session = any

local sessions: { [any]: Session } = {}

function ProfileRegistry.set(player: any, session: Session): ()
	sessions[player] = session
end

function ProfileRegistry.get(player: any): Session?
	return sessions[player]
end

function ProfileRegistry.clear(player: any): ()
	sessions[player] = nil
end

function ProfileRegistry.all(): { [any]: Session }
	return sessions
end

return ProfileRegistry
