--=========================================================
--  HOODSIDE AUTOFARM v10 (completo + noclip de puertas)
--  F = arrancar/parar autofarm | N = noclip puertas on/off
--  H = copiar nombres de partes cercanas (diagnostico)
--=========================================================
local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RS        = game:GetService("ReplicatedStorage")
local Pathfind  = game:GetService("PathfindingService")
local lp = Players.LocalPlayer
local pg = lp:WaitForChild("PlayerGui")

local viejo = pg:FindFirstChild("AutofarmHood")
if viejo then viejo:Destroy() end

local gui = Instance.new("ScreenGui")
gui.Name = "AutofarmHood"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 9999
gui.Parent = pg

local btn = Instance.new("TextButton")
btn.Size = UDim2.new(0, 320, 0, 30)
btn.Position = UDim2.new(0, 12, 0, 60)
btn.BackgroundColor3 = Color3.fromRGB(30, 90, 40)
btn.TextColor3 = Color3.new(1, 1, 1)
btn.Font = Enum.Font.Code
btn.TextSize = 15
btn.Text = "ARRANCAR"
btn.Parent = gui

local lbl = Instance.new("TextLabel")
lbl.Size = UDim2.new(0, 320, 0, 92)
lbl.Position = UDim2.new(0, 12, 0, 92)
lbl.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
lbl.BackgroundTransparency = 0.2
lbl.TextColor3 = Color3.fromRGB(255, 200, 120)
lbl.Font = Enum.Font.Code
lbl.TextSize = 12
lbl.TextWrapped = true
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.Text = "v10 iniciando..."
lbl.Parent = gui

local lblN = Instance.new("TextLabel")
lblN.Size = UDim2.new(0, 320, 0, 22)
lblN.Position = UDim2.new(0, 12, 0, 186)
lblN.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
lblN.BackgroundTransparency = 0.2
lblN.TextColor3 = Color3.fromRGB(120, 220, 255)
lblN.Font = Enum.Font.Code
lblN.TextSize = 12
lblN.TextXAlignment = Enum.TextXAlignment.Left
lblN.Text = "noclip puertas: ON | N on/off | H nombres"
lblN.Parent = gui

--------------------------------------------------------------------
local activo, estado, hilo, ultimoError = false, "cargando", nil, ""
local CFG = { Umbral = 500, Timeout = 30 }
local W = workspace
local malos, usados, llevando = {}, {}, false

local function num(s)
	local d = ""
	for dig in tostring(s):gmatch("%d") do d = d .. dig end
	return tonumber(d) or 0
end

local function hijo(padre, nombre, espera)
	local o = padre and padre:FindFirstChild(nombre)
	local t0 = os.clock()
	while not o and os.clock() - t0 < (espera or 6) do
		task.wait(0.2); o = padre and padre:FindFirstChild(nombre)
	end
	return o
end

local MERCADO, CASCO, CAJEROS, REQ, CLAIM, GRAB
local tieneFPP = type(fireproximityprompt) == "function"

local function buscarPrompt(padre, texto)
	for _, d in ipairs(padre:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText:find(texto) then return d end
	end
	return nil
end

local function hrp() local c = lp.Character; return c and c:FindFirstChild("HumanoidRootPart") end
local function hum() local c = lp.Character; return c and c:FindFirstChildOfClass("Humanoid") end
local function vivo() local h = hum(); return h ~= nil and h.Health > 0 end

local function cajas()
	local n, c = 0, lp.Character
	if c then
		for _, d in ipairs(c:GetChildren()) do
			if d.Name:find("^CajaTrabajo") then n = n + 1 end
		end
	end
	return n
end

local function efectivo()
	local a = pg:FindFirstChild("HudTop")
	a = a and a:FindFirstChild("Money")
	a = a and a:FindFirstChild("Amount")
	if not a then return 0 end
	return num(a.Text)
end

local function job() local c = lp.Character; return c and c:GetAttribute("Job") end
local function streak() local c = lp.Character; return (c and c:GetAttribute("JobStreak")) or 0 end

local function dist2(a, b)
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end

local function usar(pr, alterno)
	if not pr then return false end
	local t0 = os.clock()
	while activo and os.clock() - t0 < 4 do
		if pr.Enabled then break end
		task.wait(0.1)
	end
	if not pr.Enabled then return false end
	local hold = pr.HoldDuration or 0
	if hold > 0 and not alterno then
		pcall(function() pr:InputHoldBegin() end)
		task.wait(hold + 0.4)
		pcall(function() pr:InputHoldEnd() end)
	elseif tieneFPP then
		pcall(function() fireproximityprompt(pr) end)
	end
	return true
end

--------------------------------------------------------------------
--  NOCLIP SOLO PUERTAS
--------------------------------------------------------------------
local RADIO_NC = 14
local PATRONES = { "door", "puerta", "porton", "gate", "entrada" }
local ncActivo = true
local ncCache = {}     -- parte -> es puerta (true/false)
local ncApagadas = {}  -- parte -> CanCollide original

local function esPuerta(part)
	local c = ncCache[part]
	if c ~= nil then return c end
	local res = false
	local o, n = part, 0
	while o and o ~= workspace and n < 6 do
		local nombre = o.Name:lower()
		for _, p in ipairs(PATRONES) do
			if nombre:find(p, 1, true) then res = true break end
		end
		if res then break end
		o = o.Parent; n = n + 1
	end
	ncCache[part] = res
	return res
end

local function ncRestaurar(part)
	local orig = ncApagadas[part]
	ncApagadas[part] = nil
	if part and part.Parent and orig ~= nil then
		pcall(function() part.CanCollide = orig end)
	end
end

local function ncRestaurarTodo()
	for part in pairs(ncApagadas) do ncRestaurar(part) end
end

task.spawn(function()
	while gui.Parent do
		pcall(function()
			local char = lp.Character
			local root = char and char:FindFirstChild("HumanoidRootPart")
			if not ncActivo or not root then
				if not ncActivo then ncRestaurarTodo() end
				return
			end

			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = { char }
			local cerca = workspace:GetPartBoundsInRadius(root.Position, RADIO_NC, params)
			local set = {}

			for _, part in ipairs(cerca) do
				set[part] = true
				if esPuerta(part) then
					if ncApagadas[part] == nil then ncApagadas[part] = part.CanCollide end
					if part.CanCollide then part.CanCollide = false end
				end
			end
			for part in pairs(ncApagadas) do
				if not set[part] then ncRestaurar(part) end
			end

			local n = 0
			for _ in pairs(ncApagadas) do n = n + 1 end
			lblN.Text = "noclip puertas: ON (" .. n .. " partes) | N on/off | H nombres"
		end)
		task.wait(0.15)
	end
	ncRestaurarTodo()
end)

--------------------------------------------------------------------
local function irA(pos, radio, timeout)
	radio, timeout = radio or 4, timeout or CFG.Timeout
	local t0 = os.clock()
	while activo and vivo() and os.clock() - t0 < timeout do
		local r = hrp(); if not r then return false end
		if dist2(r.Position, pos) <= radio then return true end

		local path = Pathfind:CreatePath({
			AgentRadius = 2, AgentHeight = 5, AgentCanJump = true, WaypointSpacing = 5,
		})
		local okc = pcall(function() path:ComputeAsync(r.Position, pos) end)

		if okc and path.Status == Enum.PathStatus.Success then
			local waypoints = path:GetWaypoints()
			for i, wp in ipairs(waypoints) do
				if not activo or not vivo() then return false end
				local h = hum(); if not h then return false end
				if wp.Action == Enum.PathWaypointAction.Jump then h.Jump = true end
				h:MoveTo(wp.Position)
				local tw, ultimo, tj = os.clock(), r.Position, os.clock()
				while os.clock() - tw < 3.5 do
					local rr = hrp()
					if not rr or not vivo() then break end
					if dist2(rr.Position, wp.Position) < 3 then break end
					if os.clock() - tj > 1 then
						if (rr.Position - ultimo).Magnitude < 0.6 then h.Jump = true end
						ultimo, tj = rr.Position, os.clock()
					end
					task.wait(0.1)
				end
				local rr = hrp()
				if rr and dist2(rr.Position, pos) <= radio then return true end
			end
		else
			local h = hum()
			if h then h:MoveTo(pos); task.wait(0.8); h.Jump = true; task.wait(0.8) end
		end
		task.wait(0.15)
	end
	local r = hrp()
	return r ~= nil and dist2(r.Position, pos) <= radio + 1.5
end

local function alcanzable(pos)
	local r = hrp(); if not r then return false, math.huge end
	local path = Pathfind:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function() path:ComputeAsync(r.Position, pos) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then return false, math.huge end
	local wps = path:GetWaypoints()
	local last = wps[#wps]
	if not last or dist2(last.Position, pos) > 6 then return false, math.huge end
	local len, prev = 0, r.Position
	for _, w in ipairs(wps) do
		len = len + (w.Position - prev).Magnitude
		prev = w.Position
	end
	return true, len
end

local function destinoDe(pad)
	local wp = pad:FindFirstChild("WorkPad")
	if wp then
		if wp:IsA("BasePart") then return wp.Position end
		local ok, cf = pcall(function() return wp:GetPivot() end)
		if ok and cf then return cf.Position end
	end
	return pad.Position
end

local function pads()
	local out = {}
	if not CASCO then return out end
	for _, p in ipairs(CASCO:GetChildren()) do
		if p.Name == "JobSpot" and p:FindFirstChild("WorkPad") and not p:FindFirstChildOfClass("ProximityPrompt") then
			out[#out + 1] = p
		end
	end
	return out
end

-- un estante esta "activo" si su luz, haz o anillo estan encendidos
local function encendido(p)
	for _, d in ipairs(p:GetDescendants()) do
		if d:IsA("PointLight") or d:IsA("Beam") or d:IsA("SurfaceGui") then
			local ok, en = pcall(function() return d.Enabled end)
			if ok and en == true then return true end
		end
	end
	return false
end

local function elegirPad()
	local lista = pads()

	-- 1) el estante con la luz encendida (el del haz amarillo)
	local r = hrp()
	local mejor, mejorD = nil, math.huge
	for _, p in ipairs(lista) do
		if encendido(p) then
			local d = r and (destinoDe(p) - r.Position).Magnitude or 0
			if d < mejorD then mejor, mejorD = p, d end
		end
	end
	if mejor then
		estado = "estante activo detectado"
		return mejor
	end

	-- 2) fallback: el alcanzable mas cercano
	local mejorLen = math.huge
	mejor = nil
	for _, p in ipairs(lista) do
		if not usados[p] and (malos[p] or 0) < os.clock() then
			local ok, len = alcanzable(destinoDe(p))
			if ok then
				if len < mejorLen then mejor, mejorLen = p, len end
			else
				malos[p] = os.clock() + 60
			end
		end
	end
	return mejor
end

local function atmCercano()
	local r = hrp(); if not r or not CAJEROS then return nil end
	local mejor, dist = nil, math.huge
	for _, m in ipairs(CAJEROS:GetChildren()) do
		local spot = m:FindFirstChild("ATMSpot")
		local pr = spot and spot:FindFirstChildOfClass("ProximityPrompt")
		if pr then
			local d = (spot.Position - r.Position).Magnitude
			if d < dist then mejor, dist = pr, d end
		end
	end
	return mejor
end

--------------------------------------------------------------------
local function ciclo()
	while activo do
		local ok, err = pcall(function()
			if llevando and cajas() == 0 then llevando = false; usados = {} end

			if not vivo() then
				estado = "MUERTO, esperando"
			elseif efectivo() >= CFG.Umbral and cajas() == 0 then
				local pr = atmCercano()
				if not pr then estado = "sin cajero"
				else
					estado = "yendo al cajero"
					irA(pr.Parent.Position, 5)
					if vivo() and usar(pr) then
						task.wait(0.9)
						local n = efectivo()
						if n > 0 then
							estado = "depositando " .. n
							pcall(function() REQ:InvokeServer("bank.transfer", { amount = n, op = "deposit" }) end)
							task.wait(1.3)
						end
					end
				end
			elseif job() ~= "reponedor" then
				estado = "reclamando trabajo"
				if CLAIM then
					irA(CLAIM.Parent.Position, 2.5)
					for i = 1, 4 do
						if not activo or not vivo() or job() == "reponedor" then break end
						usar(CLAIM, i % 2 == 0); task.wait(1)
					end
				else estado = "SIN PROMPT DE TRABAJO" end
			elseif not llevando and cajas() < 2 then
				estado = "agarrando caja"
				if GRAB then
					irA(GRAB.Parent.Position, 3)
					for i = 1, 4 do
						if not activo or not vivo() or cajas() >= 2 then break end
						usar(GRAB, i % 2 == 0); task.wait(1)
					end
					if cajas() > 0 then llevando = true end
				else estado = "SIN PROMPT DE CAJA" end
			else
				llevando = true
				local pad = elegirPad()
				if not pad then
					estado = "SIN ESTANTE ALCANZABLE"
					usados = {}
					task.wait(1.5)
				else
					if estado ~= "estante activo detectado" then
						estado = "llevando caja (" .. cajas() .. ")"
					end
					local streakAntes, cajasAntes = streak(), cajas()
					if irA(destinoDe(pad), 2) then
						for _ = 1, 15 do
							if not activo or not vivo() or cajas() < cajasAntes or streak() > streakAntes then break end
							task.wait(0.2)
						end
					end
					if cajas() < cajasAntes or streak() > streakAntes then
						usados[pad] = true
					else
						malos[pad] = os.clock() + 45
					end
				end
			end
		end)
		if not ok then ultimoError = tostring(err) end
		task.wait(0.3)
	end
end

--------------------------------------------------------------------
local function iniciar()
	local town = hijo(W, "Town"); if not town then error("no encuentro Workspace.Town") end
	local edif = hijo(town, "Edificios"); if not edif then error("no encuentro Town.Edificios") end
	MERCADO = hijo(edif, "Minimercado"); if not MERCADO then error("no encuentro Minimercado") end
	CASCO = hijo(MERCADO, "Casco"); if not CASCO then error("no encuentro Minimercado.Casco") end
	CAJEROS = hijo(hijo(town, "Publico"), "Cajeros")
	local rem = hijo(RS, "Remotes"); REQ = rem and hijo(rem, "Request")
	if not REQ then error("no encuentro Remotes.Request") end
	CLAIM = buscarPrompt(hijo(MERCADO, "Contratando") or MERCADO, "Tomar el trabajo")
	GRAB  = buscarPrompt(CASCO, "Coger caja")
	estado = "listo"
end

local ok, err = pcall(iniciar)
if not ok then ultimoError = "INIT: " .. tostring(err) end

task.spawn(function()
	while gui.Parent do
		local o, e = pcall(function()
			lbl.Text = string.format("estado: %s\ncajas: %d | plata: $%d\ntrabajo: %s | pads: %d\nerr: %s",
				estado, cajas(), efectivo(), tostring(job()), #pads(), ultimoError)
		end)
		if not o then lbl.Text = "ERROR PANEL: " .. tostring(e) end
		task.wait(0.3)
	end
end)

local function arrancar()
	if activo then return end
	activo, estado, ultimoError = true, "iniciando", ""
	btn.Text = "PARAR"; btn.BackgroundColor3 = Color3.fromRGB(120, 30, 30)
	hilo = task.spawn(ciclo)
end

local function parar()
	activo, estado = false, "parado"
	btn.Text = "ARRANCAR"; btn.BackgroundColor3 = Color3.fromRGB(30, 90, 40)
	if hilo then task.cancel(hilo) end
end

btn.MouseButton1Click:Connect(function() if activo then parar() else arrancar() end end)

UIS.InputBegan:Connect(function(i, gp)
	if gp then return end
	if i.KeyCode == Enum.KeyCode.F then
		if activo then parar() else arrancar() end
	elseif i.KeyCode == Enum.KeyCode.N then
		ncActivo = not ncActivo
		if not ncActivo then
			ncRestaurarTodo()
			lblN.Text = "noclip puertas: OFF | N on/off"
		end
	elseif i.KeyCode == Enum.KeyCode.H then
		local root = hrp()
		if not root then return end
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { lp.Character }
		local out = {}
		for _, part in ipairs(workspace:GetPartBoundsInRadius(root.Position, 8, params)) do
			out[#out + 1] = part:GetFullName() .. " | CanCollide=" .. tostring(part.CanCollide)
		end
		pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
		lblN.Text = "copiadas " .. #out .. " partes cercanas"
	end
end)
