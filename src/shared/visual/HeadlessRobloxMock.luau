--!nonstrict
-- Minimal Roblox runtime mock for standalone `luau` CLI contract tests.
-- Never loaded in Roblox runtime (guarded by `type(game) == "userdata"`).

local HeadlessRobloxMock = {}

local currentTime = 100.0
local pendingDelays: { () -> () } = {}

function HeadlessRobloxMock.setTime(t: number): ()
	currentTime = t
end

function HeadlessRobloxMock.time(): number
	return currentTime
end

function HeadlessRobloxMock.flushDelays(): ()
	local queue = pendingDelays
	pendingDelays = {}
	for _, fn in ipairs(queue) do
		fn()
	end
end

function HeadlessRobloxMock.clearDelays(): ()
	pendingDelays = {}
end

function HeadlessRobloxMock.shared(name: string): any
	local req: any = require
	return req("./" .. name)
end

local Vector3Class = {}
Vector3Class.__index = Vector3Class

local function makeVec3(x: number?, y: number?, z: number?): any
	local vx = x or 0
	local vy = y or 0
	local vz = z or 0
	local mag = math.sqrt(vx * vx + vy * vy + vz * vz)
	return setmetatable({
		X = vx,
		Y = vy,
		Z = vz,
		Magnitude = mag,
		Unit = if mag > 1e-9
			then setmetatable(
				{ X = vx / mag, Y = vy / mag, Z = vz / mag, Magnitude = 1 },
				Vector3Class
			)
			else nil,
	}, Vector3Class)
end

function Vector3Class.__add(a: any, b: any): any
	return makeVec3(a.X + b.X, a.Y + b.Y, a.Z + b.Z)
end

function Vector3Class.__sub(a: any, b: any): any
	return makeVec3(a.X - b.X, a.Y - b.Y, a.Z - b.Z)
end

function Vector3Class.__unm(a: any): any
	return makeVec3(-a.X, -a.Y, -a.Z)
end

function Vector3Class.__mul(a: any, b: any): any
	if type(a) == "number" then
		return makeVec3(a * b.X, a * b.Y, a * b.Z)
	elseif type(b) == "number" then
		return makeVec3(a.X * b, a.Y * b, a.Z * b)
	end
	return makeVec3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end

function Vector3Class.__div(a: any, b: any): any
	if type(b) == "number" then
		return makeVec3(a.X / b, a.Y / b, a.Z / b)
	end
	return makeVec3(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end

function Vector3Class:Dot(other: any): number
	return self.X * other.X + self.Y * other.Y + self.Z * other.Z
end

function Vector3Class:Cross(other: any): any
	return makeVec3(
		self.Y * other.Z - self.Z * other.Y,
		self.Z * other.X - self.X * other.Z,
		self.X * other.Y - self.Y * other.X
	)
end

function Vector3Class:Lerp(other: any, alpha: number): any
	return makeVec3(
		self.X + (other.X - self.X) * alpha,
		self.Y + (other.Y - self.Y) * alpha,
		self.Z + (other.Z - self.Z) * alpha
	)
end

local Vector3Lib = {
	new = makeVec3,
	zero = makeVec3(0, 0, 0),
	one = makeVec3(1, 1, 1),
}
HeadlessRobloxMock.Vector3 = Vector3Lib

local CFrameClass = {}
CFrameClass.__index = CFrameClass

local function makeCF(
	px: number,
	py: number,
	pz: number,
	r00: number,
	r01: number,
	r02: number,
	r10: number,
	r11: number,
	r12: number,
	r20: number,
	r21: number,
	r22: number
): any
	local cf: any = {
		_m = { r00, r01, r02, r10, r11, r12, r20, r21, r22 },
		Position = makeVec3(px, py, pz),
	}
	return setmetatable(cf, CFrameClass)
end

function CFrameClass.__index(self: any, key: string): any
	if key == "Rotation" then
		local m = self._m
		return makeCF(0, 0, 0, m[1], m[2], m[3], m[4], m[5], m[6], m[7], m[8], m[9])
	elseif key == "LookVector" then
		local m = self._m
		return makeVec3(-m[3], -m[6], -m[9])
	elseif key == "RightVector" then
		local m = self._m
		return makeVec3(m[1], m[4], m[7])
	elseif key == "UpVector" then
		local m = self._m
		return makeVec3(m[2], m[5], m[8])
	end
	return CFrameClass[key]
end

function CFrameClass.__mul(a: any, b: any): any
	local am = a._m
	local ap = a.Position
	if getmetatable(b) == Vector3Class then
		return makeVec3(
			am[1] * b.X + am[2] * b.Y + am[3] * b.Z + ap.X,
			am[4] * b.X + am[5] * b.Y + am[6] * b.Z + ap.Y,
			am[7] * b.X + am[8] * b.Y + am[9] * b.Z + ap.Z
		)
	end
	local bm = b._m
	local bp = b.Position
	local px = am[1] * bp.X + am[2] * bp.Y + am[3] * bp.Z + ap.X
	local py = am[4] * bp.X + am[5] * bp.Y + am[6] * bp.Z + ap.Y
	local pz = am[7] * bp.X + am[8] * bp.Y + am[9] * bp.Z + ap.Z
	return makeCF(
		px,
		py,
		pz,
		am[1] * bm[1] + am[2] * bm[4] + am[3] * bm[7],
		am[1] * bm[2] + am[2] * bm[5] + am[3] * bm[8],
		am[1] * bm[3] + am[2] * bm[6] + am[3] * bm[9],
		am[4] * bm[1] + am[5] * bm[4] + am[6] * bm[7],
		am[4] * bm[2] + am[5] * bm[5] + am[6] * bm[8],
		am[4] * bm[3] + am[5] * bm[6] + am[6] * bm[9],
		am[7] * bm[1] + am[8] * bm[4] + am[9] * bm[7],
		am[7] * bm[2] + am[8] * bm[5] + am[9] * bm[8],
		am[7] * bm[3] + am[8] * bm[6] + am[9] * bm[9]
	)
end

function CFrameClass.__sub(a: any, v: any): any
	local m = a._m
	local p = a.Position
	return makeCF(
		p.X - v.X,
		p.Y - v.Y,
		p.Z - v.Z,
		m[1],
		m[2],
		m[3],
		m[4],
		m[5],
		m[6],
		m[7],
		m[8],
		m[9]
	)
end

function CFrameClass.__add(a: any, v: any): any
	local m = a._m
	local p = a.Position
	return makeCF(
		p.X + v.X,
		p.Y + v.Y,
		p.Z + v.Z,
		m[1],
		m[2],
		m[3],
		m[4],
		m[5],
		m[6],
		m[7],
		m[8],
		m[9]
	)
end

function CFrameClass:Inverse(): any
	local m = self._m
	local p = self.Position
	local ix = -(m[1] * p.X + m[4] * p.Y + m[7] * p.Z)
	local iy = -(m[2] * p.X + m[5] * p.Y + m[8] * p.Z)
	local iz = -(m[3] * p.X + m[6] * p.Y + m[9] * p.Z)
	return makeCF(ix, iy, iz, m[1], m[4], m[7], m[2], m[5], m[8], m[3], m[6], m[9])
end

function CFrameClass:ToObjectSpace(worldCF: any): any
	return self:Inverse() * worldCF
end

local function cfNew(a: any, b: any?, c: any?): any
	if a == nil then
		return makeCF(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	elseif type(a) == "table" then
		return makeCF(a.X, a.Y, a.Z, 1, 0, 0, 0, 1, 0, 0, 0, 1)
	end
	return makeCF(a, b or 0, c or 0, 1, 0, 0, 0, 1, 0, 0, 0, 1)
end

local function cfAngles(rx: number, ry: number, rz: number): any
	local cx, sx = math.cos(rx), math.sin(rx)
	local cy, sy = math.cos(ry), math.sin(ry)
	local cz, sz = math.cos(rz), math.sin(rz)
	local mX = makeCF(0, 0, 0, 1, 0, 0, 0, cx, -sx, 0, sx, cx)
	local mY = makeCF(0, 0, 0, cy, 0, sy, 0, 1, 0, -sy, 0, cy)
	local mZ = makeCF(0, 0, 0, cz, -sz, 0, sz, cz, 0, 0, 0, 1)
	return mX * mY * mZ
end

local function cfLookAt(at: any, target: any): any
	local diff = target - at
	if diff.Magnitude < 1e-6 then
		return cfNew(at)
	end
	local fwd = diff.Unit
	local upRef = if math.abs(fwd.Y) > 0.99 then makeVec3(0, 0, 1) else makeVec3(0, 1, 0)
	local right = fwd:Cross(upRef).Unit
	local up = right:Cross(fwd).Unit
	return makeCF(
		at.X,
		at.Y,
		at.Z,
		right.X,
		up.X,
		-fwd.X,
		right.Y,
		up.Y,
		-fwd.Y,
		right.Z,
		up.Z,
		-fwd.Z
	)
end

local CFrameLib = {
	new = cfNew,
	Angles = cfAngles,
	lookAt = cfLookAt,
	identity = makeCF(0, 0, 0, 1, 0, 0, 0, 1, 0, 0, 0, 1),
}
HeadlessRobloxMock.CFrame = CFrameLib

local Color3Class = {}
Color3Class.__index = Color3Class

local function makeColor3(r: number?, g: number?, b: number?): any
	return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3Class)
end

function Color3Class:Lerp(other: any, alpha: number): any
	return makeColor3(
		self.R + (other.R - self.R) * alpha,
		self.G + (other.G - self.G) * alpha,
		self.B + (other.B - self.B) * alpha
	)
end

HeadlessRobloxMock.Color3 = {
	new = makeColor3,
	fromRGB = function(r: number, g: number, b: number)
		return makeColor3((r or 0) / 255, (g or 0) / 255, (b or 0) / 255)
	end,
	fromHSV = function(h: number, s: number, v: number)
		return makeColor3(v, v * (1 - s * 0.5), v * (1 - s))
	end,
}

HeadlessRobloxMock.Vector2 = {
	new = function(x: number?, y: number?)
		return { X = x or 0, Y = y or 0 }
	end,
	zero = { X = 0, Y = 0 },
}
HeadlessRobloxMock.UDim = {
	new = function(s: number?, o: number?)
		return { Scale = s or 0, Offset = o or 0 }
	end,
}
HeadlessRobloxMock.UDim2 = {
	new = function(xs, xo, ys, yo)
		return { xs = xs or 0, xo = xo or 0, ys = ys or 0, yo = yo or 0 }
	end,
	fromOffset = function(xo, yo)
		return { xo = xo or 0, yo = yo or 0 }
	end,
	fromScale = function(xs, ys)
		return { xs = xs or 0, ys = ys or 0 }
	end,
}
HeadlessRobloxMock.NumberRange = {
	new = function(a: number, b: number?)
		return { Min = a, Max = b or a }
	end,
}
HeadlessRobloxMock.NumberSequenceKeypoint = {
	new = function(t: number, v: number, e: number?)
		return { Time = t, Value = v, Envelope = e or 0 }
	end,
}
HeadlessRobloxMock.NumberSequence = {
	new = function(a: any, b: any?)
		return { a, b }
	end,
}
HeadlessRobloxMock.ColorSequenceKeypoint = {
	new = function(t: number, c: any)
		return { Time = t, Value = c }
	end,
}
HeadlessRobloxMock.ColorSequence = {
	new = function(a: any, b: any?)
		if
			b == nil
			and type(a) == "table"
			and a.Keypoints == nil
			and a[1] ~= nil
			and a[1].Time ~= nil
		then
			local kps = {}
			for i, kp in ipairs(a) do
				kps[i] = kp
			end
			return { Keypoints = kps }
		end
		-- (c0, c1): dois keypoints em t=0 e t=1.
		return {
			a,
			b,
			Keypoints = {
				{ Time = 0, Value = a },
				{ Time = 1, Value = if b ~= nil then b else a },
			},
		}
	end,
}
HeadlessRobloxMock.TweenInfo = {
	new = function(...)
		return { ... }
	end,
}
HeadlessRobloxMock.Enum = setmetatable({}, {
	__index = function(self, group: string)
		local sub = setmetatable({}, {
			__index = function(s, item: string)
				local val = { Name = item, EnumType = group }
				s[item] = val
				return val
			end,
		})
		self[group] = sub
		return sub
	end,
})

local function makeSignal()
	local listeners: { (...any) -> () } = {}
	return {
		Connect = function(_self: any, fn: ((...any) -> ())?)
			if type(fn) == "function" then
				listeners[#listeners + 1] = fn
			end
			return { Disconnect = function() end }
		end,
		Once = function(_self: any, fn: ((...any) -> ())?)
			if type(fn) == "function" then
				listeners[#listeners + 1] = fn
			end
			return { Disconnect = function() end }
		end,
		Fire = function(_self: any, ...: any)
			local copy = listeners
			listeners = {}
			for _, fn in ipairs(copy) do
				fn(...)
			end
		end,
	}
end

local InstanceMethods = {}

function InstanceMethods:IsA(cls: string): boolean
	if self.ClassName == cls or cls == "Instance" or cls == "PVInstance" then
		return true
	end
	if cls == "BasePart" then
		return self.ClassName == "Part"
			or self.ClassName == "WedgePart"
			or self.ClassName == "MeshPart"
	end
	return false
end

function InstanceMethods:GetChildren(): { any }
	local out = {}
	for _, c in ipairs(self._children) do
		out[#out + 1] = c
	end
	return out
end

function InstanceMethods:GetDescendants(): { any }
	local out = {}
	local function walk(node: any)
		for _, c in ipairs(node._children) do
			out[#out + 1] = c
			walk(c)
		end
	end
	walk(self)
	return out
end

function InstanceMethods:FindFirstChild(name: string): any?
	for _, c in ipairs(self._children) do
		if c.Name == name then
			return c
		end
	end
	return nil
end

function InstanceMethods:FindFirstChildOfClass(cls: string): any?
	for _, c in ipairs(self._children) do
		if c.ClassName == cls then
			return c
		end
	end
	return nil
end

function InstanceMethods:WaitForChild(name: string): any
	return self:FindFirstChild(name)
end

function InstanceMethods:SetAttribute(key: string, val: any): ()
	self._attrs[key] = val
end

function InstanceMethods:GetAttribute(key: string): any
	return self._attrs[key]
end

function InstanceMethods:GetScale(): number
	return self._scale or 1
end

function InstanceMethods:ScaleTo(s: number): ()
	self._scale = s
end

function InstanceMethods:PivotTo(cf: any): ()
	self._pivot = cf
end

function InstanceMethods:GetBoundingBox(): (any, any)
	return self._pivot or CFrameLib.identity, makeVec3(2, 4, 2)
end

function InstanceMethods:ApplyImpulse(_v: any): () end
function InstanceMethods:ApplyAngularImpulse(_v: any): () end
function InstanceMethods:Emit(_n: number): () end

function InstanceMethods:Destroy(): ()
	self.Parent = nil
	for _, c in ipairs(self:GetChildren()) do
		c:Destroy()
	end
end

-- Clone profundo: copia todos os campos publicos (MeshPart.MeshId/TextureID, SurfaceAppearance
-- ColorMap/NormalMap/..., Beam/Decal/Attachment.Texture etc.), atributos e filhos.
local CLONE_SKIP: { [string]: boolean } = {
	ClassName = true,
	ChildAdded = true,
	Parent = true,
	CFrame = true,
}

function InstanceMethods:Clone(): any
	local copy = HeadlessRobloxMock.Instance.new(self.ClassName)
	for k, v in pairs(self) do
		if type(k) == "string" and string.sub(k, 1, 1) ~= "_" and not CLONE_SKIP[k] then
			rawset(copy, k, v)
		end
	end
	copy.CFrame = self.CFrame
	for k, v in pairs(self._attrs) do
		copy._attrs[k] = v
	end
	copy._scale = self._scale
	copy._pivot = self._pivot
	for _, child in ipairs(self._children) do
		local childCopy = child:Clone()
		childCopy.Parent = copy
	end
	return copy
end

local function createMockInstance(className: string): any
	local isPart = className == "Part" or className == "WedgePart" or className == "MeshPart"
	local state: any = {
		ClassName = className,
		Name = className,
		_parent = nil,
		_children = {},
		_attrs = {},
		_scale = 1,
		_pivot = CFrameLib.identity,
		_cframe = CFrameLib.identity,
		_position = Vector3Lib.zero,
		Size = if isPart then makeVec3(1, 1, 1) else nil,
		Anchored = false,
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
		CastShadow = true,
		Transparency = 0,
		AssemblyMass = 1,
		Enabled = false,
		ChildAdded = makeSignal(),
	}
	return setmetatable(state, {
		__index = function(t, k: string)
			if k == "Parent" then
				return rawget(t, "_parent")
			elseif k == "CFrame" then
				return rawget(t, "_cframe")
			elseif k == "Position" then
				return rawget(t, "_position")
			end
			return InstanceMethods[k]
		end,
		__newindex = function(t, k: string, v: any)
			if k == "Parent" then
				local oldParent = rawget(t, "_parent")
				if oldParent ~= nil then
					local list = oldParent._children
					for idx = #list, 1, -1 do
						if list[idx] == t then
							table.remove(list, idx)
						end
					end
				end
				rawset(t, "_parent", v)
				if v ~= nil and v._children ~= nil then
					v._children[#v._children + 1] = t
				end
			elseif k == "CFrame" then
				rawset(t, "_cframe", v)
				rawset(t, "_position", v.Position)
			elseif k == "Position" then
				local cf = rawget(t, "_cframe")
				local newCF = cfNew(v) * cf.Rotation
				rawset(t, "_cframe", newCF)
				rawset(t, "_position", v)
			else
				rawset(t, k, v)
			end
		end,
	})
end

HeadlessRobloxMock.Instance = {
	new = createMockInstance,
}

local services: { [string]: any } = {
	ReplicatedStorage = createMockInstance("Folder"),
	Workspace = createMockInstance("Folder"),
	Debris = { AddItem = function() end },
	PhysicsService = {
		RegisterCollisionGroup = function() end,
		CollisionGroupSetCollidable = function() end,
	},
	RunService = { RenderStepped = makeSignal() },
	TweenService = {
		Create = function()
			local completed = makeSignal()
			return {
				Play = function()
					pendingDelays[#pendingDelays + 1] = function()
						completed:Fire(HeadlessRobloxMock.Enum.PlaybackState.Completed)
					end
				end,
				Completed = completed,
			}
		end,
	},
}

HeadlessRobloxMock.game = {
	GetService = function(_self: any, name: string)
		if services[name] == nil then
			services[name] = createMockInstance("Folder")
		end
		return services[name]
	end,
}

HeadlessRobloxMock.task = {
	delay = function(_t: number, fn: () -> ())
		pendingDelays[#pendingDelays + 1] = fn
	end,
	defer = function(_fn: () -> ()) end,
	spawn = function(_fn: () -> ()) end,
	wait = function()
		return 0
	end,
}

return HeadlessRobloxMock
