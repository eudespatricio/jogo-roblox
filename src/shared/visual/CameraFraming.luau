--!strict
-- Multiplatform 3D Camera & Frustum Solver (pure Luau, zero Roblox globals).
-- Computes HUD-aware camera eye, target, FOV, and zoom so the entire 3D Arena
-- (Bastion Wall X=-25.5, 5x5 Courtyard, Crowd Stands, Fan Manifold, and
-- Monumental Portal X=+38) projects cleanly inside the clear HUD corridor
-- across 4:3 Tablets, 16:9 Desktops, 20:9 Phones, and Portrait screens.

local CameraFraming = {}

export type Vec3 = { x: number, y: number, z: number }
export type CameraSpec = {
	eye: Vec3,
	target: Vec3,
	fov: number,
	zoom: number,
}

local BuildLayout: any = nil
do
	if typeof(script) == "Instance" then
		local parent = (script :: any).Parent
		local sharedRoot = if parent ~= nil then parent.Parent else nil
		local buildDir = if sharedRoot ~= nil
			then (sharedRoot:FindFirstChild("build") or sharedRoot:WaitForChild("build"))
			else nil
		local mod = if buildDir ~= nil
			then (buildDir:FindFirstChild("BuildLayout") or buildDir:WaitForChild("BuildLayout"))
			else nil
		if mod ~= nil then
			local ok, loaded = pcall(require :: any, mod)
			if ok then
				BuildLayout = loaded
			end
		end
	else
		local ok, loaded = pcall(require :: any, "../build/BuildLayout")
		if ok then
			BuildLayout = loaded
		end
	end
end

local function v3(x: number, y: number, z: number): Vec3
	return table.freeze({ x = x, y = y, z = z })
end

-- Bounding anchors for CAM 1 (diagonal) and CAM 2 (corridor)
CameraFraming.ANCHORS_FULL = table.freeze({
	-- Bastion Towers & Wall
	v3(-25.5, 0.5, -25.0),
	v3(-25.5, 15.0, -25.0),
	v3(-25.5, 0.5, 25.0),
	v3(-25.5, 15.0, 25.0),
	v3(-25.0, 14.5, 0.0),
	-- Crowd Stands
	v3(-14.5, 3.2, -27.2),
	v3(14.5, 3.2, -27.2),
	v3(-11.5, 3.2, 27.2),
	v3(11.5, 3.2, 27.2),
	-- 5x5 Courtyard Front/Sides
	v3(-21.5, 0.5, 22.0),
	v3(21.5, 0.5, 22.0),
	v3(21.5, 0.5, -22.0),
	-- Fan Manifold & Monumental Portal (X = +38)
	v3(36.5, 1.0, -9.5),
	v3(36.5, 1.0, 9.5),
	v3(39.5, 0.5, -7.8),
	v3(39.5, 15.8, -7.8),
	v3(39.5, 0.5, 7.8),
	v3(39.5, 15.8, 7.8),
} :: { Vec3 })

-- Bounding anchors for CAM 3 (wall POV, behind Bastion looking East toward Portal)
CameraFraming.ANCHORS_WALL_POV = table.freeze({
	-- Gatehouse Battlements Foreground
	v3(-21.5, 9.5, -17.5),
	v3(-21.5, 9.5, 17.5),
	-- Crowd Stands
	v3(-14.5, 3.2, -27.2),
	v3(14.5, 3.2, -27.2),
	v3(-11.5, 3.2, 27.2),
	v3(11.5, 3.2, 27.2),
	-- 5x5 Lanes
	v3(-19.5, 0.5, -21.5),
	v3(-19.5, 0.5, 21.5),
	v3(21.5, 0.5, -21.5),
	v3(21.5, 0.5, 21.5),
	-- Fan Manifold & Monumental Portal
	v3(36.5, 1.0, -9.5),
	v3(36.5, 1.0, 9.5),
	v3(39.5, 0.5, -7.8),
	v3(39.5, 16.0, -7.8),
	v3(39.5, 0.5, 7.8),
	v3(39.5, 16.0, 7.8),
} :: { Vec3 })

-- Compact mobile gameplay anchors (phones <= 500px short side):
-- Keeps Bastion Wall/Towers, 5x5 Courtyard Grid, Fan Manifold, and Portal Mouth/Archway framed close
-- without outer decorative stands or spire tips triggering excessive pullback.
CameraFraming.ANCHORS_MOBILE_FULL = table.freeze({
	v3(-25.0, 0.5, -22.5),
	v3(-25.0, 12.0, -22.5),
	v3(-25.0, 0.5, 22.5),
	v3(-25.0, 12.0, 22.5),
	v3(-25.0, 12.5, 0.0),
	v3(-20.5, 0.5, -20.0),
	v3(-20.5, 0.5, 20.0),
	v3(21.0, 0.5, -20.0),
	v3(21.0, 0.5, 20.0),
	v3(36.0, 0.8, -7.5),
	v3(36.0, 0.8, 7.5),
	v3(38.5, 0.5, -6.5),
	v3(38.5, 11.5, -6.5),
	v3(38.5, 0.5, 6.5),
	v3(38.5, 11.5, 6.5),
	v3(38.5, 12.0, 0.0),
} :: { Vec3 })

CameraFraming.ANCHORS_MOBILE_WALL_POV = table.freeze({
	v3(-21.5, 8.5, -15.5),
	v3(-21.5, 8.5, 15.5),
	v3(-19.5, 0.5, -20.0),
	v3(-19.5, 0.5, 20.0),
	v3(21.5, 0.5, -20.0),
	v3(21.5, 0.5, 20.0),
	v3(36.0, 0.8, -7.5),
	v3(36.0, 0.8, 7.5),
	v3(38.5, 0.5, -6.5),
	v3(38.5, 12.0, -6.5),
	v3(38.5, 0.5, 6.5),
	v3(38.5, 12.0, 6.5),
	v3(38.5, 12.5, 0.0),
	v3(0.0, 0.5, -21.0),
	v3(0.0, 0.5, 21.0),
	v3(12.0, 0.5, 0.0),
} :: { Vec3 })

function CameraFraming.resolveAngle(angle: string?): string
	if angle == "corridor" or angle == "wall" or angle == "diagonal" then
		return angle
	end
	return "diagonal"
end

function CameraFraming.isCompactMobile(viewportW: number, viewportH: number): boolean
	local w = math.max(320, viewportW)
	local h = math.max(240, viewportH)
	return math.min(w, h) <= 500
end

function CameraFraming.anchorsForAngle(angle: string?): { Vec3 }
	local resolved = CameraFraming.resolveAngle(angle)
	if resolved == "wall" then
		return CameraFraming.ANCHORS_WALL_POV
	end
	return CameraFraming.ANCHORS_FULL
end

function CameraFraming.anchorsForViewport(
	viewportW: number,
	viewportH: number,
	angle: string?
): { Vec3 }
	if CameraFraming.isCompactMobile(viewportW, viewportH) then
		local resolved = CameraFraming.resolveAngle(angle)
		if resolved == "wall" then
			return CameraFraming.ANCHORS_MOBILE_WALL_POV
		end
		return CameraFraming.ANCHORS_MOBILE_FULL
	end
	return CameraFraming.anchorsForAngle(angle)
end

local function cameraBasis(eye: Vec3, target: Vec3): (Vec3, Vec3, Vec3)
	local fx = target.x - eye.x
	local fy = target.y - eye.y
	local fz = target.z - eye.z
	local flen = math.sqrt(fx * fx + fy * fy + fz * fz)
	if flen < 1e-6 then
		return { x = 1, y = 0, z = 0 }, { x = 0, y = 1, z = 0 }, { x = 0, y = 0, z = -1 }
	end
	fx /= flen
	fy /= flen
	fz /= flen

	-- right = normalize(forward x (0, 1, 0)) = normalize((-fz, 0, fx))
	local rx = -fz
	local ry = 0
	local rz = fx
	local rlen = math.sqrt(rx * rx + rz * rz)
	if rlen < 1e-6 then
		rx, ry, rz = 1, 0, 0
	else
		rx /= rlen
		rz /= rlen
	end

	-- up = right x forward
	local ux = ry * fz - rz * fy
	local uy = rz * fx - rx * fz
	local uz = rx * fy - ry * fx

	return { x = rx, y = ry, z = rz }, { x = ux, y = uy, z = uz }, { x = fx, y = fy, z = fz }
end

function CameraFraming.projectPoint(
	spec: CameraSpec,
	viewportW: number,
	viewportH: number,
	pt: Vec3
): (number, number, number)
	local w = math.max(1, viewportW)
	local h = math.max(1, viewportH)
	local right, up, forward = cameraBasis(spec.eye, spec.target)

	local relX = pt.x - spec.eye.x
	local relY = pt.y - spec.eye.y
	local relZ = pt.z - spec.eye.z

	local dx = relX * right.x + relY * right.y + relZ * right.z
	local dy = relX * up.x + relY * up.y + relZ * up.z
	local depth = relX * forward.x + relY * forward.y + relZ * forward.z

	local tanHalfY = math.tan(math.rad(spec.fov * 0.5))
	local tanHalfX = tanHalfY * (w / h)
	local safeDepth = math.max(0.001, depth)

	local u = 0.5 + 0.5 * (dx / (safeDepth * tanHalfX))
	local v = 0.5 - 0.5 * (dy / (safeDepth * tanHalfY))
	return u, v, depth
end

local function maxExceedRatio(
	eye: Vec3,
	target: Vec3,
	tanHalfX: number,
	tanHalfY: number,
	anchors: { Vec3 },
	allowLeft: number,
	allowRight: number,
	allowBot: number,
	allowTop: number
): number
	local right, up, forward = cameraBasis(eye, target)
	local maxRatio = 1.0
	for _, pt in ipairs(anchors) do
		local relX = pt.x - eye.x
		local relY = pt.y - eye.y
		local relZ = pt.z - eye.z

		local dx = relX * right.x + relY * right.y + relZ * right.z
		local dy = relX * up.x + relY * up.y + relZ * up.z
		local depth = math.max(1.0, relX * forward.x + relY * forward.y + relZ * forward.z)

		local nx = dx / (depth * tanHalfX)
		local ny = dy / (depth * tanHalfY)

		local rx = if nx < 0 then nx / allowLeft else nx / allowRight
		local ry = if ny < 0 then ny / allowBot else ny / allowTop
		local r = math.max(rx, ry)
		if r > maxRatio then
			maxRatio = r
		end
	end
	return maxRatio
end

function CameraFraming.compute(
	viewportW: number,
	viewportH: number,
	mode: string?,
	angle: string?
): CameraSpec
	local w = math.max(320, viewportW)
	local h = math.max(240, viewportH)
	local resolvedAngle = CameraFraming.resolveAngle(angle)
	local isCombat = mode == "combat" or mode == "raid" or mode == "dropin"
	local isMobile = CameraFraming.isCompactMobile(w, h)
	local aspect = w / h

	local target: Vec3
	local eye0: Vec3
	local fov: number
	local allowLeft: number
	local allowRight: number
	local allowBot: number
	local allowTop: number
	local maxZoom: number

	if isMobile then
		local isPortrait = w < h
		if resolvedAngle == "corridor" then
			target = { x = 6.2, y = if isCombat then 1.3 else 0.6, z = -0.5 }
			if isPortrait then
				eye0 = if isCombat
					then { x = 6.2, y = 36.0, z = 44.0 }
					else { x = 6.2, y = 39.0, z = 46.0 }
			else
				eye0 = if isCombat
					then { x = 6.2, y = 29.0, z = 35.5 }
					else { x = 6.2, y = 32.5, z = 38.0 }
			end
			fov = if isCombat then 44 else 43
		elseif resolvedAngle == "wall" then
			target = { x = 8.5, y = if isCombat then 2.3 else 1.8, z = 0.0 }
			eye0 = if isCombat
				then { x = -36.5, y = 27.0, z = 0.0 }
				else { x = -38.0, y = 29.5, z = 0.0 }
			fov = 48
		else
			target = { x = 3.6, y = if isCombat then 1.4 else 0.7, z = 0.4 }
			eye0 = if isCombat
				then { x = 38.5, y = 25.5, z = 38.5 }
				else { x = 40.5, y = 30.0, z = 40.5 }
			fov = if isCombat then 43 else 42
		end

		if isPortrait then
			fov += 10
			allowLeft, allowRight = -0.92, 0.92
			allowTop = if isCombat then 0.80 else 0.75
			allowBot = if isCombat then -0.80 else -0.70
			maxZoom = if resolvedAngle == "corridor" then 2.12 else 2.02
		else
			-- Landscape phones use corner/island HUD pills rather than full-width bars.
			allowLeft, allowRight = -0.92, 0.92
			allowTop = if isCombat then 0.90 else 0.87
			allowBot = if isCombat then -0.90 else -0.84
			maxZoom = 1.25
		end
	else
		local baseTargetX: number, baseTargetY: number, baseTargetZ: number
		local eye0X: number, eye0Y: number, eye0Z: number
		local baseFov: number

		if resolvedAngle == "corridor" then
			if isCombat then
				baseTargetX, baseTargetY, baseTargetZ = 6.5, 1.5, -0.5
				eye0X, eye0Y, eye0Z = 6.5, 39.0, 48.0
				baseFov = 42
			else
				baseTargetX, baseTargetY, baseTargetZ = 6.5, 1.2, -0.5
				eye0X, eye0Y, eye0Z = 6.5, 44.0, 50.0
				baseFov = 40
			end
		elseif resolvedAngle == "wall" then
			if isCombat then
				baseTargetX, baseTargetY, baseTargetZ = 8.5, 2.4, 0.0
				eye0X, eye0Y, eye0Z = -41.0, 33.0, 0.0
				baseFov = 46
			else
				baseTargetX, baseTargetY, baseTargetZ = 8.5, 2.2, 0.0
				eye0X, eye0Y, eye0Z = -43.0, 36.0, 0.0
				baseFov = 46
			end
		else
			if isCombat then
				baseTargetX, baseTargetY, baseTargetZ = 5.5, 1.8, 0.5
				eye0X, eye0Y, eye0Z = 46.0, 33.0, 47.0
				baseFov = 40
			else
				baseTargetX, baseTargetY, baseTargetZ = 5.5, 1.4, 0.5
				eye0X, eye0Y, eye0Z = 49.0, 40.0, 49.0
				baseFov = 39
			end
		end

		local topSafePx = 56
		local botSafePx = 56
		if BuildLayout ~= nil and BuildLayout.computeHud ~= nil then
			local hud = BuildLayout.computeHud(w, h)
			if not isCombat then
				topSafePx = math.max(
					hud.goldPill.y + hud.goldPill.h,
					hud.utilityCluster.y + hud.utilityCluster.h
				) + 6
				botSafePx = (h - hud.trapDock.y) + 8
			else
				topSafePx = hud.combatTopPill.y + hud.combatTopPill.h + 6
				botSafePx = 56
			end
		end
		local sideSafePx = math.max(14, math.floor(w * 0.025))

		local ndcLeft = -1 + 2 * (sideSafePx / w)
		local ndcRight = 1 - 2 * (sideSafePx / w)
		if ndcRight - ndcLeft < 0.45 then
			local midX = (ndcLeft + ndcRight) * 0.5
			ndcLeft = midX - 0.225
			ndcRight = midX + 0.225
		end

		local ndcTop = 1 - 2 * (topSafePx / h)
		local ndcBot = -1 + 2 * (botSafePx / h)
		if ndcTop - ndcBot < 0.45 then
			local midY = (ndcTop + ndcBot) * 0.5
			ndcBot = midY - 0.225
			ndcTop = midY + 0.225
		end

		local targetYShift = 0
		if botSafePx > topSafePx then
			targetYShift = -(botSafePx - topSafePx) * 0.022
		end
		target = {
			x = baseTargetX,
			y = baseTargetY + targetYShift,
			z = baseTargetZ,
		}
		eye0 = {
			x = eye0X,
			y = eye0Y,
			z = eye0Z,
		}
		fov = if aspect < 1.0 then baseFov + 8 else baseFov

		local margin = 1.04
		allowLeft = math.min(-0.08, ndcLeft / margin)
		allowRight = math.max(0.08, ndcRight / margin)
		allowBot = math.min(-0.08, ndcBot / margin)
		allowTop = math.max(0.08, ndcTop / margin)
		maxZoom = 2.15
	end

	local tanHalfY = math.tan(math.rad(fov * 0.5))
	local tanHalfX = tanHalfY * aspect
	local anchors = CameraFraming.anchorsForViewport(w, h, resolvedAngle)

	local zoom = 1.0
	for _ = 1, 3 do
		local curEye: Vec3 = {
			x = target.x + (eye0.x - target.x) * zoom,
			y = target.y + (eye0.y - target.y) * zoom,
			z = target.z + (eye0.z - target.z) * zoom,
		}
		local maxRatio = maxExceedRatio(
			curEye,
			target,
			tanHalfX,
			tanHalfY,
			anchors,
			allowLeft,
			allowRight,
			allowBot,
			allowTop
		)
		if maxRatio <= 1.0001 then
			break
		end
		zoom = math.clamp(zoom * maxRatio, 1.0, maxZoom)
	end

	zoom = math.clamp(zoom, 1.0, maxZoom)
	local finalEye: Vec3 = {
		x = target.x + (eye0.x - target.x) * zoom,
		y = target.y + (eye0.y - target.y) * zoom,
		z = target.z + (eye0.z - target.z) * zoom,
	}

	-- If zoom hit the pullback ceiling (e.g. narrow Portrait or close corridor), widen FOV slightly
	-- so horizontal frustum still encloses all 3D anchors inside the safe margin.
	local residualRatio = maxExceedRatio(
		finalEye,
		target,
		tanHalfX,
		tanHalfY,
		anchors,
		allowLeft,
		allowRight,
		allowBot,
		allowTop
	)
	if residualRatio > 1.0001 then
		local neededTanHalfY = tanHalfY * residualRatio
		fov = math.clamp(math.ceil(math.deg(2 * math.atan(neededTanHalfY)) * 10) / 10, fov, 76)
	end

	return {
		eye = finalEye,
		target = target,
		fov = fov,
		zoom = zoom,
	}
end

return table.freeze(CameraFraming)
