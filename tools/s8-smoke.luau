--!nonstrict
-- Smoke de runtime da S8 para rodar no Studio (edit mode) via run-in-roblox:
--   run-in-roblox --place build/place.rbxl --script tools/s8-smoke.luau
-- Constroi arena/traps/horda/UI/VFX, valida os modelos e limpa. Nao e um teste visual de render;
-- e o teste de que os modulos e as APIs usadas existem no Studio real.

local function Main(): ()
	local RunService = game:GetService("RunService")
	print(
		string.format(
			"[s8-smoke] contexto client=%s server=%s",
			tostring(RunService:IsClient()),
			tostring(RunService:IsServer())
		)
	)
	local Players = game:GetService("Players")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")
	local StarterGui = game:GetService("StarterGui")
	local StarterPlayer = game:GetService("StarterPlayer")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local VisualTheme = require(Shared:WaitForChild("visual"):WaitForChild("VisualTheme"))
	local visual = StarterPlayer:WaitForChild("StarterPlayerScripts"):WaitForChild("visual")
	local UiKit = require(visual:WaitForChild("UiKit"))
	local VisualSetup = require(visual:WaitForChild("VisualSetup"))
	local ArenaVisual = require(visual:WaitForChild("ArenaVisual"))
	local TrapKit = require(visual:WaitForChild("TrapKit"))
	local HordeKit = require(visual:WaitForChild("HordeKit"))
	local Vfx = require(visual:WaitForChild("Vfx"))
	local AudioKit = require(visual:WaitForChild("AudioKit"))

	local function step(name: string, fn: () -> ()): ()
		local ok, err = pcall(fn)
		if not ok then
			error("[s8-smoke] FALHOU " .. name .. ": " .. tostring(err), 0)
		end
		print("[s8-smoke] OK " .. name)
	end

	local root = Instance.new("Folder")
	root.Name = "S8Smoke"
	root.Parent = workspace
	local gui = Instance.new("ScreenGui")
	gui.Name = "S8SmokeGui"
	gui.ResetOnSpawn = false
	gui.Parent = StarterGui

	local arena: Folder
	local trapCount = 0
	local unitCount = 0

	step("visual setup", function()
		VisualSetup.apply()
		assert(VisualTheme.HEX.amber == "#F59E0B", "paleta")
	end)

	step("arena", function()
		arena = ArenaVisual.build(root, Vector3.new(0, 0, 0))
		assert(arena ~= nil and arena:FindFirstChild("Base") ~= nil, "arena sem base")
		assert(#arena:GetChildren() >= 30, "arena pequena: " .. tostring(#arena:GetChildren()))
	end)

	step("trap kit", function()
		for _, trapId in ipairs(VisualTheme.trapIds()) do
			local model = TrapKit.create(trapId, 2, root, CFrame.new(0, 0.4, 0))
			assert(model ~= nil, "trap nil: " .. trapId)
			assert(#model:GetChildren() >= 4, "trap sem pecas: " .. trapId)
			TrapKit.setLevel(model, 3)
			TrapKit.pulse(model)
			trapCount += 1
		end
		local cells = {
			r1c3 = { trap = "archer", level = 1 },
			r2c3 = { trap = "tar", level = 1 },
			r3c3 = { trap = "catapult", level = 1 },
			r4c3 = { trap = "frost", level = 1 },
			r5c3 = { trap = "cannon", level = 1 },
		}
		TrapKit.sync(root, cells, Vector3.new(0, 0, 0))
		assert(root:FindFirstChild("MuralhaTraps") ~= nil, "sync sem folder")
	end)

	step("horde kit", function()
		for index, kind in ipairs(VisualTheme.enemyIds()) do
			local unit = HordeKit.create(kind, root, CFrame.new(index * 4, 0.9, 0))
			assert(unit ~= nil and unit.model ~= nil, "horde nil: " .. kind)
			assert(#unit.model:GetChildren() >= 4, "horde sem pecas: " .. kind)
			HordeKit.setBase(unit, CFrame.new(index * 4, 0.9, 0))
			HordeKit.step(unit, 1, true)
			HordeKit.setVisible(unit, false)
			HordeKit.setVisible(unit, true)
			unitCount += 1
		end
	end)

	step("vfx", function()
		Vfx.impact(root, Vector3.new(0, 1, 0), Color3.fromRGB(245, 158, 11), 4)
		Vfx.dust(root, Vector3.new(0, 1, 0), 3)
		Vfx.ring(root, Vector3.new(0, 1, 0), Color3.fromRGB(20, 184, 166))
		Vfx.projectile(root, Vector3.new(-20, 5, 0), Vector3.new(10, 1, 0), "boulder", 0.15, nil)
	end)

	step("ui kit", function()
		local panel = UiKit.panel(gui, "Panel")
		panel.Size = UDim2.fromOffset(220, 120)
		UiKit.label(panel, "Title", "MURALHA")
		UiKit.button(panel, "Action", "DEFENDER")
		UiKit.iconCoin(panel, 20)
		UiKit.progress(panel, "Bar", Color3.fromRGB(245, 158, 11))
		local card = UiKit.card(panel, "archer")
		assert(card.frame ~= nil and card.icon ~= nil and card.name ~= nil and card.cost ~= nil)
		UiKit.setCard(card, VisualTheme.TRAPS.archer, true)
	end)

	step("audio", function()
		AudioKit.play("ui_click")
		AudioKit.play("impact", 0.5)
		AudioKit.setMuted(true)
		AudioKit.play("victory")
		AudioKit.setMuted(false)
	end)

	task.wait(0.3)
	if gui.Parent ~= nil then
		gui:Destroy()
	end
	if root.Parent ~= nil then
		root:Destroy()
	end

	print(string.format("[s8-smoke] PASSOU traps=%d hordas=%d", trapCount, unitCount))
end

return { Main = Main }
