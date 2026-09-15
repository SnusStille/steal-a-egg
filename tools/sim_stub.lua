-- sim_stub.lua | Fake Roblox environment for headless boot simulation.
-- Purpose: execute the REAL server boot (ServerMain + all services) with
-- stubbed engine APIs to catch REAL boot-time errors without Studio.
-- Threads that would run forever are aborted at the first task.wait().

_SIM = {
	prints = {},
	warns = {},
	errors = {},   -- {where, message, trace}
	vivified = {}, -- auto-created instance keys (review for stub gaps)
	sources = {},  -- [id] = source (injected by driver)
	spawned = 0,
}

local _print = print
function print(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end
	_SIM.prints[#_SIM.prints + 1] = table.concat(parts, " ")
end

local _warn = warn or function(...) end
function warn(...)
	local parts = {}
	for i = 1, select("#", ...) do
		parts[#parts + 1] = tostring(select(i, ...))
	end
	_SIM.warns[#_SIM.warns + 1] = table.concat(parts, " ")
end

-- Luau-compat shims (Lua 5.4 host)
if unpack == nil then unpack = table.unpack end
if math.clamp == nil then
	function math.clamp(x, a, b)
		if x < a then return a end
		if x > b then return b end
		return x
	end
end
if math.round == nil then
	function math.round(x) return math.floor(x + 0.5) end
end
if math.pow == nil then
	function math.pow(x, y) return x ^ y end
end
if math.sign == nil then
	function math.sign(x)
		if x > 0 then return 1 elseif x < 0 then return -1 end
		return 0
	end
end
if string.split == nil then
	function string.split(s, sep)
		local out = {}
		local from = 1
		while true do
			local a, b = string.find(s, sep, from, true)
			if not a then
				out[#out + 1] = string.sub(s, from)
				break
			end
			out[#out + 1] = string.sub(s, from, a - 1)
			from = b + 1
		end
		return out
	end
end

function tick() return os.clock() end

-- Yield sentinel: abort threads that would suspend forever in sim
local SIM_YIELD = setmetatable({}, { __tostring = function() return "SimYield(suspended-at-wait)" end })
function _SIM.isYield(err) return err == SIM_YIELD end

task = {}
function task.wait(_) error(SIM_YIELD) end
function task.spawn(fn, ...)
	_SIM.spawned = _SIM.spawned + 1
	local args = {...}
	local function runner()
		fn(unpack(args))
	end
	local ok, err = xpcall(runner, function(e) return {e, debug.traceback()} end)
	if not ok and err[1] ~= SIM_YIELD then
		_SIM.errors[#_SIM.errors + 1] = {where = "task.spawn", message = tostring(err[1]), trace = tostring(err[2])}
	end
end
function task.defer(fn, ...) task.spawn(fn, ...) end
_SIM.delayed = {}
_SIM.delayDropped = 0
function task.delay(_, fn, ...)
	if #_SIM.delayed >= 200 then
		_SIM.delayDropped = _SIM.delayDropped + 1
		return {}
	end
	local args = {...}
	_SIM.delayed[#_SIM.delayed + 1] = { fn = fn, args = args }
	return {}
end
function _SIM.runDelayed()
	local ran = 0
	while #_SIM.delayed > 0 and ran < 200 do
		local item = table.remove(_SIM.delayed, 1)
		ran = ran + 1
		local ok, err = xpcall(function() item.fn(unpack(item.args)) end,
			function(e) return { e, debug.traceback() } end)
		if not ok and err[1] ~= SIM_YIELD then
			_SIM.errors[#_SIM.errors + 1] = { where = "task.delay", message = tostring(err[1]), trace = tostring(err[2]) }
		end
	end
	return ran
end
function task.cancel(_) end
function task.synchronize() end
function task.desynchronize() end

function typeof(x)
	local t = type(x)
	if t == "table" then
		local mt = getmetatable(x)
		if mt and mt._typeof then return mt._typeof end
	end
	return t
end

-- Signals (events): Connect/Fire/Wait. Wait aborts the thread (sim yield).
local SignalMT = { _typeof = "RBXScriptSignal" }
SignalMT.__index = SignalMT
function SignalMT:Connect(fn)
	self._listeners[#self._listeners + 1] = fn
	return { Connected = true, Disconnect = function() end }
end
function SignalMT:ConnectParallel(fn) return self:Connect(fn) end
function SignalMT:Fire(...)
	for _, fn in ipairs(self._listeners) do
		local ok, err = pcall(fn, ...)
		if not ok and err ~= SIM_YIELD then
			_SIM.errors[#_SIM.errors + 1] = {where = "signal", message = tostring(err), trace = debug.traceback()}
		end
	end
end
function SignalMT:Wait() error(SIM_YIELD) end
function SignalMT:Once(fn)
	local conn
	conn = self:Connect(function(...)
		conn.Disconnect()
		fn(...)
	end)
	return conn
end
local function newSignal()
	return setmetatable({ _listeners = {} }, SignalMT)
end

-- Vector3
local Vector3MT = { _typeof = "Vector3" }
Vector3MT.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		if m == 0 then return Vector3.new(0, 0, 0) end
		return Vector3.new(v.X / m, v.Y / m, v.Z / m)
	end
	return Vector3MT[k]
end
function Vector3MT:Dot(o) return self.X * o.X + self.Y * o.Y + self.Z * o.Z end
function Vector3MT:Cross(o)
	return Vector3.new(self.Y * o.Z - self.Z * o.Y, self.Z * o.X - self.X * o.Z, self.X * o.Y - self.Y * o.X)
end
function Vector3MT:Lerp(o, t)
	return Vector3.new(self.X + (o.X - self.X) * t, self.Y + (o.Y - self.Y) * t, self.Z + (o.Z - self.Z) * t)
end
Vector3MT.__add = function(a, b) return Vector3.new(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vector3MT.__sub = function(a, b) return Vector3.new(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vector3MT.__mul = function(a, b)
	if type(a) == "number" then return Vector3.new(a * b.X, a * b.Y, a * b.Z) end
	if type(b) == "number" then return Vector3.new(a.X * b, a.Y * b, a.Z * b) end
	return Vector3.new(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vector3MT.__div = function(a, b)
	if type(b) == "number" then return Vector3.new(a.X / b, a.Y / b, a.Z / b) end
	return Vector3.new(a.X / b.X, a.Y / b.Y, a.Z / b.Z)
end
Vector3MT.__unm = function(a) return Vector3.new(-a.X, -a.Y, -a.Z) end
Vector3MT.__tostring = function(v) return v.X .. ", " .. v.Y .. ", " .. v.Z end
Vector3 = {}
function Vector3.new(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vector3MT)
end

-- CFrame (position-accurate, rotation-approximated: enough for boot)
local CFrameMT = { _typeof = "CFrame" }
CFrameMT.__index = function(c, k)
	if k == "Position" then return c.p end
	if k == "LookVector" then return Vector3.new(0, 0, -1) end
	if k == "X" or k == "Y" or k == "Z" then return c.p[k] end
	return CFrameMT[k]
end
CFrameMT.__add = function(c, v) return CFrame.new(c.p + v) end
CFrameMT.__sub = function(a, b)
	if type(b) == "table" and getmetatable(b) == Vector3MT then
		return CFrame.new(a.p - b)
	end
	return a.p - b.p
end
CFrameMT.__mul = function(a, b)
	local am = getmetatable(a)
	if am == CFrameMT then
		local bm = getmetatable(b)
		if bm == CFrameMT then return CFrame.new(a.p + b.p) end
		if bm == Vector3MT then return a.p + b end
	end
	if am == Vector3MT then return a + b.p end
	error("CFrame mul unsupported")
end
CFrame = {}
function CFrame.new(a, b, c, ...)
	if a == nil then return setmetatable({ p = Vector3.new() }, CFrameMT) end
	if type(a) == "table" and getmetatable(a) == Vector3MT then
		return setmetatable({ p = a }, CFrameMT)
	end
	return setmetatable({ p = Vector3.new(a or 0, b or 0, c or 0) }, CFrameMT)
end
function CFrame.lookAt(pos, _) return CFrame.new(pos) end
function CFrame.fromEulerAnglesXYZ(x, y, z) return CFrame.new(x or 0, y or 0, z or 0) end
CFrame.identity = CFrame.new()

-- Color3
local Color3MT = { _typeof = "Color3" }
Color3MT.__index = Color3MT
function Color3MT:Lerp(o, t)
	return Color3.new(self.R + (o.R - self.R) * t, self.G + (o.G - self.G) * t, self.B + (o.B - self.B) * t)
end
Color3 = {}
function Color3.new(r, g, b) return setmetatable({ R = r or 0, G = g or 0, B = b or 0 }, Color3MT) end
function Color3.fromRGB(r, g, b) return Color3.new(r / 255, g / 255, b / 255) end
function Color3.fromHSV(h, s, v)
	local i = math.floor(h * 6)
	local f = h * 6 - i
	local p, q, t = v * (1 - s), v * (1 - f * s), v * (1 - (1 - f) * s)
	local m = i % 6
	if m == 0 then return Color3.new(v, t, p) elseif m == 1 then return Color3.new(q, v, p)
	elseif m == 2 then return Color3.new(p, v, t) elseif m == 3 then return Color3.new(p, q, v)
	elseif m == 4 then return Color3.new(t, p, v) else return Color3.new(v, p, q) end
end

BrickColor = {}
setmetatable(BrickColor, { __index = function(_, k)
	if k == "new" then return function(_, name) return { Name = name or "", Color = Color3.new() } end end
	return { Name = tostring(k), Color = Color3.new() }
end })

-- Vector2 / UDim / UDim2 / Rect (data only)
Vector2 = {}
function Vector2.new(x, y) return { X = x or 0, Y = y or 0 } end
UDim = {}
function UDim.new(s, o) return { Scale = s or 0, Offset = o or 0 } end
UDim2 = {}
function UDim2.new(sx, ox, sy, oy)
	return { X = UDim.new(sx, ox), Y = UDim.new(sy, oy) }
end
function UDim2.fromScale(sx, sy) return UDim2.new(sx, 0, sy, 0) end
function UDim2.fromOffset(ox, oy) return UDim2.new(0, ox, 0, oy) end
Rect = {}
function Rect.new(...) return {} end
NumberRange = {}
function NumberRange.new(...) return {} end
NumberSequence = {}
function NumberSequence.new(...) return {} end
ColorSequence = {}
function ColorSequence.new(...) return {} end
PhysicalProperties = {}
function PhysicalProperties.new(...) return {} end
TweenInfo = {}
function TweenInfo.new(...) return {} end
Random = {}
local RandomMT = { _typeof = "Random" }
RandomMT.__index = RandomMT
function Random.new() return setmetatable({}, RandomMT) end
function RandomMT:NextInteger(a, b) return math.random(a, b) end
function RandomMT:NextNumber(a, b)
	if a == nil then return math.random() end
	return a + math.random() * ((b or 1) - a)
end
function RandomMT:NextUnitVector() return Vector3.new(0, 1, 0) end
function RandomMT:Shuffle(t) return t end
function RandomMT:Clone() return Random.new() end

-- Enum: memoized tokens, typeof == "EnumItem"
Enum = {}
do
	local cache = {}
	local itemMT = { _typeof = "EnumItem" }
	itemMT.__index = itemMT
	setmetatable(Enum, { __index = function(_, group)
		if cache[group] == nil then
			local items = {}
			cache[group] = setmetatable({}, { __index = function(_, name)
				local key = group .. "." .. tostring(name)
				if items[key] == nil then
					items[key] = setmetatable({ Name = tostring(name), Value = 0, EnumType = group }, itemMT)
				end
				return items[key]
			end })
		end
		return cache[group]
	end })
end

-- Fake instances
local InstMT = { _typeof = "Instance" }
local PART_DEFAULTS = {
	Position = function() return Vector3.new() end,
	Size = function() return Vector3.new(1, 1, 1) end,
	CFrame = function() return CFrame.new() end,
	Color = function() return Color3.new() end,
	Transparency = 0, Anchored = true, CanCollide = true,
	CanQuery = true, CanTouch = true, Material = nil, Shape = nil,
	TopSurface = nil, BottomSurface = nil,
}
local VALUE_DEFAULTS = { Value = nil }

local function linkChild(parent, child)
	rawset(child, "Parent", parent)
	parent._children[#parent._children + 1] = child
end

local function unlink(inst)
	local parent = rawget(inst, "Parent")
	if parent and parent._children then
		for i, c in ipairs(parent._children) do
			if c == inst then
				table.remove(parent._children, i)
				break
			end
		end
	end
	rawset(inst, "Parent", nil)
end

local methods = {}

function methods:FindFirstChild(name, _)
	for _, c in ipairs(self._children) do
		if c.Name == name then return c end
	end
	return nil
end

function methods:WaitForChild(name, _)
	return self:FindFirstChild(name)
end

function methods:FindFirstChildOfClass(class)
	for _, c in ipairs(self._children) do
		if c.ClassName == class then return c end
	end
	return nil
end

function methods:FindFirstChildWhichIsA(class) return self:FindFirstChildOfClass(class) end

function methods:GetChildren()
	local out = {}
	for _, c in ipairs(self._children) do out[#out + 1] = c end
	return out
end

function methods:GetDescendants()
	local out = {}
	local function rec(inst)
		for _, c in ipairs(inst._children) do
			out[#out + 1] = c
			rec(c)
		end
	end
	rec(self)
	return out
end

local ISA_PARENTS = {
	Part = { "BasePart", "PVInstance" },
	MeshPart = { "BasePart", "PVInstance" },
	SpawnLocation = { "BasePart", "PVInstance" },
	UnionOperation = { "BasePart", "PVInstance" },
	Model = { "PVInstance" },
}
function methods:IsA(class)
	if self.ClassName == class or class == "Instance" then return true end
	for _, parent in ipairs(ISA_PARENTS[self.ClassName] or {}) do
		if parent == class then return true end
	end
	return false
end
function methods:IsDescendantOf(anc)
	local p = rawget(self, "Parent")
	while p do
		if p == anc then return true end
		p = rawget(p, "Parent")
	end
	return false
end

function methods:Clone()
	local copy = Instance.new(self.ClassName)
	copy.Name = self.Name
	for k, v in pairs(self) do
		if type(k) == "string" and k:sub(1, 1) ~= "_" and k ~= "Name" and k ~= "Parent" and k ~= "ClassName" then
			if type(v) ~= "table" or getmetatable(v) == nil then
				copy[k] = v
			end
		end
	end
	for _, c in ipairs(self._children) do
		local cc = c:Clone()
		cc.Parent = copy
	end
	return copy
end

function methods:Destroy() unlink(self) end

function methods:ClearAllChildren()
	for _, c in ipairs(self:GetChildren()) do c:Destroy() end
end

function methods:GetFullName()
	local parts = {}
	local cur = self
	while cur do
		table.insert(parts, 1, cur.Name or "?")
		cur = rawget(cur, "Parent")
	end
	return table.concat(parts, ".")
end

function methods:GetAttribute(k) return self._attrs[k] end
function methods:SetAttribute(k, v) self._attrs[k] = v end
function methods:GetPivot() return self.CFrame end
function methods:PivotTo(cf) self.CFrame = cf end
function methods:GetBoundingBox() return self.CFrame, self.Size end
function methods:GetPropertyChangedSignal(_) return newSignal() end
function methods:TweenSize(...) return true end
function methods:TweenPosition(...) return true end
function methods:Play() end
function methods:Stop() end
function methods:Pause() end
function methods:Resume() end

-- Remote plumbing (server sim: no clients; Fire* just runs local listeners)
function methods:FireClient(...) self._sig_OnClientEvent_DeviceSafe(self, ...) end
function methods:FireAllClients(...) self._sig_OnClientEvent_DeviceSafe(self, ...) end
function methods:FireServer(...) self._sig_OnServerEvent_DeviceSafe(self, ...) end
function methods:InvokeClient(...) return nil end
function methods:InvokeServer(...)
	local h = rawget(self, "OnServerInvoke")
	if type(h) == "function" then return h(_SIM.localPlayer, ...) end
	return nil
end

function methods:_sig_OnClientEvent_DeviceSafe(...)
	local sig = rawget(self, "_sig_OnClientEvent")
	if sig then sig:Fire(...) end
end
function methods:_sig_OnServerEvent_DeviceSafe(...)
	local sig = rawget(self, "_sig_OnServerEvent")
	if sig then sig:Fire(...) end
end

InstMT.__index = function(inst, k)
	if methods[k] then return methods[k] end
	local raw = rawget(inst, k)
	if raw ~= nil then return raw end
	-- children are reachable by name (Roblox semantics: parent.ChildName)
	if type(k) == "string" then
		for _, c in ipairs(rawget(inst, "_children")) do
			if c.Name == k then return c end
		end
	end
	-- Position derives from CFrame (Roblox semantics)
	if k == "Position" then
		local cf = rawget(inst, "CFrame")
		if type(cf) == "table" and cf.p ~= nil then return cf.Position end
	end
	-- signal-like keys auto-vivify as signals
	if type(k) == "string" and (k == "Changed" or k:sub(-7) == "Changed"
		or k == "OnServerEvent" or k == "OnClientEvent" or k == "OnServerInvoke" or k == "OnClientInvoke"
		or k == "PlayerAdded" or k == "PlayerRemoving" or k == "DescendantAdded" or k == "DescendantRemoving"
		or k == "ChildAdded" or k == "ChildRemoved" or k == "Died" or k == "Touched" or k == "TouchEnded"
		or k == "Triggered" or k == "Heartbeat" or k == "RenderStepped" or k == "Stepped"
		or k == "Completed" or k == "AncestryChanged" or k == "PromptShown" or k == "PromptHidden"
		or k == "Error" or k == "ProcessReceipt" or k == "PromptGamePassPurchaseFinished"
		or k == "PromptPurchaseFinished" or k == "CharacterAdded" or k == "CharacterRemoving"
		or k == "Chatted" or k == "Idled" or k == "MouseButton1Click" or k == "MouseButton1Down"
		or k == "MouseButton1Up" or k == "MouseButton2Click" or k == "MouseEnter" or k == "MouseLeave"
		or k == "MouseMoved" or k == "Activated" or k == "Focused" or k == "FocusLost"
		or k == "InputBegan" or k == "InputEnded" or k == "InputChanged" or k == "TouchTap"
		or k == "Ended" or k == "DidLoop" or k == "Loaded" or k == "Played" or k == "Paused"
		or k == "Resumed" or k == "Stopped") then
		local sig = newSignal()
		if k == "OnClientEvent" then rawset(inst, "_sig_OnClientEvent", sig) end
		if k == "OnServerEvent" then rawset(inst, "_sig_OnServerEvent", sig) end
		rawset(inst, k, sig)
		_SIM.vivified[inst.ClassName .. "." .. k] = true
		return sig
	end
	-- sensible part defaults (Position/Size/CFrame/...)
	local cls = rawget(inst, "ClassName")
	if PART_DEFAULTS[k] ~= nil and (cls == "Part" or cls == "SpawnLocation" or cls == "Model" or cls == "MeshPart") then
		local d = PART_DEFAULTS[k]
		local v = (type(d) == "function") and d() or d
		rawset(inst, k, v)
		return v
	end
	if k == "Value" and (cls == "BoolValue" or cls == "IntValue" or cls == "StringValue" or cls == "ObjectValue" or cls == "NumberValue") then
		return rawget(inst, "_value")
	end
	return nil
end

InstMT.__newindex = function(inst, k, v)
	if k == "Parent" then
		unlink(inst)
		if v ~= nil then linkChild(v, inst) else rawset(inst, "Parent", nil) end
		return
	end
	if k == "Value" then
		rawset(inst, "_value", v)
		return
	end
	if k == "Position" and type(v) == "table" and v.X ~= nil then
		rawset(inst, "CFrame", CFrame.new(v))
		return
	end
	rawset(inst, k, v)
end

Instance = {}
function Instance.new(className, parent)
	local inst = setmetatable({
		ClassName = className, Name = "", Parent = nil,
		_children = {}, _attrs = {},
	}, InstMT)
	if parent ~= nil then inst.Parent = parent end
	return inst
end

-- Services with real behavior
local serviceExtras = {}

serviceExtras.Players = function(svc)
	function svc:GetPlayers() return {} end
	function svc:GetPlayerByUserId(_) return nil end
	function svc:GetUserIdFromNameAsync(_) return 0 end
	svc.LocalPlayer = nil
	svc.MaxPlayers = 8
end

serviceExtras.DataStoreService = function(svc)
	local function fakeStore()
		return {
			GetAsync = function(_, _) return nil end,
			SetAsync = function() return true end,
			UpdateAsync = function(_, _, fn)
				if type(fn) == "function" then pcall(fn, nil) end
				return true
			end,
			RemoveAsync = function() return true end,
		}
	end
	local function fakeOrdered()
		return {
			GetSortedAsync = function()
				return { GetCurrentPage = function() return {} end }
			end,
			UpdateAsync = function(_, _, fn)
				if type(fn) == "function" then pcall(fn, nil) end
				return true
			end,
		}
	end
	function svc:GetDataStore(_) return fakeStore() end
	function svc:GetOrderedDataStore(_) return fakeOrdered() end
	function svc:GetGlobalDataStore() return fakeStore() end
end

serviceExtras.RunService = function(svc)
	function svc:IsStudio() return true end
	function svc:IsServer() return _SIM.isClient ~= true end
	function svc:IsClient() return _SIM.isClient == true end
	function svc:IsRunMode() return false end
end

serviceExtras.MarketplaceService = function(svc)
	function svc:PromptPurchase() end
	function svc:PromptGamePassPurchase() end
	function svc:PromptProductPurchase() end
	function svc:GetProductInfo() return {} end
	function svc:UserOwnsGamePassAsync() return false end
end

serviceExtras.GamePassService = function(svc)
	function svc:PlayerHasPass() return false end
end

serviceExtras.TweenService = function(svc)
	function svc:Create(_, _, _)
		return { Play = function() end, Cancel = function() end, Completed = newSignal() }
	end
end

serviceExtras.UserInputService = function(svc)
	svc.TouchEnabled = false
	svc.KeyboardEnabled = true
	svc.MouseEnabled = true
end

game = {}
game._services = {}
function game:GetService(name)
	if game._services[name] == nil then
		local svc = Instance.new(name)
		svc.Name = name
		if serviceExtras[name] then serviceExtras[name](svc) end
		game._services[name] = svc
	end
	return game._services[name]
end
game.CreatorId = 0
game.PlaceId = 0
game.JobId = "sim"
function game:BindToClose(_) end
function game:Shutdown() end

-- Build virtual tree from driver-provided table; wire service singletons
function _SIM.buildTree(node, parent)
	local inst = Instance.new(node.class or "Folder")
	inst.Name = node.name or ""
	if node.sourceId then inst._sourceId = node.sourceId end
	if parent then inst.Parent = parent end
	-- service singletons: top-level tree nodes become THE service
	if parent == nil then
		if serviceExtras[inst.Name] then serviceExtras[inst.Name](inst) end
		game._services[inst.Name] = inst
	end
	if node.children then
		for _, child in ipairs(node.children) do
			_SIM.buildTree(child, inst)
		end
	end
	-- seed part geometry when provided
	if node.cf then inst.CFrame = CFrame.new(node.cf[1], node.cf[2], node.cf[3]) end
	if node.size then inst.Size = Vector3.new(node.size[1], node.size[2], node.size[3]) end
	if node.color then inst.Color = Color3.new(node.color[1], node.color[2], node.color[3]) end
	return inst
end

-- require-by-instance (Roblox semantics: cache per ModuleScript)
local requireCache = {}
local scriptStack = {}
local _require = require
function require(target)
	if type(target) ~= "table" or target.ClassName ~= "ModuleScript" then
		error("require expects a ModuleScript, got " .. tostring(target and target.ClassName))
	end
	if requireCache[target] ~= nil then return requireCache[target] end
	local src = _SIM.sources[target._sourceId]
	if src == nil then error("no source for " .. target:GetFullName()) end
	scriptStack[#scriptStack + 1] = script
	script = target
	local chunk, err = load(src, "@" .. target:GetFullName(), "t", _G)
	if not chunk then
		script = table.remove(scriptStack)
		error(err)
	end
	local ok, result = xpcall(chunk, function(e) return { e, debug.traceback() } end)
	script = table.remove(scriptStack)
	if not ok then
		if result[1] == SIM_YIELD then error(SIM_YIELD) end
		error(result[1] .. "\n" .. tostring(result[2]))
	end
	requireCache[target] = result
	return result
end

function _SIM.runScript(target)
	scriptStack[#scriptStack + 1] = script
	script = target
	local src = _SIM.sources[target._sourceId]
	local chunk, err = load(src, "@" .. target:GetFullName(), "t", _G)
	if not chunk then
		script = table.remove(scriptStack)
		return false, err
	end
	local ok, r1, r2 = xpcall(chunk, function(e) return { e, debug.traceback() } end)
	script = table.remove(scriptStack)
	if not ok then
		if r1[1] == SIM_YIELD then return false, "SUSPEND: top-level yielded" end
		return false, tostring(r1[1]) .. "\n" .. tostring(r1[2])
	end
	return true, r1
end

function _SIM.find(path)
	-- path like {"ServerScriptService","EggHeistServer","ServerMain"}
	local cur = game:GetService(path[1])
	for i = 2, #path do
		cur = cur and cur:FindFirstChild(path[i])
	end
	return cur
end

function _SIM.setupClient()
	local Players = game:GetService("Players")
	local player = Instance.new("Player")
	player.Name = "SimPlayer"
	player.UserId = 1
	player.DisplayName = "SimPlayer"
	player.Parent = Players
	local playerGui = Instance.new("PlayerGui")
	playerGui.Name = "PlayerGui"
	playerGui.Parent = player
	local backpack = Instance.new("Backpack")
	backpack.Parent = player
	local char = Instance.new("Model")
	char.Name = "SimPlayer"
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.Size = Vector3.new(2, 2, 1)
	hrp.CFrame = CFrame.new(0, 10, 0)
	hrp.Parent = char
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Parent = char
	local hum = Instance.new("Humanoid")
	hum.Health = 100
	hum.MaxHealth = 100
	hum.Parent = char
	char.Parent = game:GetService("Workspace")
	player.Character = char
	_SIM.localPlayer = player
	Players.LocalPlayer = player
	function Players:GetPlayers() return { player } end
	function Players:GetPlayerByUserId(_) return player end
	local ws = game:GetService("Workspace")
	local cam = Instance.new("Camera")
	cam.Name = "Camera"
	cam.CFrame = CFrame.new(0, 30, 40)
	cam.FieldOfView = 70
	cam.Parent = ws
	ws.CurrentCamera = cam
	_SIM.isClient = true
	return "client-ready"
end

function _SIM.serverModule(name)
	local root = _SIM.find({ "ServerScriptService", "EggHeistServer" })
	if not root then return nil end
	for _, d in ipairs(root:GetDescendants()) do
		if d.ClassName == "ModuleScript" and d.Name == name then return d end
	end
	return nil
end

function _SIM.fireServer(endpoint, ...)
	local folder = game:GetService("ReplicatedStorage"):FindFirstChild("EggHeistRemotes")
	if not folder then return "no remote folder" end
	local re = folder:FindFirstChild("C2S_" .. endpoint)
	if not re then return "no endpoint " .. tostring(endpoint) end
	local sig = rawget(re, "_sig_OnServerEvent")
	if not sig then return "no server listener on " .. tostring(endpoint) end
	sig:Fire(_SIM.localPlayer, ...)
	return "fired:" .. tostring(endpoint)
end

function _SIM.claimBase()
	local world = require(_SIM.serverModule("WorldService"))
	local plot = world.GetPlotModel(1)
	if not plot then return "no plot1" end
	local foundation = plot:FindFirstChild("Foundation")
	if not foundation then return "no foundation" end
	local hrp = _SIM.localPlayer.Character:FindFirstChild("HumanoidRootPart")
	hrp.CFrame = foundation.CFrame + Vector3.new(0, 5, 0)
	return _SIM.fireServer("ClaimBase")
end

function _SIM.hatchFirstEgg()
	local DS = require(_SIM.serverModule("DataService"))
	local prof = DS.GetProfile(_SIM.localPlayer)
	if not prof or not prof.eggs or #prof.eggs == 0 then return "no eggs" end
	return _SIM.fireServer("HatchEgg", prof.eggs[1].uid)
end

function _SIM.stateDump()
	local out = {}
	local ws = game:GetService("Workspace")
	local parts, models, prompts, guis = 0, 0, 0, 0
	for _, d in ipairs(ws:GetDescendants()) do
		if d.ClassName == "Part" or d.ClassName == "MeshPart" then parts = parts + 1 end
		if d.ClassName == "Model" then models = models + 1 end
		if d.ClassName == "ProximityPrompt" then prompts = prompts + 1 end
		if d.ClassName:sub(-3) == "Gui" then guis = guis + 1 end
	end
	out[#out + 1] = string.format("workspace: %d parts, %d models, %d prompts, %d guis (%d descendants)",
		parts, models, prompts, guis, #ws:GetDescendants())
	local pg = _SIM.localPlayer and _SIM.localPlayer:FindFirstChild("PlayerGui")
	if pg then
		out[#out + 1] = "playerGui top-level: " .. #pg:GetChildren()
		for _, c in ipairs(pg:GetChildren()) do
			out[#out + 1] = "  gui: " .. c.Name .. " (" .. c.ClassName .. ", " .. #c:GetDescendants() .. " descendants)"
		end
	else
		out[#out + 1] = "playerGui: MISSING"
	end
	local world = require(_SIM.serverModule("WorldService"))
	for i = 1, 8 do
		local plot = world.GetPlotModel(i)
		local f = plot and plot:FindFirstChild("Foundation")
		if f then
			out[#out + 1] = string.format("plot%d foundation: (%.1f, %.1f, %.1f)", i, f.Position.X, f.Position.Y, f.Position.Z)
		else
			out[#out + 1] = "plot" .. i .. ": MISSING foundation"
		end
	end
	local DS = require(_SIM.serverModule("DataService"))
	if _SIM.localPlayer then
		local prof = DS.GetProfile(_SIM.localPlayer)
		if prof then
			out[#out + 1] = string.format("profile: cash=%s eggs=%d pets=%d plot=%s",
				tostring(prof.cash), #prof.eggs, #prof.pets, tostring(prof.base and prof.base.plot))
		else
			out[#out + 1] = "profile: MISSING"
		end
	end
	return table.concat(out, string.char(10))
end
