--!strict
-- Propriedades de funil do drop-in (taxonomia v1). O envelope/sink e a S7; a S5 produz e valida
-- as props no contrato headless e loga o ponto de funil no servidor.

local DropInTelemetry = {}

local function validMs(value: any): boolean
	return type(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
		and value % 1 == 0
end

function DropInTelemetry.shownProps(msSinceJoin: any): (any?, string?)
	if not validMs(msSinceJoin) then
		return nil, "bad_ms"
	end
	return { ms_since_join = msSinceJoin }, nil
end

function DropInTelemetry.pressedProps(msSinceJoin: any, pressed: any): (any?, string?)
	if not validMs(msSinceJoin) then
		return nil, "bad_ms"
	end
	if type(pressed) ~= "boolean" then
		return nil, "bad_pressed"
	end
	return { ms_since_join = msSinceJoin, pressed = pressed }, nil
end

-- Linha de log do funil enquanto o sink da S7 nao existe; nao substitui o envelope.
function DropInTelemetry.format(name: string, props: any): string
	local parts = { "[analytics]", name }
	if type(props) == "table" then
		local keys = {}
		for key in pairs(props) do
			keys[#keys + 1] = key
		end
		table.sort(keys)
		for _, key in ipairs(keys) do
			parts[#parts + 1] = string.format("%s=%s", key, tostring(props[key]))
		end
	end
	return table.concat(parts, " ")
end

return DropInTelemetry
