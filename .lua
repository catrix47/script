--=========================================================
--  HOODSIDE AUTOFARM v16
--  3 cajas + tipo de caja marcable + diablito + barra de retiro
--  F = arrancar/parar | N = noclip puertas | B = marcar caja cercana
--  H = copiar partes cercanas | K = copiar datos de cajas
--=========================================================
local Players   = game:GetService("Players")
local UIS       = game:GetService("UserInputService")
local RS        = game:GetService("ReplicatedStorage")
local Pathfind  = game:GetService("PathfindingService")
local VirtualUser = game:GetService("VirtualUser")
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
lbl.Size = UDim2.new(0, 320, 0, 104)
lbl.Position = UDim2.new(0, 12, 0, 92)
lbl.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
lbl.BackgroundTransparency = 0.2
lbl.TextColor3 = Color3.fromRGB(255, 200, 120)
lbl.Font = Enum.Font.Code
lbl.TextSize = 12
lbl.TextWrapped = true
lbl.TextXAlignment = Enum.TextXAlignment.Left
lbl.TextYAlignment = Enum.TextYAlignment.Top
lbl.Text = "v16 iniciando..."
lbl.Parent = gui

local lblN = Instance.new("TextLabel")
lblN.Size = UDim2.new(0, 320, 0, 22)
lblN.Position = UDim2.new(0, 12, 0, 198)
lblN.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
lblN.BackgroundTransparency = 0.2
lblN.TextColor3 = Color3.fromRGB(120, 220, 255)
lblN.Font = Enum.Font.Code
lblN.TextSize = 12
lblN.TextXAlignment = Enum.TextXAlignment.Left
lblN.Text = "noclip puertas: ON | N H K B"
lblN.Parent = gui

local btnN = Instance.new("TextButton")
btnN.Size = UDim2.new(0, 158, 0, 26)
btnN.Position = UDim2.new(0, 12, 0, 224)
btnN.TextColor3 = Color3.new(1, 1, 1)
btnN.Font = Enum.Font.Code
btnN.TextSize = 13
btnN.Parent = gui

local btnM = Instance.new("TextButton")
btnM.Size = UDim2.new(0, 158, 0, 26)
btnM.Position = UDim2.new(0, 174, 0, 224)
btnM.TextColor3 = Color3.new(1, 1, 1)
btnM.Font = Enum.Font.Code
btnM.TextSize = 13
btnM.Parent = gui

local lblS = Instance.new("TextLabel")
lblS.Size = UDim2.new(0, 320, 0, 18)
lblS.Position = UDim2.new(0, 12, 0, 254)
lblS.BackgroundColor3 = Color3.fromRGB(10, 10, 10)
lblS.BackgroundTransparency = 0.2
lblS.TextColor3 = Color3.fromRGB(150, 255, 150)
lblS.Font = Enum.Font.Code
lblS.TextSize = 12
lblS.TextXAlignment = Enum.TextXAlignment.Left
lblS.Text = ""
lblS.Parent = gui

local barra = Instance.new("Frame")
barra.Size = UDim2.new(0, 320, 0, 14)
barra.Position = UDim2.new(0, 12, 0, 274)
barra.BackgroundColor3 = Color3.fromRGB(45, 45, 45)
barra.Active = true
barra.Parent = gui

local relleno = Instance.new("Frame")
relleno.Size = UDim2.new(0, 0, 1, 0)
relleno.BackgroundColor3 = Color3.fromRGB(60, 170, 80)
relleno.BorderSizePixel = 0
relleno.Parent = barra

local TXT_MK = "Marcar caja cercana marron/normal [B]"
local btnMk = Instance.new("TextButton")
btnMk.Size = UDim2.new(0, 320, 0, 24)
btnMk.Position = UDim2.new(0, 12, 0, 294)
btnMk.BackgroundColor3 = Color3.fromRGB(60, 60, 110)
btnMk.TextColor3 = Color3.new(1, 1, 1)
btnMk.Font = Enum.Font.Code
btnMk.TextSize = 12
btnMk.Text = TXT_MK
btnMk.Parent = gui

--------------------------------------------------------------------
local activo, estado, hilo, ultimoError = false, "cargando", nil, ""
local CFG = { Umbral = 1000, Timeout = 30, Max = 3 }
local W = workspace
local malos, usados, llevando = {}, {}, false
local malosG = {}
local GRABS = {}
local MARCA = {}                       -- prompt -> "normal" / "marron" (puesto con B)
local PERM = { normal = true, marron = false }

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

local MERCADO, CASCO, CAJEROS, REQ, CLAIM
local tieneFPP = type(fireproximityprompt) == "function"

local function buscarPrompt(padre, texto)
	for _, d in ipairs(padre:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText:find(texto) then return d end
	end
	return nil
end

local function buscarPrompts(padre, texto)
	local out = {}
	for _, d in ipairs(padre:GetDescendants()) do
		if d:IsA("ProximityPrompt") and d.ActionText:find(texto) then out[#out + 1] = d end
	end
	return out
end

local function posDe(pr)
	local p = pr.Parent
	if p then
		if p:IsA("BasePart") then return p.Position end
		if p:IsA("Attachment") then return p.WorldPosition end
		local base = p:FindFirstAncestorWhichIsA("BasePart")
		if base then return base.Position end
		local ok, cf = pcall(function() return p:GetPivot() end)
		if ok and cf then return cf.Position end
	end
	return Vector3.new(0, 0, 0)
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

local function maxCajas()
	for _, pr in ipairs(GRABS) do
		local m = tostring(pr.ObjectText):match("/(%d+)")
		if m then return math.clamp(tonumber(m) or CFG.Max, 1, 10) end
	end
	return CFG.Max
end

local function suelo(pos)
	local ok, res = pcall(function()
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { lp.Character }
		return workspace:Raycast(pos + Vector3.new(0, 1, 0), Vector3.new(0, -25, 0), params)
	end)
	if ok and res then return res.Position + Vector3.new(0, 3, 0) end
	return pos
end

--------------------------------------------------------------------
--  DIABLITO (si esta en la mochila como herramienta, lo equipa)
--------------------------------------------------------------------
local function esDiablito(t)
	return t:IsA("Tool") and t.Name:lower():find("diablito") ~= nil
end

-- devuelve (lo tiene, herramienta, equipado)
local function tieneDiablito()
	local c = lp.Character
	if c then
		for _, d in ipairs(c:GetChildren()) do
			if esDiablito(d) then return true, d, true end
		end
	end
	local bp = lp:FindFirstChildOfClass("Backpack")
	if bp then
		for _, d in ipairs(bp:GetChildren()) do
			if esDiablito(d) then return true, d, false end
		end
	end
	return false, nil, false
end

local function equiparDiablito()
	local f, tool, eq = tieneDiablito()
	if f and not eq then
		local h = hum()
		if h then pcall(function() h:EquipTool(tool) end) end
	end
end

--------------------------------------------------------------------
--  TIPOS DE CAJA (normal / marron) - se marcan con B
--------------------------------------------------------------------
local function tipoDe(pr)
	if MARCA[pr] then return MARCA[pr] end
	local t = tostring(pr.ObjectText):lower()
	if t:find("diablito") then return "marron" end
	return "normal"
end

local function grabCercano()
	local r = hrp(); if not r then return nil, math.huge end
	local mejor, d0 = nil, math.huge
	for _, pr in ipairs(GRABS) do
		local d = (posDe(pr) - r.Position).Magnitude
		if d < d0 then mejor, d0 = pr, d end
	end
	return mejor, d0
end

local function marcarCercana()
	local pr, d = grabCercano()
	if not pr then return end
	local nuevo = (tipoDe(pr) == "marron") and "normal" or "marron"
	MARCA[pr] = nuevo
	malosG = {}
	btnMk.Text = "Marcada como " .. nuevo .. " (a " .. string.format("%.1f", d) .. " studs)"
	task.delay(3, function() btnMk.Text = TXT_MK end)
end
btnMk.MouseButton1Click:Connect(marcarCercana)

local function contarTipos()
	local n, m = 0, 0
	for _, pr in ipairs(GRABS) do
		if tipoDe(pr) == "marron" then m = m + 1 else n = n + 1 end
	end
	return n, m
end

local function contarPerm()
	local p, m = 0, 0
	for _, pr in ipairs(GRABS) do
		if PERM[tipoDe(pr)] and pr.Parent then
			p = p + 1
			if (malosG[pr] or 0) >= os.clock() then m = m + 1 end
		end
	end
	return p, m
end

local function refrescarBotones()
	btnN.Text = "Normales: " .. (PERM.normal and "ON" or "OFF")
	btnN.BackgroundColor3 = PERM.normal and Color3.fromRGB(30, 110, 50) or Color3.fromRGB(80, 40, 40)
	btnM.Text = "Marrones: " .. (PERM.marron and "ON" or "OFF")
	btnM.BackgroundColor3 = PERM.marron and Color3.fromRGB(120, 80, 30) or Color3.fromRGB(80, 40, 40)
end
refrescarBotones()
btnN.MouseButton1Click:Connect(function() PERM.normal = not PERM.normal; refrescarBotones() end)
btnM.MouseButton1Click:Connect(function()
	PERM.marron = not PERM.marron
	refrescarBotones()
	if PERM.marron then malosG = {} end
end)

--------------------------------------------------------------------
--  BARRA DE RETIRO (100 a 5000, de 100 en 100)
--------------------------------------------------------------------
local U_MIN, U_MAX, U_PASO = 100, 5000, 100

local function aplicarUmbral(v)
	v = math.clamp(v, U_MIN, U_MAX)
	CFG.Umbral = v
	relleno.Size = UDim2.new((v - U_MIN) / (U_MAX - U_MIN), 0, 1, 0)
	lblS.Text = "retirar al llegar a: $" .. v .. "  (100 - 5k)"
end
aplicarUmbral(CFG.Umbral)

local arrastrando = false
local function desdeX(x)
	local rel = math.clamp((x - barra.AbsolutePosition.X) / barra.AbsoluteSize.X, 0, 1)
	local pasos = (U_MAX - U_MIN) / U_PASO
	aplicarUmbral(U_MIN + math.floor(rel * pasos + 0.5) * U_PASO)
end
barra.InputBegan:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		arrastrando = true
		desdeX(i.Position.X)
	end
end)
UIS.InputChanged:Connect(function(i)
	if arrastrando and (i.UserInputType == Enum.UserInputType.MouseMovement or i.UserInputType == Enum.UserInputType.Touch) then
		desdeX(i.Position.X)
	end
end)
UIS.InputEnded:Connect(function(i)
	if i.UserInputType == Enum.UserInputType.MouseButton1 or i.UserInputType == Enum.UserInputType.Touch then
		arrastrando = false
	end
end)

--------------------------------------------------------------------
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
--  ANTI AFK
--------------------------------------------------------------------
pcall(function()
	if getconnections then
		for _, c in ipairs(getconnections(lp.Idled)) do
			pcall(function() c:Disable() end)
		end
	end
end)

lp.Idled:Connect(function()
	pcall(function()
		VirtualUser:CaptureController()
		VirtualUser:ClickButton2(Vector2.new())
	end)
end)

task.spawn(function()
	while gui.Parent do
		task.wait(300)
		pcall(function()
			VirtualUser:CaptureController()
			VirtualUser:ClickButton2(Vector2.new())
		end)
	end
end)

--------------------------------------------------------------------
--  NOCLIP SOLO PUERTAS
--------------------------------------------------------------------
local RADIO_NC = 14
local PATRONES = { "door", "puerta", "porton", "gate", "entrada" }
local ncActivo = true
local ncCache = {}
local ncApagadas = {}

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
			lblN.Text = "noclip puertas: ON (" .. n .. ") | N H K B"
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

local function alcanzable(pos, tol)
	tol = tol or 6
	local r = hrp(); if not r then return false, math.huge end
	local path = Pathfind:CreatePath({ AgentRadius = 2, AgentHeight = 5, AgentCanJump = true })
	local ok = pcall(function() path:ComputeAsync(r.Position, pos) end)
	if not ok or path.Status ~= Enum.PathStatus.Success then return false, math.huge end
	local wps = path:GetWaypoints()
	local last = wps[#wps]
	if not last or dist2(last.Position, pos) > tol then return false, math.huge end
	local len, prev = 0, r.Position
	for _, w in ipairs(wps) do
		len = len + (w.Position - prev).Magnitude
		prev = w.Position
	end
	return true, len
end

-- devuelve (caja, tieneRuta). Si ninguna tiene ruta, devuelve la mas cercana en linea recta
local function elegirGrab()
	local mejor, mejorLen = nil, math.huge
	local cercano, cercanoD = nil, math.huge
	local r = hrp()
	for _, pr in ipairs(GRABS) do
		if PERM[tipoDe(pr)] and pr.Parent and (malosG[pr] or 0) < os.clock() then
			local pos = posDe(pr)
			local ok, len = alcanzable(suelo(pos), 12)
			if ok then
				if len < mejorLen then mejor, mejorLen = pr, len end
			elseif r then
				local d = (pos - r.Position).Magnitude
				if d < cercanoD then cercano, cercanoD = pr, d end
			end
		end
	end
	if mejor then return mejor, true end
	return cercano, false
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
			if job() == "reponedor" then equiparDiablito() end
			local MAXC = maxCajas()

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
			elseif not llevando and cajas() < MAXC then
				if not PERM.normal and not PERM.marron then
					estado = "ELEGI UN TIPO DE CAJA"
					task.wait(1)
				else
					local pr, conRuta = elegirGrab()
					if not pr then
						local p, m = contarPerm()
						estado = "SIN CAJA (permitidas " .. p .. ", malas " .. m .. ")"
						task.wait(1.5)
					else
						estado = "agarrando caja (" .. tipoDe(pr) .. ")" .. (conRuta and "" or " (directo)")
						local antes = cajas()
						irA(posDe(pr), 3, conRuta and CFG.Timeout or 12)
						for i = 1, 6 do
							if not activo or not vivo() or cajas() >= MAXC then break end
							usar(pr, i % 2 == 0); task.wait(1)
						end
						if cajas() > antes then
							llevando = true
						else
							malosG[pr] = os.clock() + 60
						end
					end
				end
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
	GRABS = buscarPrompts(MERCADO, "Coger caja")
	if #GRABS == 0 then error("no encuentro ninguna caja (Coger caja)") end
	estado = "listo"
end

local ok, err = pcall(iniciar)
if not ok then ultimoError = "INIT: " .. tostring(err) end

task.spawn(function()
	while gui.Parent do
		local o, e = pcall(function()
			local nN, nM = contarTipos()
			local dj = tieneDiablito()
			lbl.Text = string.format(
				"estado: %s\ncajas: %d/%d | plata: $%d\ntrabajo: %s | pads: %d | diablito: %s\ncajas disp: %d (%d norm / %d marr)\nerr: %s",
				estado, cajas(), maxCajas(), efectivo(), tostring(job()), #pads(), dj and "si" or "no",
				#GRABS, nN, nM, ultimoError)
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
	elseif i.KeyCode == Enum.KeyCode.B then
		marcarCercana()
	elseif i.KeyCode == Enum.KeyCode.N then
		ncActivo = not ncActivo
		if not ncActivo then
			ncRestaurarTodo()
			lblN.Text = "noclip puertas: OFF | N H K B"
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
	elseif i.KeyCode == Enum.KeyCode.K then
		local out = {}
		for idx, pr in ipairs(GRABS) do
			local p = posDe(pr)
			out[#out + 1] = idx .. " | " .. tipoDe(pr) .. " | texto=" .. tostring(pr.ObjectText) ..
				" | pos=" .. string.format("%.0f, %.0f, %.0f", p.X, p.Y, p.Z) ..
				" | " .. pr:GetFullName()
		end
		pcall(function() if setclipboard then setclipboard(table.concat(out, "\n")) end end)
		lblN.Text = "copiadas " .. #out .. " cajas (K)"
	end
end)
